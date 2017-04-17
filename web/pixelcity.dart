/*
Copyright Robert Muth <robert@muth.org>

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; version 3
of the License.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
*/

import 'dart:html' as HTML;
import 'dart:core';
import 'dart:math' as Math;
import 'dart:async';
import 'dart:typed_data';
import 'dart:web_gl' as WebGL;

import 'package:vector_math/vector_math.dart' as VM;
import 'package:chronosgl/chronosgl.dart';

import 'config.dart';
import 'settings.dart';
import 'webutil.dart';
import 'street.dart';
import 'sky.dart';
import 'floor_plan.dart';
import 'renderer.dart';

import 'rgb.dart';
import 'building.dart';
import 'geometry.dart';
import 'facade.dart';
import 'shaders.dart';
import 'logging.dart' as log;

double GetRandom(Math.Random rng, double a, double b) {
  return rng.nextDouble() * (b - a) + a;
}

final VM.Vector3 kColorBlack = new VM.Vector3(0.0, 0.0, 0.0);

const double kHeightCamera = 80.0;
const double kHeightFloor = 0.0;
const double kHeightStreetLight = 2.0;

double AngleDelta(double angleSrc, double angleDst) {
  double delta = angleDst - angleSrc;
  if (0.0 <= delta && delta <= 180.0) {
    return delta;
  }
  if (180.0 < delta) {
    return delta - 360.0;
  }
  // delta must be negative
  if (-180.0 <= delta) {
    return delta;
  }
  return delta + 360.0;
}

abstract class MyCamera {
  void init();
  void animate(OrbitCamera camera, double elapsed, double now);
}

// both camera and target are orbiting
class RotatingCamera implements MyCamera {
  final double _cameraOrbit;
  final double _targetOrbit;
  final double _targetHeight;
  final double _speed;
  final double _angleOffset;

  RotatingCamera(this._cameraOrbit, this._targetOrbit, this._targetHeight,
      this._speed, this._angleOffset);

  void init() {}

  void animate(OrbitCamera camera, double elapsed, double now) {
    double h = gOptions.GetDouble(oCameraHeight);
    if (gOptions.GetBool(oCameraLevelChange)) {
      h *= 1 + 0.20 * Math.sin(now / 10000);
    }
    double dir = now * _speed;
    double cx = _cameraOrbit * Math.sin(dir);
    double cz = _cameraOrbit * Math.cos(dir);
    camera.setPos(cx, h, cz);
    dir += _angleOffset;
    double tx = _targetOrbit * Math.sin(dir);
    double tz = _targetOrbit * Math.cos(dir);
    camera.lookAt(new VM.Vector3(tx, _targetHeight, tz));
  }
}

class ManualCamera implements MyCamera {
  final double _azimuthDelta;
  ManualCamera(this._azimuthDelta);

  void init() {
    //double h = gOptions.GetDouble(oCameraHeight);
    // FIXME
    // _orbit.polar = Math.PI / 8;
  }

  void animate(OrbitCamera camera, double elapsed, double now) {
    camera.azimuth += _azimuthDelta;
    camera.animate(elapsed);
  }
}

class FollowCarCamera {
  final Car _car;
  final int _xzoffset;
  final double _targetHeight;
  final VM.Vector3 up = new VM.Vector3(0.0, 1.0, 0.0);
  double _currentDir;
  int _angle;
  FollowCarCamera(this._car, this._xzoffset, this._targetHeight, this._angle) {
    _currentDir = _car.Dir();
  }

  void _UpdateDir(double elapsed) {
    final double targetDir = _car.Dir();
    //LogInfo("DIR  ${dir} ${_currentDir}");
    final double delta = AngleDelta(_currentDir, targetDir);
    if (delta > 0) {
      final double dist = 0.01 * elapsed;
      //log.LogInfo("Delta ${delta} ${dist}");
      if (dist >= delta) {
        _currentDir = targetDir;
      } else {
        _currentDir += dist;
      }
    } else if (delta < 0) {
      final double dist = -0.01 * elapsed;
      //log.LogInfo("Delta ${delta} ${dist}");
      if (dist <= delta) {
        _currentDir = targetDir;
      } else {
        _currentDir += dist;
      }
    }
  }

  void init() {}

