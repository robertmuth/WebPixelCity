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

/*
Show a single building of the selected types
TODO: this needs to share some more rendering code with pixelcity.dart
*/

import 'dart:html' as HTML;
import 'dart:math' as Math;

import 'package:vector_math/vector_math.dart' as VM;
import 'package:chronosgl/chronosgl.dart';

import 'rgb.dart';
import 'building.dart';
import 'config.dart';
import 'geometry.dart';
import 'street.dart';
import 'facade.dart';
import 'shaders.dart';
import 'renderer.dart';
import 'logging.dart' as log;

Math.Random gRng = new Math.Random();

const int kWorldDim = 1024 ~/ 4;

List<Node> MakeScene(ChronosGL cgl, Math.Random rng, BuildingParameters params,
    RoofOptions roofOpt, String style) {
  ColorMat floorMat = new ColorMat(params.solidMat, kRGBblue.GlColor());
  Shape g = new Shape();
  g.AddQuad(MakeFloor(kWorldDim * 1.0, kWorldDim * 1.0), floorMat);
  Rect base = new Rect(kWorldDim / 2, kWorldDim / 2, 30.0, 30.0);
  double height = 60.0;
  switch (style) {
    case "Modern":
      var opt = new BuildingModernOptions(rng, params, true);
      AddBuildingModern(g, rng, base, height, opt);
      break;
    case "Simple":
      var opt = new BuildingSimpleOptions(rng, params);
      AddBuildingSimple(g, rng, base, height, opt);
      break;
    case "Tower":
      var opt = new BuildingTowerOptions(rng, params, true);
      AddBuildingTower(g, rng, base, height, opt, roofOpt);
      break;
    case "Blocky":
      var opt = new BuildingBlockyOptions(rng, params);
      AddBuildingBlocky(g, rng, base, height, opt, roofOpt);
      break;
    default:
      HTML.window.alert("Unknown building style ${style}");
      break;
  }

  List<Node> meshes = ConvertToChronosGL(cgl, g);
  int xzoffset = kWorldDim ~/ 2.0;
  for (int i = 0; i < meshes.length; i++) {
    meshes[i]
      ..moveForward(xzoffset + 0.0)
      ..moveLeft(xzoffset + 0.0);
  }
  return meshes;
}

void onWindowResize(event) {
  HTML.CanvasElement canvas = HTML.document.getElementById("area");
  canvas.width = HTML.window.innerWidth;
  canvas.height = HTML.window.innerHeight;
}

final HTML.SelectElement gStyle =
    HTML.document.querySelector('#buildingStyle') as HTML.SelectElement;

final HTML.SelectElement gMode =
    HTML.document.querySelector('#mode') as HTML.SelectElement;

final HTML.ButtonElement gRefresh =
    HTML.document.querySelector('#refresh') as HTML.ButtonElement;

final int gShadowMapW = 512;
final int gShadowMapH = 512;

class ShaderSet {
  RenderProgram basic;
  RenderProgram basicRegular;
  RenderProgram basicWithShadow;
  RenderProgram basicWireframe;
  RenderProgram lights;
  RenderProgram pulselights;
  ShadowMap shadowMap;

  ShaderSet(RenderPhase phaseMain, Light light, ShadowMap sm) {
    VM.Matrix4 lm = light.ExtractShadowProjViewMatrix();
    shadowMap = sm;
    basicRegular = phaseMain.createProgram(pcTexturedShader());
    basicWireframe = phaseMain.createProgram(createWireframeShader())
      ..SetInput(uColorAlpha, new VM.Vector4(1.0, 1.0, 0.0, 1.0))
      ..SetInput(uColorAlpha2, new VM.Vector4(0.1, 0.1, 0.1, 1.0));
    basicWithShadow = phaseMain.createProgram(pcTexturedShaderWithShadow())
      ..SetInput(uLightPerspectiveViewMatrix, lm)
      ..SetInput(uShadowMap, sm.GetMapTexture())
      ..SetInput(uCanvasSize, sm.GetMapSize());

    lights = phaseMain.createProgram(pcPointSpritesShader());
    pulselights = phaseMain.createProgram(pcPointSpritesFlashingShader());
  }
}