  void animate(OrbitCamera camera, double elapsed, double now) {
    _UpdateDir(elapsed);
    double x = _car.Pos().x - _xzoffset;
    double z = _car.Pos().y - _xzoffset;
    double dir = (90 - _currentDir + _angle) * Math.PI / 180.0;
    // look forward in direction of movement
    double tx = x - 200 * Math.cos(dir);
    double tz = z - 200 * Math.sin(dir);
    VM.Vector3 at = new VM.Vector3(tx, _targetHeight, tz);

    double cx = x + 1.0 * Math.cos(dir);
    double cz = z + 1.0 * Math.sin(dir);
    double h = gOptions.GetDouble(oCameraHeight);
    if (gOptions.GetBool(oCameraLevelChange)) {
      h *= 1 + 0.25 * Math.sin(now / 10000);
    }
    camera.setPos(cx, h, cz);
    camera.lookAt(at, up);
  }
}

Math.Random gRng = new Math.Random(1);
HTML.Element gFps = HTML.querySelector("#fps");
PC gPc = null;

void UpdateAll() {
  HTML.CanvasElement canvas = HTML.document.getElementById("area");
  canvas.width = HTML.window.innerWidth;
  canvas.height = HTML.window.innerHeight;

  int seed = gOptions.GetInt(oRandomSeed);
  if (seed == 0) {
    seed = new DateTime.now().millisecondsSinceEpoch;
  }
  gRng = new Math.Random(seed);
}

int _kSkyRepeats = 3;

// TODO(robertm): this is pretty close to a generic cyclinder shape function generalize
Node MakeSky(ChronosGL cgl, Math.Random rng, double skyHue, int segments,
    double radius, double height) {
  log.LogInfo("Make Sky Canvas");
  double sat = 0.1 + 0.8 * rng.nextDouble();
  RGB black = new RGB.fromGray(0);
  RGB horizon = new RGB.fromHSL(skyHue, sat, 0.2);
  RGB clouds = new RGB.fromHSL(skyHue, 0.15, 0.1);
  FaceMat mat = new FaceMat("sky")
    ..canvas = MakeCanvasSky(rng, 2048, 1024, black, horizon, clouds);

  log.LogInfo("Make sky");
  Shape shape = new Shape();
  List<VM.Vector2> points = MakeRegularPolygonShape(segments, radius, 0.0, 0.0);
  for (int i = 0; i < segments; i++) {
    Rect uvxy = new Rect((segments - 1 - i) / segments * _kSkyRepeats, 0.0,
        1 / segments * _kSkyRepeats, 1.0);
    VM.Vector2 p1 = points[i];
    VM.Vector2 p2 = points[(i + 1) % segments];
    List<VM.Vector3> face = [
      new VM.Vector3(p1.x, height, p1.y),
      new VM.Vector3(p1.x, 0.0, p1.y),
      new VM.Vector3(p2.x, 0.0, p2.y),
      new VM.Vector3(p2.x, height, p2.y),
    ];

    shape.AddQuad(new Quad(face, uvxy), new ColorMat(mat, kRGBwhite.GlColor()));
  }
  return ConvertToChronosGLSingle("sky", cgl, shape);
}

Node MakeGround(ChronosGL cgl, Floorplan floorplan, int dimension, int xzoffset,
    RGB lane, RGB other) {
  log.LogInfo("Make Floor Canvas");

  FaceMat mat = new FaceMat("floor")
    ..canvas = RenderCanvasWorldMap(floorplan.world_map, lane, other);

  log.LogInfo("Make Floor Mesh");
  Shape shape = new Shape();
  shape.AddQuad(MakeFloor(dimension * 1.0, dimension * 1.0),
      new ColorMat(mat, kRGBwhite.GlColor()));
  return ConvertToChronosGLSingle("floor", cgl, shape)
    ..moveForward(xzoffset + 0.0)
    ..moveLeft(xzoffset + 0.0);
}

VM.Vector3 RandomColor(Math.Random rng) {
  return new VM.Vector3(rng.nextDouble(), rng.nextDouble(), rng.nextDouble());
}

List<Node> MakeBuildings(ChronosGL cgl, int xzoffset, Math.Random rng,
    List<Building> buildings, List<String> logos, String mode) {
  log.LogInfo("Make building materials");

  List<FaceMat> walls;
  FaceMat logo;
  switch (mode) {
    case kModeNight:
      walls = MakeWallsNight(gRng, kRGBblack);
      logo = MakeLogo(logos, kRGBwhite, kRGBblack);
      break;
    case kModeWireframe:
      logo = new FaceMat("dummy");
      walls = [logo];
      break;
    case kModeDay:
    case kModeShadow:
      walls = MakeWallsDay(gRng, kRGBwhite);
      logo = MakeLogo(logos, kRGBblack, kRGBwhite);
      break;
    default:
      assert(false, "unknown mode ${mode}");
  }

  final BuildingParameters params = new BuildingParameters()
    ..wallMats = walls
    ..logoMat = logo
    ..lightTrimMat = MakeLightTrims()
    ..pointLightMat = MakePointLight()
    ..flashingLightMat = MakeFlashingLight()
    ..radioTowerMat = MakeRadioTower()
    ..wallColors = kBuildingColors
    ..ledgeColors = kLedgeColors
    ..offsetColors = kOffsetColors
    ..baseColors = kBaseColors
    ..acColors = kAcColors
    ..num_logos = kNumBuildingLogos
    ..solidMat = MakeSolid();

  log.LogInfo("Errecting building");
  Shape shape = new Shape();
  int count = 0;
  for (Building b in buildings) {
    if (count % 100 == 0) {
      log.LogInfo("initialize buidings ${count}");
    }
    count++;
    VM.Vector3 theColor =
        kDaylightBuildingColors[rng.nextInt(kDaylightBuildingColors.length)]
            .GlColor();
    if (mode != kModeNight) {
      params..wallColors = [theColor + RandomColor(rng) * 0.2];
      params..ledgeColors = [theColor + RandomColor(rng) * 0.1];
      params..offsetColors = [theColor + RandomColor(rng) * 0.1];
      params..baseColors = [theColor + RandomColor(rng) * 0.1];
      params..acColors = [theColor + RandomColor(rng) * 0.2];
    }
    RoofOptions roofOpt = new RoofOptions(rng, params);
    switch (mode) {
      case kModeNight:
        break;
      case kModeDay:
      case kModeShadow:
        roofOpt.allowLightStrip = false;
        roofOpt.allowGlobeLight = false;
        break;
      case kModeWireframe:
        roofOpt.allowLogo = false;
        roofOpt.allowLightStrip = false;
        break;
    }

    AddOneBuilding(
        shape, rng, params, roofOpt, b, theColor, mode == kModeNight);
  }
  log.LogInfo("Generate Mesh for Buildings");
  List<Node> out = ConvertToChronosGL(cgl, shape);
  for (int i = 0; i < out.length; i++) {
    out[i]
      ..moveForward(xzoffset + 0.0)
      ..moveLeft(xzoffset + 0.0);
  }
  return out;
}

const int kStreetLightSpacing = 6;

List<double> _PlaceLightsOnLine(double w, int spacing) {
  int n = (w / spacing).floor();
  double offset = (w - spacing * n) / 2;
  if (offset < spacing / 2) {
    offset += spacing / 2;
  }
  List<double> out = [];
  for (double p = offset; p <= w - offset; p += spacing) {
    out.add(p);
  }
  return out;
}

Node MakeStreetLightsPoints(
    ChronosGL cgl, int xzoffset, Math.Random rng, Floorplan floorplan) {
  FaceMat mat = MakePointLight();
  log.LogInfo("Make street lights using points");
  Shape shape = new Shape();
  ColorMat streetLightMat = new ColorMat(mat, kRGBwhite.GlColor());
  List<VM.Vector3> lights = [];
  for (Rect r in floorplan.GetTileStrips(kTileSidewalkLight)) {
    if (r.w > r.h) {
      assert(r.h == 1.0);
      List<double> pos = _PlaceLightsOnLine(r.w, kStreetLightSpacing);
      for (double p in pos) {
        if (rng.nextInt(50) != 0) {
          // Do we need to add 0.5 fudge for centering?
          lights.add(
              new VM.Vector3(r.x + p + 0.5, kHeightStreetLight, r.y + 0.5));
        }
      }
    } else {
      assert(r.w == 1.0);
      List<double> pos = _PlaceLightsOnLine(r.h, kStreetLightSpacing);
      for (double p in pos) {
        if (rng.nextInt(50) != 0) {
          // Do we need to add 0.5 fudge for centering?
          lights.add(
              new VM.Vector3(r.x + 0.5, kHeightStreetLight, r.y + p + 0.5));
        }
      }
    }
  }
  for (VM.Vector3 v in lights) {
    shape.AddPoint(v, 1300.0 + 500.0 * rng.nextDouble(), streetLightMat);
  }
  log.LogInfo("Created ${lights.length} street lights using points");
  return ConvertToChronosGLSingle("pointlight", cgl, shape)
    ..moveForward(xzoffset + 0.0)
    ..moveLeft(xzoffset + 0.0);
}