void main() {
  log.LogInfo("starting");
  IntroduceNewShaderVar(
      uFlashing,
      new ShaderVarDesc("float",
          "Dummy uniform not used by any shader to signal flashing point lights"));
  IntroduceNewShaderVar(iaRotatationY,
      new ShaderVarDesc("float", "for cars: rotation around y axis"));
  IntroduceNewShaderVar(uFogColor, new ShaderVarDesc("vec3", ""));
  IntroduceNewShaderVar(uFogScale, new ShaderVarDesc("float", ""));
  IntroduceNewShaderVar(uFogEnd, new ShaderVarDesc("float", ""));

  HTML.CanvasElement canvas = HTML.document.getElementById('area');
  canvas.width = HTML.window.innerWidth;
  canvas.height = HTML.window.innerHeight;
  HTML.window.onResize.listen(onWindowResize);

  ChronosGL chronosGL = new ChronosGL(canvas);

  final int mafl = MaxAnisotropicFilterLevel(chronosGL);
  defaultAnisoLevel = mafl > 4 ? 4 : mafl;
  print("defaultAnisoLevel: ${defaultAnisoLevel}");

  OrbitCamera orbit = new OrbitCamera(50.0, 1.0, 0.0, canvas);
  Perspective perspective = new Perspective(orbit, 0.1, 2000.0);
  RenderPhase phaseMain = new RenderPhase("Main", chronosGL);

  orbit.addPos(0.0, 80.0, 0.0);
  orbit.mouseWheelFactor = -0.1;

  final VM.Vector3 dirLight = new VM.Vector3(1.0, -1.0, 1.0);

  final Illumination illumination = new Illumination();
  final Light light =
      new DirectionalLight("dir", dirLight, ColorWhite, ColorWhite, 200.0);
  illumination.AddLight(light);

  ShadowMap shadowMap =
      new ShadowMapDepth16(chronosGL, gShadowMapW, gShadowMapH);
  shadowMap.SetVisualizationViewPort(0, 0, gShadowMapW, gShadowMapH);

  RenderProgram fixed = phaseMain.createProgram(createSolidColorShader());
  Material lightMat = new Material("light")..SetUniform(uColor, ColorYellow);
  MeshData mdLight = EmptyLightVisualizer(chronosGL, "light");
  UpdateLightVisualizer(mdLight, light);
  fixed.add(new Node("light", mdLight, lightMat));

  print("Setup programs");
  ShaderSet shaders = new ShaderSet(phaseMain, light, shadowMap);

  List<String> logos = GetBuildingLogos(gRng);
  List<FaceMat> nightWalls = MakeWallsNight(gRng, kRGBblack);
  List<FaceMat> dayWalls = MakeWallsNight(gRng, kRGBwhite);
  FaceMat nightLogos = MakeLogo(logos, kRGBwhite, kRGBblack);
  FaceMat dayLogos = MakeLogo(logos, kRGBblack, kRGBwhite);

  void reset(String style, String mode, ShaderSet shaders) {
    print("make scene ${style} ${mode}");
    bool nightMode = mode == "Night";
    switch (mode) {
      case "day":
        shaders.basic = shaders.basicRegular;
        break;
      case "shadow":
        shaders.basic = shaders.basicWithShadow;
        break;
      case "night":
        shaders.basic = shaders.basicRegular;
        break;
      case "wireframe":
        shaders.basic = shaders.basicWireframe;
        break;
      default:
        assert(false);
        break;
    }
    shaders.basicRegular.removeAll();
    shaders.basicWireframe.removeAll();
    shaders.basicWithShadow.removeAll();
    shaders.lights.removeAll();
    shaders.pulselights.removeAll();
    shadowMap.ClearShadowCasters();

    final BuildingParameters params = new BuildingParameters()
      ..wallMats = nightMode ? nightWalls : dayWalls
      ..logoMat = nightMode ? nightLogos : dayLogos
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

    final RoofOptions roofOpt = new RoofOptions(gRng, params);

    if (!nightMode) {
      VM.Vector3 theColor =
          kDaylightBuildingColors[gRng.nextInt(kDaylightBuildingColors.length)]
              .GlColor();
      params..wallColors = [theColor];
      params..ledgeColors = [theColor];
      params..offsetColors = [theColor];
      params..baseColors = [theColor];
      roofOpt.allowLightStrip = false;
    }

    List<Node> building = MakeScene(chronosGL, gRng, params, roofOpt, style);

    for (Node m in building) {
      final dynamic mat = m.material;
      if (mat.name == "pointlightFlash") {
        shaders.pulselights.add(m);
      } else if (mat.name == "pointlight") {
        shaders.lights.add(m);
      } else {
        print("Add material ${m.material.name}");
        shaders.basic.add(m);
        shadowMap.AddShadowCaster(m);
      }
    }
  }

  gStyle.onChange.listen((HTML.Event e) {
    reset(gStyle.value, gMode.value, shaders);
  });

  gMode.onChange.listen((HTML.Event e) {
    reset(gStyle.value, gMode.value, shaders);
  });

  gRefresh.onClick.listen((HTML.MouseEvent e) {
    reset(gStyle.value, gMode.value, shaders);
    e.preventDefault();
  });

  gStyle.dispatchEvent(new HTML.Event("change"));

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
  void animate(num timeMs) {
    double elapsed = timeMs + 0.0 - _lastTimeMs;
    _lastTimeMs = timeMs;

    orbit.azimuth += 0.001;
    orbit.animate(elapsed);

    shaders.pulselights.ForceInput(uTime, timeMs / 1000.0);
    if (gMode.value == "shadow") {
      fixed.enabled = true;
      shadowMap.Compute(light.ExtractShadowProjViewMatrix());
    } else {
      fixed.enabled = false;
    }
    phaseMain.draw([perspective, illumination]);
    if (gMode.value == "shadow") {
      shadowMap.Visualize();
    }
    HTML.window.animationFrame.then(animate);
  }

  animate(0.0);
}