Node MakeCarLightInstancer(ChronosGL cgl, Floorplan floorplan) {
  FaceMat mat = new FaceMat("headlight")
    ..canvas = MakeCanvasHeadLights()
    ..depthWrite = false
    ..clamp = true
    ..transparent = true;
  Shape c = new Shape();
  AddCar(c, new ColorMat(mat, kRGBwhite.GlColor()));

  int count = floorplan.GetCars().length - 1;
  InstancerData instancer = new InstancerData("cars", cgl, count);
  Float32List translations = new Float32List(count * 3);
  Float32List rotations = new Float32List(count);
  instancer.AddBuffer(iaRotatationY, rotations);
  instancer.AddBuffer(iaTranslation, translations);

  return ConvertToChronosGLSingleWithInstancer(
      "car instancer", cgl, c, instancer);
}

Node MakeCarBodyInstancer(ChronosGL cgl, Floorplan floorplan) {
  FaceMat mat = new FaceMat("SolidCarBody");
  int count = floorplan.GetCars().length - 1;
  Shape c = new Shape();
  AddCarBody(c, new ColorMat(mat, kRGBblack.GlColor()));

  InstancerData instancer = new InstancerData("cars", cgl, count);
  Float32List translations = new Float32List(count * 3);
  Float32List rotations = new Float32List(count);
  instancer.AddBuffer(iaRotatationY, rotations);
  instancer.AddBuffer(iaTranslation, translations);

  return ConvertToChronosGLSingleWithInstancer("car-body", cgl, c, instancer);
}

void HandleCommand(String cmd, String param) {
  log.LogInfo("HandleCommand: ${cmd} ${param}");
  switch (cmd) {
    case "A":
      Toggle(HTML.querySelector(".about"));
      break;
    case "C":
      Toggle(HTML.querySelector(".config"));
      gOptions.SaveToLocalStorage();
      gPc.UpdateVisibility();
      break;
    case "P":
      Toggle(HTML.querySelector(".performance"));
      break;
    case "R":
      gOptions.SaveToLocalStorage();
      HTML.window.location.hash = "";
      HTML.window.location.reload();
      break;
    case "A+":
      Show(HTML.querySelector(".about"));
      break;
    case "A-":
      Hide(HTML.querySelector(".about"));
      break;
    case "F":
      ToggleFullscreen();
      break;
    case "C-":
      Hide(HTML.querySelector(".config"));
      gOptions.SaveToLocalStorage();
      gPc.UpdateVisibility();
      break;
    case "C+":
      Show(HTML.querySelector(".config"));
      break;
    case "X":
      String preset =
          (HTML.querySelector("#preset") as HTML.SelectElement).value;
      gOptions.SetNewSettings(preset);
      gPc.UpdateVisibility();
      HTML.window.location.reload();
      break;
    default:
      break;
  }
}

double GetSkyHue(Math.Random rng) {
  double skyHue = rng.nextDouble();
  String color = gOptions.Get(oSkyColor);
  if (color != "random") {
    RGB rgb = new RGB.fromName(color);
    skyHue = rgb.Hue();
  }
  log.LogInfo("Sky: ${color} ${skyHue}");
  assert(skyHue >= 0.0 && skyHue <= 1.0);
  return skyHue;
}

VM.Vector4 GetWireframeColor(Math.Random rng) {
  String color = gOptions.Get(oWireframeColor);
  if (color == "random") {
    return new VM.Vector4(
        rng.nextDouble(), rng.nextDouble(), rng.nextDouble(), 1.0);
  }
  RGB rgb = new RGB.fromName(color);
  return rgb.GlColorWithAlpha(1.0);
}

class ShaderSet {
  RenderProgram basic;
  RenderProgram street;
  RenderProgram instanced;
  RenderProgram lights;
  RenderProgram pulselights;

  ShadowMap shadowmap;
}

class PC {
  Floorplan _floorplan;
  WorldConfig _wc;
  final int _xzoffset;

  Node _sky;
  Node _floor;
  Node _car_light_instancer;
  List<Node> _buildings;
  Node _street_lights;
  Node _car_body_instancer;

  PC(ChronosGL cgl, Math.Random rng, int dimension, this._xzoffset,
      List<String> logos, String mode) {
    _wc = new WorldConfig(dimension);
    log.LogInfo("Floorplan creation start ${_wc.Dimension()}");
    _floorplan = new Floorplan(_wc, rng);
    log.LogInfo("Floorplan created");

    Map<int, int> histo = _floorplan.world_map.TileHistogram();
    for (int k in histo.keys) {
      log.LogDebug("Tile $k -> ${histo[k]}");
    }

    log.LogInfo("Texture creation start");

    log.LogInfo("Mesh creation start");
    _sky = MakeSky(cgl, rng, GetSkyHue(rng), 30, _wc.Dimension() / 1.41,
        _wc.Dimension() / 2);

    _buildings = MakeBuildings(
        cgl, _xzoffset, rng, _floorplan.GetBuildings(), logos, mode);

    switch (mode) {
      case kModeNight:
        _floor = MakeGround(cgl, _floorplan, _wc.Dimension(), _xzoffset,
            new RGB.fromGray(0x10), new RGB.fromGray(0x15));
        _street_lights =
            MakeStreetLightsPoints(cgl, _xzoffset, rng, _floorplan);
        _car_light_instancer = MakeCarLightInstancer(cgl, _floorplan);
        _car_body_instancer = MakeCarBodyInstancer(cgl, _floorplan);
        break;
      case kModeWireframe:
        _floor = MakeGround(cgl, _floorplan, _wc.Dimension(), _xzoffset,
            new RGB.fromGray(0x20), new RGB.fromGray(0x30));
        _street_lights =
            MakeStreetLightsPoints(cgl, _xzoffset, rng, _floorplan);
        _car_light_instancer = MakeCarLightInstancer(cgl, _floorplan);
        _car_body_instancer = MakeCarBodyInstancer(cgl, _floorplan);
        break;
      case kModeDay:
      case kModeShadow:
        _floor = MakeGround(cgl, _floorplan, _wc.Dimension(), _xzoffset,
            new RGB.fromGray(0x80), new RGB.fromGray(0xa0));
        _street_lights = new Node.Container("no lights");
        _car_light_instancer = new Node.Container("no car light");
        _car_body_instancer = MakeCarBodyInstancer(cgl, _floorplan);
        break;
      default:
        assert(false, "bad mode ${mode}");
    }

    log.LogInfo("Mesh creation done");
  }

  int GetDimension() {
    return _wc.Dimension();
  }

  Car GetCameraCar() {
    return _floorplan.GetCars()[0];
  }

  void UpdateVisibility() {
    if (_car_light_instancer == null) return;
    bool showCars = gOptions.GetBool("showCars");
    _car_light_instancer.enabled = showCars;

    bool showBuildings = gOptions.GetBool("showBuildings");
    for (Node m in _buildings) {
      m.enabled = showBuildings;
    }
  }

  void AttachToPrograms(WebGL.RenderingContext gl, ShaderSet shaders) {
    log.LogInfo("AttachToPrograms");

    for (Node m in _buildings) {
      if (m.material.name == "pointlightFlash") {
        print("attaching ${m.name} to flashing");
        shaders.pulselights.add(m);
      } else if (m.material.name == "pointlight") {
        print("attaching ${m.name} to light");
        shaders.lights.add(m);
      } else {
        print("attaching ${m.name} to basic");
        shaders.basic.add(m);
        if (shaders.shadowmap != null) shaders.shadowmap.AddShadowCaster(m);
      }
    }

    shaders.basic.add(_sky);
    shaders.street.add(_floor);

    shaders.instanced.add(_car_light_instancer);
    shaders.instanced.add(_car_body_instancer);

    shaders.lights.add(_street_lights);

    log.LogInfo("AttachToPrograms done");
  }

  void ShowCars(bool enabled) {
    _car_body_instancer.enabled = enabled;
    _car_light_instancer.enabled = enabled;
  }

  void ShowSky(bool enabled) {
    _sky.enabled = enabled;
  }

  void Animate(Math.Random rng, double elapsed) {
    _floorplan.UpdateCars(rng, elapsed);
    int n = _floorplan.GetCars().length;
    Float32List translations = new Float32List(n * 3 - 3);
    Float32List rotations = new Float32List(n - 1);
    // first car is for camera
    int t = 0;
    int r = 0;
    for (int i = 1; i < n; i++) {
      Car c = _floorplan.GetCars()[i];
      PosDouble p = c.Pos();
      translations[t + 0] = p.x + 0.5 - _xzoffset;
      translations[t + 1] = kCarLevel;
      translations[t + 2] = p.y + 0.5 - _xzoffset;
      t += 3;
      rotations[r] = -c.Dir() * (Math.PI / 180.0) + Math.PI;
      r += 1;
    }
    for (InstancerData instancer in [
      _car_light_instancer.instancerData,
      _car_body_instancer.instancerData,
    ]) {
      if (instancer == null) continue;
      instancer.ChangeBufferCanonical(iaTranslation, translations);
      instancer.ChangeBufferCanonical(iaRotatationY, rotations);
    }
  }
}

Map<String, int> _NameToSize = {
  "small": 512,
  "medium": 1024,
  "large": 2048,
  "xlarge": 4096,
  "default": 1024,
};

void RegisterEventHandlers() {
  HTML.document.body.onKeyDown.listen((HTML.KeyboardEvent e) {
    log.LogInfo("key pressed ${e.keyCode} ${e.target.runtimeType}");
    if (e.target.runtimeType == HTML.InputElement) {
      return;
    }
    String cmd = new String.fromCharCodes([e.keyCode]);
    HandleCommand(cmd, "");
  });

  HTML.ElementList<HTML.Element> buttons =
      HTML.document.body.querySelectorAll("button");
  log.LogInfo("found ${buttons.length} buttons");

  buttons.onClick.listen((HTML.Event ev) {
    String cmd = (ev.target as HTML.Element).dataset['cmd'];
    String param = (ev.target as HTML.Element).dataset['param'];
    HandleCommand(cmd, param);
  });

  HTML.querySelector("#area").onDoubleClick.listen((HTML.MouseEvent ev) {
    log.LogInfo("click area ${ev.target.runtimeType}");
    HandleCommand("C", "");
  });

  HTML.window.onResize.listen((event) => UpdateAll());
}

void main2() {
  IntroduceNewShaderVar(
      uFlashing,
      new ShaderVarDesc("float",
          "Dummy uniform not used by any shader to signal flashing point lights"));
  IntroduceNewShaderVar(iaRotatationY,
      new ShaderVarDesc("float", "for cars: rotation around y axis"));
  IntroduceNewShaderVar(uFogColor, new ShaderVarDesc(VarTypeVec3, ""));
  IntroduceNewShaderVar(uFogScale, new ShaderVarDesc(VarTypeFloat, ""));
  IntroduceNewShaderVar(uFogEnd, new ShaderVarDesc(VarTypeFloat, ""));

  ProgressReporter pr = new ProgressReporter(HTML.querySelector("#progress"));
  pr.Start(); // Using the  ProgressReporter properly is hard without major refactoring
  if (!HasWebGLSupport()) {
    pr.SetTask("Your browser does not support WebGL.");
    return;
  }
  OptionsSetup();
  RegisterEventHandlers();
  UpdateAll();
  Math.Random rng = gRng;

  DateTime initStart = new DateTime.now();
  log.LogInfo("Initialize WebGL");
  final String size = gOptions.Get(oWorldSize);
  final int dim = _NameToSize.containsKey(size)
      ? _NameToSize[size]
      : _NameToSize["default"];
  final int xzoffset = dim ~/ 2;
  HTML.CanvasElement canvas = HTML.querySelector("#area") as HTML.CanvasElement;
  ChronosGL chronosGL = new ChronosGL(canvas);

  // activate the extension
  var ext = GetGlExtensionAnisotropic(chronosGL);
  if (ext == null) {
    LogError("No anisotropic texture extension");
  }

  List<DrawStats> drawStats = new List<DrawStats>();

  OrbitCamera orbit = new OrbitCamera(150.0, 0.0, 0.0, canvas);
  orbit.mouseWheelFactor = -0.1;
  Perspective perspective = new Perspective(orbit, 1.0, 10000.0);

  VM.Vector3 dirLight = new VM.Vector3(2.0, -1.2, 0.5);

  final mode = gOptions.Get(oMode);
  Illumination illumination = new Illumination();
  Light light =
      new DirectionalLight("dir", dirLight, ColorWhite, ColorWhite, dim / 2);
  illumination.AddLight(light);

  RenderPhase phaseMain = new RenderPhase("main", chronosGL);

  ShaderSet shaders = new ShaderSet();
  // NOTE: INITIALIZATION ORDER IS IMPORTANT - TRANSPARENT  SHADERS GO LAST!
  switch (mode) {
    case kModeNight:
      shaders
        ..basic = phaseMain.createProgram(pcTexturedShaderWithFog())
        ..street = shaders.basic
        ..instanced = phaseMain.createProgram(pcTexturedShaderWithInstancer())
        ..lights = phaseMain.createProgram(pcPointSpritesShader())
        ..pulselights = phaseMain.createProgram(pcPointSpritesFlashingShader());
      break;
    case kModeDay:
      shaders
        ..basic = phaseMain.createProgram(pcTexturedShader())
        ..street = shaders.basic
        ..instanced = phaseMain.createProgram(pcTexturedShaderWithInstancer())
        ..lights = phaseMain.createProgram(pcPointSpritesShader())
        ..pulselights = phaseMain.createProgram(pcPointSpritesFlashingShader());
      break;
    case kModeShadow:
      VM.Matrix4 lm = light.ExtractShadowProjViewMatrix();

      shaders
        ..basic = phaseMain.createProgram(pcTexturedShaderWithShadow())
        ..street = shaders.basic
        ..instanced = phaseMain.createProgram(pcTexturedShaderWithInstancer())
        ..lights = phaseMain.createProgram(pcPointSpritesShader())
        ..pulselights = phaseMain.createProgram(pcPointSpritesFlashingShader())
        ..shadowmap = new ShadowMapDepth16(chronosGL, dim * 8, dim * 8);
      shaders.basic
        ..SetInput(uLightPerspectiveViewMatrix, lm)
        ..SetInput(uShadowMap, shaders.shadowmap.GetMapTexture())
        ..SetInput(uCanvasSize, shaders.shadowmap.GetMapSize());
      break;
    case kModeWireframe:
      VM.Vector4 color = GetWireframeColor(rng);
      VM.Vector4 color2 = color * 0.1;
      color2.a = 1.0;
      shaders
        ..basic = phaseMain.createProgram(createWireframeShader())
        ..street = phaseMain.createProgram(pcTexturedShader())
        ..instanced = phaseMain.createProgram(pcTexturedShaderWithInstancer())
        ..lights = phaseMain.createProgram(pcPointSpritesShader())
        ..pulselights = phaseMain.createProgram(pcPointSpritesFlashingShader());
      shaders.basic
        ..SetInput(uColorAlpha, color)
        ..SetInput(uColorAlpha2, color2);
      break;
    default:
      assert(false, "unknown mode ${mode}");
  }

  List<String> logos = GetBuildingLogos(rng);
  if (gOptions.Get(oLogo) != "") {
    logos[0] = gOptions.Get(oLogo);
  }

  defaultAnisoLevel = ext == null ? 1 : 4;

  log.LogInfo("Create World ${mode}");
  gPc = new PC(chronosGL, rng, dim, xzoffset, logos, mode);
  gPc.AttachToPrograms(chronosGL.gl, shaders);
  gPc.UpdateVisibility();
  log.LogInfo("World has been created");
  pr.End();

  Map<String, MyCamera> cameraAnimations = {
    "user": new ManualCamera(0.0),
    "userOrbit": new ManualCamera(0.001),
    //
    "rotateNear":
        new RotatingCamera(0.0, dim * 0.1, 10.0, 1 / (dim * 10.0), Math.PI),
    "rotateFar":
        new RotatingCamera(0.0, dim * 0.2, 10.0, 1 / (dim * 10.0), Math.PI),
    "orbitOuter":
        new RotatingCamera(dim * 0.3, 0.0, 10.0, 1 / (dim * 20.0), 0.0),
    "orbitInner":
        new RotatingCamera(dim * 0.1, 0.0, 10.0, 1 / (dim * 20.0), 0.0),
    "carFront": new FollowCarCamera(gPc.GetCameraCar(), xzoffset, 15.0, 0),
    "carBack": new FollowCarCamera(gPc.GetCameraCar(), xzoffset, 15.0, 180),
    "carRight": new FollowCarCamera(gPc.GetCameraCar(), xzoffset, 15.0, 90),
    "carLeft": new FollowCarCamera(gPc.GetCameraCar(), xzoffset, 15.0, 270),
  };

  String lastCameraMode = "";
  void animateCam(double elapsed, double now) {
    String mode = gOptions.Get(oCameraMode);
    if (cameraAnimations.containsKey(mode)) {
      if (mode != lastCameraMode) {
        log.LogInfo("new camera: " + mode);
        cameraAnimations[mode].init();
        lastCameraMode = mode;
      }
      cameraAnimations[mode].animate(orbit, elapsed, now);
    } else {
      log.LogError("unknown camera mode ${mode}");
    }
  }

  void updateFps(double elapsed, double time) {
    int programChanges = 0;
    int calls = 0;
    int elements = 0;
    String last = "@@@";
    for (DrawStats d in drawStats) {
      if (d.name != last) {
        programChanges += 1;
        last = d.name;
      }
      calls += 1;
      elements += d.numItems;
    }
    drawStats.clear();
    UpdateFrameCount(time, gFps,
        "programs: ${programChanges}  calls: ${calls} elements: ${elements}\naniso: ${defaultAnisoLevel}");
  }

  Show(HTML.querySelector(".about"));
  if (gOptions.GetBool(oHideAbout)) {
    var delay = const Duration(seconds: 4);
    new Timer(delay, () => Hide(HTML.querySelector(".about")));
  }

  void resolutionChange(HTML.Event ev) {
    int w = canvas.clientWidth;
    int h = canvas.clientHeight;
    canvas.width = w;
    canvas.height = h;
    print("size change $w $h");
    perspective.AdjustAspect(w, h);
    phaseMain.viewPortW = w;
    phaseMain.viewPortH = h;
  }

  resolutionChange(null);
  HTML.window.onResize.listen(resolutionChange);

  double _lastTimeMs = 0.0;
  if (shaders.shadowmap != null) {
    shaders.shadowmap.Compute(light.ExtractShadowProjViewMatrix());
  }

  void animate(timeMs) {
    timeMs = timeMs + 0.0; // force double
    double elapsed = timeMs - _lastTimeMs;
    _lastTimeMs = timeMs;

    updateFps(elapsed, timeMs);

    gPc.Animate(gRng, elapsed);
    animateCam(elapsed, timeMs);

    shaders.pulselights.ForceInput(uTime, timeMs / 1000.0);

    final double fogEnd = gPc.GetDimension() * gOptions.GetDouble(oFog);
    final double fogScale = 1.0 / fogEnd;

    shaders.basic
      ..ForceInput(uFogColor, kColorBlack)
      ..ForceInput(uFogEnd, fogEnd)
      ..ForceInput(uFogScale, fogScale);

    perspective.UpdateFov(0.0 + gOptions.GetInt(oFov));
    if (gOptions.GetBool(oCull)) {
      chronosGL.gl.enable(WebGL.CULL_FACE);
    } else {
      chronosGL.gl.disable(WebGL.CULL_FACE);
    }
    gPc.ShowCars(gOptions.GetBool(oShowCars));
    gPc.ShowSky(gOptions.GetBool(oShowSky));

    phaseMain.draw([perspective, illumination]);

    HTML.window.animationFrame.then(animate);
  }

  DateTime initEnd = new DateTime.now();
  LogInfo("====================================");
  LogInfo("Initialization Duration: ${initEnd.difference(initStart)}");
  LogInfo("====================================");
  gPc.Animate(rng, 0.1);
  animate(0.0);
}

void main() {
  try {
    main2();
  } catch (exception, stackTrace) {
    HTML.window.alert("Exception: ${exception}\nStack: ${stackTrace}");
  }
}
