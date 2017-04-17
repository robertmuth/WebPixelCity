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
This file contains the code for creating building geometries.
There are currently 4 types of buildings based on the original
version of PixelCity:
Modern
Blocky
Simple
Tower
*/

library building;

import 'dart:math' as Math;

import 'package:vector_math/vector_math.dart' as VM;

import 'config.dart';
import 'geometry.dart';
import 'logging.dart';
import 'floor_plan.dart';
import 'rgb.dart';



double GetRandom(Math.Random rng, double a, double b) {
  return rng.nextDouble() * (b - a) + a;
}

const int kMinTierHeight = 3;
const int kMaxTierHeight = 10;

int _NumTiers(int h) {
  if (h >= 40) return 15;
  if (h >= 30) return 10;
  if (h >= 20) return 5;
  if (h >= 10) return 2;
  return 1;
}

const double kRadioTowerHeight = 15.0;
const double kRadioTowerRadius = 1.0;

void _AddRadioTower(Shape shape, Math.Random rng, Rect area, double level,
    ColorMat radioTower, ColorMat pulseLight) {
  //LogInfo("add radio tower");
  final double cx = area.x + area.w / 2;
  final double cz = area.y + area.h / 2;
  final double d = kRadioTowerRadius;
  final List<VM.Vector2> uvs = [
    new VM.Vector2(0.0, 0.0),
    new VM.Vector2(1.0, 0.0),
    new VM.Vector2(0.5, kRadioTowerHeight),
  ];
  final List<VM.Vector3> p = [
    new VM.Vector3(cx - d, level, cz + d),
    new VM.Vector3(cx + d, level, cz + d),
    new VM.Vector3(cx + d, level, cz - d),
    new VM.Vector3(cx - d, level, cz - d),
  ];

  final VM.Vector3 tip = new VM.Vector3(cx, level + kRadioTowerHeight, cz);

  for (int i = 0; i < 4; i++) {
    shape.AddTriad(new Triad([p[i], p[(i + 1) % 4], tip], uvs), radioTower);
  }
  shape.AddPoint(tip, 1500.0, pulseLight);
}

int kBaseHeight = 2;

List<int> kSkipDistances = [30, 60, 90];

// skip distance  -> segment length (normalized by radius):
//  10 deg                     = 2 * 0.0874
//  30 deg  2 * (2-sqrt(3))    = 2 * 0.2679
//  60 deg  2 * sqrt(1/3)      = 2 * 0.5773
//  90 deg  2 * 1              = 2 * 1.0000
List<VM.Vector2> MakeModernShape(Math.Random rng, Rect base) {
  double r = Math.min(base.w, base.h) / 2.0;
  double cx = base.x + base.w / 2;
  double cy = base.y + base.h / 2;
  int skip_interval = 1 + rng.nextInt(8);
  int skip_distance = kSkipDistances[rng.nextInt(kSkipDistances.length)];
  int num_normals = 0;
  List<VM.Vector2> out = [];
  for (int angle = 0; angle <= 360; angle += 10) {
    if (num_normals >= skip_interval && angle + skip_distance <= 360) {
      angle += skip_distance;
      num_normals = 0;
    } else {
      num_normals += 1;
    }
    double x = cx + r * Math.cos(angle / 180 * Math.PI);
    double y = cy + r * Math.sin(angle / 180 * Math.PI);
    out.add(new VM.Vector2(x, y));
  }
  return out;
}

void _AddFan(Shape g, double cx, double cy, double height,
    List<VM.Vector2> points, ColorMat material) {
  VM.Vector2 last = points.last;
  for (VM.Vector2 p in points) {
    Triad t = new Triad([
      new VM.Vector3(p.x, height, p.y),
      new VM.Vector3(last.x, height, last.y),
      new VM.Vector3(cx, height, cy)
    ]);
    g.AddTriad(t, material);
    last = p;
  }
}

class BuildingParameters {
  List<FaceMat> wallMats;
  FaceMat solidMat;
  FaceMat logoMat;
  FaceMat lightTrimMat;
  FaceMat pointLightMat;
  FaceMat flashingLightMat;
  FaceMat radioTowerMat;

  List<VM.Vector3> wallColors;
  List<VM.Vector3> baseColors;
  List<VM.Vector3> ledgeColors;
  List<VM.Vector3> offsetColors;
  List<VM.Vector3> acColors;
  int num_logos;

  ColorMat RandomWallColorMat(Math.Random rng) {
    FaceMat texture = wallMats[rng.nextInt(wallMats.length)];
    VM.Vector3 color = wallColors[rng.nextInt(wallColors.length)];
    return new ColorMat(texture, color);
  }

  ColorMat RandomBaseColorMat(Math.Random rng) {
    VM.Vector3 color = baseColors[rng.nextInt(baseColors.length)];
    return new ColorMat(solidMat, color);
  }

  ColorMat RandomLedgeColorMat(Math.Random rng) {
    VM.Vector3 color = ledgeColors[rng.nextInt(ledgeColors.length)];
    return new ColorMat(solidMat, color);
  }

  ColorMat RandomOffsetColorMat(Math.Random rng) {
    VM.Vector3 color = offsetColors[rng.nextInt(offsetColors.length)];
    return new ColorMat(solidMat, color);
  }

  ColorMat RandomACColorMat(Math.Random rng) {
    VM.Vector3 color = acColors[rng.nextInt(acColors.length)];
    return new ColorMat(solidMat, color);
  }

  int RandomLogo(Math.Random rng) {
    return rng.nextInt(num_logos);
  }
}

// A roundish building
class BuildingModernOptions {
  double capHeight;
  ColorMat windowMat;
  int logoIndex = -1;
  int maxLogos = 0;
  int trimIndex = -1;

  ColorMat offsetMat;
  ColorMat logoMat;
  ColorMat trimLightMat;

  BuildingModernOptions(Math.Random rng, BuildingParameters params, bool tall) {
    capHeight = 1.0 + rng.nextInt(tall ? 5 : 1);
    windowMat = params.RandomWallColorMat(rng);
    offsetMat = params.RandomOffsetColorMat(rng);
    logoMat = new ColorMat(params.logoMat, kRGBwhite.GlColor());
    trimLightMat = new ColorMat(params.lightTrimMat, kRGBwhite.GlColor());
    if (!tall) return;

    if (capHeight > 2.0 && rng.nextBool()) {
      maxLogos = capHeight > 1.0 ? 2 : 0;

      logoIndex = params.RandomLogo(rng);
    }

    if (capHeight > 1.0 && rng.nextInt(4) == 0) {
      trimIndex = GetLightTrimPatternForContinous(rng);
    }
  }
}

//int NumLogoSurfacesModern(List<Vector2> points) {
//  int n;
//  Vector2 last = points.last;
//  for (Vector2 p in points) {
//    double len = p.distanceTo(last);
//    if (len > 10.0) n++;
//  }
//  return n;
//}

List<VM.Vector3> StdFace(
    double x1, double x2, double z1, double z2, double h1, double h2) {
  return [
    new VM.Vector3(x2, h1, z2),
    new VM.Vector3(x2, h2, z2),
    new VM.Vector3(x1, h2, z1),
    new VM.Vector3(x1, h1, z1),
  ];
}

void AddBuildingModern(Shape g, Math.Random rng, Rect base, double height,
    BuildingModernOptions o) {
  List<VM.Vector2> points = MakeModernShape(rng, base);

  Quad q;

  int logosLeft = o.maxLogos;
  // TODO: add fudge factor to not get fractional windows
  VM.Vector2 last = points.first;
  double windowOffset = 0.0;

  //LogInfo("Continous trim index: ${o.trimIndex}");
  // Go around the building
  for (VM.Vector2 p in points.reversed) {
    double len = p.distanceTo(last);
    // The len is measure in "windows"
    Rect uvxy = GetWindowUVContinous(windowOffset, len, height);
    List<VM.Vector3> MyStdFace(double h1, double h2) {
      return StdFace(last.x, p.x, last.y, p.y, h1, h2);
    }

    // main facade
    q = new Quad(MyStdFace(0.0, height), uvxy);
    g.AddQuad(q, o.windowMat);
    // roof
    if (o.logoIndex != -1) {
      if (len > 10.0 && logosLeft > 0) {
        Rect uvLogos = GetLogoUV(o.logoIndex);
        q = new Quad(MyStdFace(height, height + o.capHeight), uvLogos);
        g.AddQuad(q, o.logoMat);
        logosLeft--;
      } else {
        q = new Quad(MyStdFace(height, height + o.capHeight), kFullUV);
        g.AddQuad(q, o.offsetMat);
      }
    } else if (o.trimIndex != -1) {
      double h1 = o.capHeight - 2.0;
      double h2 = 1.0;
      double h3 = 1.0;
      if (h1 > 0.0) {
        q = new Quad(MyStdFace(height, height + h1), kFullUV);
        g.AddQuad(q, o.offsetMat);
      }
      q = new Quad(MyStdFace(height + h1 + h2, height + h1 + h2 + h3), kFullUV);
      g.AddQuad(q, o.offsetMat);

      Rect uvxy = GetLightTrimUVContinous(o.trimIndex, windowOffset, len);
      q = new Quad(MyStdFace(height + h1, height + h1 + h2), uvxy);
      g.AddQuad(q, o.trimLightMat);
    } else {
      q = new Quad(MyStdFace(height, height + o.capHeight), kFullUV);
      g.AddQuad(q, o.offsetMat);
    }
    last = p;
    windowOffset += len;
  }

  double cx = base.x + base.w / 2;
  double cy = base.y + base.h / 2;
  _AddFan(g, cx, cy, height + o.capHeight, points, o.offsetMat);
}

void _AddAC(Shape g, Rect roof, double level, Math.Random rng, ColorMat mat) {
  double dim = rng.nextInt(30) / 10.0 + 1.0;
  if (dim > roof.w - 1.0) {
    dim = roof.w - 1.0;
  }
  if (dim > roof.h - 1.0) {
    dim = roof.h - 1.0;
  }
  double ac_h = rng.nextInt(20) / 10.0 + 1.0;
  // center of ac
  double ac_x = GetRandom(rng, roof.x + 0.5, roof.x + roof.w - dim - 0.5);
  double ac_z = GetRandom(rng, roof.y + 0.5, roof.y + roof.h - dim - 0.5);
  Rect base = new Rect(ac_x, ac_z, dim, dim);
  assert(roof.Contains(base));
  _AddBox(g, base, ac_h, level, mat);
}

void _AddBox(
    Shape g, Rect base, double height, double level, ColorMat material) {
  assert(height >= 1.0);
  // front + back
  Rect bxy = new Rect(base.x, level, base.w, height);
  g.AddQuad(new Quad.fromXY(bxy, base.y, true, kFullUV), material);
  g.AddQuad(new Quad.fromXY(bxy, base.y + base.h, false, kFullUV), material);
  // left + right
  Rect bzy = new Rect(base.y, level, base.h, height);
  g.AddQuad(new Quad.fromZY(bzy, base.x, false, kFullUV), material);
  g.AddQuad(new Quad.fromZY(bzy, base.x + base.w, true, kFullUV), material);
  // top + bottom
  //g.AddQuad(new Quad.fromXZ(base, level, false, kFullUV), material);
  g.AddQuad(new Quad.fromXZ(base, level + height, true, kFullUV), material);
}

void _AddLightStripCylinder(Shape g, Math.Random rng, Rect base, double height,
    double level, ColorMat trimMat, ColorMat otherMat) {
  int pattern = GetLightTrimPatternForCentered(rng, base.w, base.h);
  {
    // front + back
    double o = GetLightTrimCenteredOffset(pattern, base.w);
    assert(o < base.w);
    Rect bxy = new Rect(base.x + o, level, base.w - 2 * o, height);
    Rect uvxy = GetLightTrimCenteredUV(pattern, bxy);
    g.AddQuad(new Quad.fromXY(bxy, base.y, true, uvxy), trimMat);
    g.AddQuad(new Quad.fromXY(bxy, base.y + base.h, false, uvxy), trimMat);
    Rect l = new Rect(base.x, level, o, height);
    g.AddQuad(new Quad.fromXY(l, base.y, true, uvxy), otherMat);
    g.AddQuad(new Quad.fromXY(l, base.y + base.h, false, uvxy), otherMat);
    Rect r = new Rect(base.x + base.w - o, level, o, height);
    g.AddQuad(new Quad.fromXY(r, base.y, true, uvxy), otherMat);
    g.AddQuad(new Quad.fromXY(r, base.y + base.h, false, uvxy), otherMat);
  }
  {
    // left + right
    double o = GetLightTrimCenteredOffset(pattern, base.h);
    assert(o < base.h);
    Rect bzy = new Rect(base.y + o, level, base.h - 2 * o, height);
    Rect uvzy = GetLightTrimCenteredUV(pattern, bzy);
    g.AddQuad(new Quad.fromZY(bzy, base.x, false, uvzy), trimMat);
    g.AddQuad(new Quad.fromZY(bzy, base.x + base.w, true, uvzy), trimMat);

    Rect l = new Rect(base.y, level, o, height);
    g.AddQuad(new Quad.fromZY(l, base.x, false, uvzy), otherMat);
    g.AddQuad(new Quad.fromZY(l, base.x + base.w, true, uvzy), otherMat);
    Rect r = new Rect(base.y + base.h - o, level, o, height);
    g.AddQuad(new Quad.fromZY(r, base.x, false, uvzy), otherMat);
    g.AddQuad(new Quad.fromZY(r, base.x + base.w, true, uvzy), otherMat);
  }
}

void _AddSimpleRoof2(
    Shape g, Rect base, double height, double level, ColorMat mat) {
  Quad q = new Quad.fromXZ(base, level + height, true, kFullUV);
  g.AddQuad(q, mat);
}

void _AddWindowCylinder(Shape g, Math.Random rng, Rect base, double height,
    double level, ColorMat windowMat, ColorMat offsetMat,
    [double cornerOffset = 0.0]) {
  Rect uvxy;
  // front + back
  void AddXY(Rect rect, Rect uv, double offset, bool front, double z) {
    g.AddQuad(new Quad.fromXY(rect, z, front, uv), windowMat);
    if (offset > 0.0) {
      Rect rect1 = new Rect(rect.x - offset, rect.y, offset, rect.h);
      g.AddQuad(new Quad.fromXY(rect1, z, front, kFullUV), offsetMat);
      Rect rect2 = new Rect(rect.x + rect.w, rect.y, offset, rect.h);
      g.AddQuad(new Quad.fromXY(rect2, z, front, kFullUV), offsetMat);
    }
  }

  Rect bxy =
      new Rect(base.x + cornerOffset, level, base.w - 2 * cornerOffset, height);
  uvxy = GetWindowUV(rng, bxy.w, bxy.h);
  AddXY(bxy, uvxy, cornerOffset, true, base.y);
  AddXY(bxy, uvxy, cornerOffset, false, base.y + base.h);

  // left + right
  void AddZY(Rect rect, Rect uv, double offset, bool front, double z) {
    g.AddQuad(new Quad.fromZY(rect, z, front, uv), windowMat);
    if (offset > 0.0) {
      Rect rect1 = new Rect(rect.x - offset, rect.y, offset, rect.h);
      g.AddQuad(new Quad.fromZY(rect1, z, front, kFullUV), offsetMat);
      Rect rect2 = new Rect(rect.x + rect.w, rect.y, offset, rect.h);
      g.AddQuad(new Quad.fromZY(rect2, z, front, kFullUV), offsetMat);
    }
  }

  Rect bzy =
      new Rect(base.y + cornerOffset, level, base.h - 2 * cornerOffset, height);
  uvxy = GetWindowUV(rng, bzy.w, bzy.h);
  AddZY(bzy, uvxy, cornerOffset, false, base.x);
  AddZY(bzy, uvxy, cornerOffset, true, base.x + base.w);
}

void _AddFlatRoof(
    Shape g, Rect base, double height, double level, ColorMat topMat) {
  Quad q = new Quad.fromXZ(base, level + height, true, kFullUV);
  g.AddQuad(q, topMat);
}

// A tall box with several sections/bands
class BuildingSimpleOptions {
  ColorMat windowMat;
  ColorMat ledgeMat;
  ColorMat offsetMat;

  BuildingSimpleOptions(Math.Random rng, BuildingParameters params) {
    windowMat = params.RandomWallColorMat(rng);
    ledgeMat = params.RandomLedgeColorMat(rng);
    offsetMat = params.RandomOffsetColorMat(rng);
  }
}

void AddBuildingSimple(
    Shape g, Math.Random rng, Rect base, double h, BuildingSimpleOptions o) {
  double level = 0.0;
  // Main
  _AddWindowCylinder(g, rng, base, h, level, o.windowMat, o.offsetMat);
  level += h;
  //Ledge
  final int ledgeH = 1 + rng.nextInt(Math.min(2, h ~/ 6));
  final double offset = rng.nextInt(10) / 30;
  Rect ledge = base.Clone()..IncreaseByOffset(offset);
  _AddBox(g, ledge, ledgeH * 1.0, level, o.ledgeMat);
}

void _AddLightStrip(Shape g, Math.Random rng, Rect base, double level, double h,
    ColorMat ledgeMat, ColorMat trimLightMat) {
  double h3 = h > 1.0 ? 1.0 : 0.0;
  double h2 = 1.0;
  double h1 = h - h2 - h3;
  if (h1 > 0.0) {
    _AddBox(g, base, h1, level, ledgeMat);
  }
  _AddLightStripCylinder(g, rng, base, h2, level + h1, trimLightMat, ledgeMat);
  _AddSimpleRoof2(g, base, h2, level + h1, ledgeMat);
  if (h3 > 0.0) {
    _AddBox(g, base, h3, level + h1 + h2, ledgeMat);
  }
}

void _AddLogoStrip(Shape g, Math.Random rng, Rect base, double level, double h,
    ColorMat logoMat, ColorMat otherMat, int logoIndex) {
  Rect uvLogos = GetLogoUV(logoIndex);
  Rect fb = new Rect(base.x, level, base.w, h);
  Rect lr = new Rect(base.y, level, base.h, h);
  Quad q;
  ColorMat m;
  m = base.w >= base.h ? logoMat : otherMat;
  q = new Quad.fromXY(fb, base.y, true, uvLogos);
  g.AddQuad(q, m);
  q = new Quad.fromXY(fb, base.y + base.h, false, uvLogos);
  g.AddQuad(q, m);

  m = base.h >= base.w ? logoMat : otherMat;
  q = new Quad.fromZY(lr, base.x, false, uvLogos);
  g.AddQuad(q, m);
  q = new Quad.fromZY(lr, base.x + base.w, true, uvLogos);
  g.AddQuad(q, m);
  // roof
  g.AddQuad(new Quad.fromXZ(base, level + h, true, kFullUV), otherMat);
}

class RoofOptions {
  ColorMat ledgeMat;
  ColorMat trimOtherMat;
  ColorMat largeLightMat;
  ColorMat logoMat;
  ColorMat logoOtherMat;
  ColorMat radioTowerMat;
  ColorMat trimLightMat;
  ColorMat pulseLightMat;
  ColorMat acMat;
  bool allowLightStrip = true;
  bool allowGlobeLight = true;
  bool allowLogo = true;

  int logo_index;

  RoofOptions(
    Math.Random rng,
    BuildingParameters params,
  ) {
    ledgeMat = params.RandomLedgeColorMat(rng);
    trimLightMat = new ColorMat(params.lightTrimMat, kRGBwhite.GlColor());
    trimOtherMat = new ColorMat(params.solidMat, new RGB(8, 8, 8).GlColor());
    largeLightMat = new ColorMat(params.pointLightMat, kRGBwhite.GlColor());
    logoMat = new ColorMat(params.logoMat, kRGBwhite.GlColor());
    logoOtherMat = new ColorMat(params.solidMat, kRGBblack.GlColor());
    radioTowerMat = new ColorMat(params.radioTowerMat, kRGBwhite.GlColor());
    pulseLightMat = new ColorMat(params.flashingLightMat, kRGBwhite.GlColor());
    logo_index = params.RandomLogo(rng);
    acMat = params.RandomACColorMat(rng);
  }
}

void _AddFancyRoof(
    Shape shape, Math.Random rng, Rect area, double level, RoofOptions o) {
  int numFeatureLogo = 0;
  //int numFeatureLightStrip = 0;
  int numFeatureGlobeLight = 0;
  int numTiers = (level / 10.0).floor();
  if (numTiers > 4) numTiers = 4;
  if (numTiers > 2 && area.w * area.h <= 8 * 8) numTiers = 2;
  // the offsets will be computed out in the for loop
  Rect base = area.Clone()..IncreaseByOffset(1.0);
  for (int i = 0; i < numTiers; i++) {
    double h = Math.max(3.0 - i, 1.0);
    base.IncreaseByOffset(-1.0);
    //LogInfo("fancy roof ${ledgeBase}");
    switch (rng.nextInt(5)) {
      case 1:
        if (o.allowLightStrip && rng.nextInt(6) == 0) {
          _AddLightStrip(
              shape, rng, base, level, h, o.trimOtherMat, o.trimLightMat);
          //numFeatureLightStrip++;
        } else {
          _AddBox(shape, base, h, level, o.ledgeMat);
        }
        break;
      case 2:
        if (o.allowGlobeLight &&
            numFeatureGlobeLight == 0 &&
            rng.nextInt(5) == 0) {
          Rect b = base.Clone()..IncreaseByOffset(0.5);
          List<VM.Vector3> lamps = [
            new VM.Vector3(b.x, level + h / 2, b.y),
            new VM.Vector3(b.x, level + h / 2, b.y + b.h),
            new VM.Vector3(b.x + b.w, level + h / 2, b.y),
            new VM.Vector3(b.x + b.w, level + h / 2, b.y + b.h)
          ];
          for (VM.Vector3 pos in lamps) {
            shape.AddPoint(pos, 2000.0, o.largeLightMat);
          }
          numFeatureGlobeLight++;
        }
        _AddBox(shape, base, h, level, o.ledgeMat);
        break;
      case 3:
        if (o.allowLogo && numFeatureLogo == 0 && h == 3.0 && rng.nextInt(5) >= 2) {
          int logoIndex = o.logo_index;
          _AddLogoStrip(
              shape, rng, base, level, h, o.logoMat, o.logoOtherMat, logoIndex);
          numFeatureLogo++;
        } else {
          _AddBox(shape, base, h, level, o.ledgeMat);
        }
        break;
      default:
        _AddBox(shape, base, h, level, o.ledgeMat);
        break;
    }
    level += h;

    if (base.w <= 7 || base.h <= 7) break;
  }

  final int numAC = (level / 15.0).floor();
  for (int i = 0; i < numAC; i++) {
    _AddAC(shape, base, level, rng, o.acMat);
  }

  if (level > 50 && rng.nextInt(10) == 0) {
    _AddRadioTower(shape, rng, base, level, o.radioTowerMat, o.pulseLightMat);
  }
}

// A tall box with several sections/bands
class BuildingTowerOptions {
  ColorMat windowMat;
  ColorMat baseMat;
  ColorMat ledgeMat;
  ColorMat offsetMat;

  //
  double ledgeHeight;
  double ledgeOffset;
  double foundationHeight;
  int tierFrac;
  double cornerOffset;
  bool fancyRoof;
  int narrowingPeriod;

  // very_tall = height > 20.0;
  BuildingTowerOptions(
      Math.Random rng, BuildingParameters params, bool veryTall) {
    windowMat = params.RandomWallColorMat(rng);
    baseMat = params.RandomBaseColorMat(rng);
    ledgeMat = params.RandomLedgeColorMat(rng);
    offsetMat = params.RandomOffsetColorMat(rng);
    //
    ledgeHeight = 1.0 + (veryTall ? rng.nextInt(3) : rng.nextInt(2));
    ledgeOffset = rng.nextInt(2) / 4;
    foundationHeight = 2.0 + (veryTall ? rng.nextInt(3) : rng.nextInt(2));
    tierFrac = 2 + rng.nextInt(4);
    cornerOffset = rng.nextInt(4) != 0 ? 1.0 : 0.0;
    fancyRoof = rng.nextInt(3) == 0;
    narrowingPeriod = 1 + rng.nextInt(10);
  }
}

void AddBuildingTower(Shape g, Math.Random rng, Rect base, double height,
    BuildingTowerOptions o, RoofOptions roofOpt) {
  double level = 0.0;
  Rect tierBase = new Rect(base.x, base.y, base.w, base.h);
  Rect ledgeBase =
      new Rect.withOffset(base.x, base.y, base.w, base.h, o.ledgeOffset);
  _AddBox(g, ledgeBase, o.foundationHeight, level, o.baseMat);
  level += o.foundationHeight;

  for (int tier = 1; level < height; tier++) {
    double sectionH = height - level;
    if (sectionH > 10.0) {
      sectionH /= o.tierFrac;
      sectionH = sectionH.floor() * 1.0;
    }
    if (sectionH < 3.0) sectionH = 3.0;
    //LogInfo("Tower section ${tierBase}     ${sectionH}");
    _AddWindowCylinder(g, rng, tierBase, sectionH, level, o.windowMat,
        o.offsetMat, o.cornerOffset);
    level += sectionH;
    if (level + o.ledgeHeight > height) break; // <<<<
    //LogInfo("Tower ledge ${ledgeBase}  ${o.ledgeHeight}");
    _AddBox(g, ledgeBase, o.ledgeHeight, level, o.ledgeMat);
    level += o.ledgeHeight;
    if (tier % o.narrowingPeriod == 0) {
      if (tierBase.w > 7) {
        tierBase.x++;
        tierBase.w -= 2;
        ledgeBase.x++;
        ledgeBase.w -= 2;
      }
      if (tierBase.h > 7) {
        tierBase.y++;
        tierBase.h -= 2;
        ledgeBase.y++;
        ledgeBase.h -= 2;
      }
    }
  }

  _AddFancyRoof(g, rng, tierBase, level, roofOpt);
}

// A tall box with several sections/bands
class BuildingBlockyOptions {
  ColorMat windowMat;
  ColorMat offsetMat;
  ColorMat baseMat;
  double baseHeight;

  // very_tall = height > 20.0;
  BuildingBlockyOptions(Math.Random rng, BuildingParameters params) {
    windowMat = params.RandomWallColorMat(rng);
    baseMat = params.RandomBaseColorMat(rng);
    baseHeight = kBaseHeight * 1.0;
    offsetMat = params.RandomOffsetColorMat(rng);
  }
}

void AddBuildingBlocky(Shape g, Math.Random rng, Rect base, double totalHeight,
    BuildingBlockyOptions o, RoofOptions roofOpt) {
  int max_left = 1;
  int max_right = 1;
  int max_front = 1;
  int max_back = 1;
  int tier = 0;
  int h = totalHeight.floor();
  int w = base.w.floor();
  int d = base.h.floor();
  int max_tiers = _NumTiers(h);
  Set<int> priorLefts = new Set<int>();
  Set<int> priorRights = new Set<int>();
  Set<int> priorFronts = new Set<int>();
  Set<int> priorBacks = new Set<int>();

  // tallest first
  while (tier < max_tiers && h >= kMinTierHeight) {
    int left = 1 + rng.nextInt(w ~/ 2);
    int right = 1 + rng.nextInt(w ~/ 2);
    int front = 1 + rng.nextInt(d ~/ 2);
    int back = 1 + rng.nextInt(d ~/ 2);

    // ensure termination
    h--;
    // avoid hiding a box
    if (left <= max_left &&
        right <= max_right &&
        front <= max_front &&
        back <= max_back) {
      continue;
    }
    // avoid z-fighting
    if (priorLefts.contains(left) ||
        priorRights.contains(right) ||
        priorFronts.contains(front) ||
        priorBacks.contains(back)) {
      continue;
    }
    priorLefts.add(left);
    priorRights.add(right);
    priorFronts.add(front);
    priorBacks.add(back);

    max_left = Math.max(left, max_left);
    max_right = Math.max(right, max_right);
    max_front = Math.max(front, max_front);
    max_back = Math.max(back, max_back);

    Rect r = new Rect(
        base.x + base.w / 2.0 - left,
        base.y + base.h / 2.0 - back,
        (left + right) * 1.0,
        (front + back) * 1.0);
    if (tier == 0) {
      _AddFancyRoof(g, rng, r, h + o.baseHeight, roofOpt);
    }

    _AddWindowCylinder(
        g, rng, r, h * 1.0, o.baseHeight, o.windowMat, o.offsetMat);
    _AddFlatRoof(g, r, h * 1.0, o.baseHeight, roofOpt.ledgeMat);
    h -= 1 + rng.nextInt(kMinTierHeight);
    tier++;
  }
  _AddBox(g, base, kBaseHeight * 1.0, 0.0, o.baseMat);
}

void AddOneBuilding(Shape shape, Math.Random rng, BuildingParameters params,
    RoofOptions roofOpt, Building b, VM.Vector3 theColor, bool nightMode) {
  switch (b.kind) {
    case kTileBuildingTower:
      var opt = new BuildingTowerOptions(rng, params, b.height > 40.0);
      if (!nightMode) {
        roofOpt.logoOtherMat.color = theColor;
        roofOpt.logoMat.color = theColor;
      }
      AddBuildingTower(shape, rng, b.base, b.height, opt, roofOpt);
      break;
    case kTileBuildingBlocky:
      var opt = new BuildingBlockyOptions(rng, params);
      if (!nightMode) {
        roofOpt.logoOtherMat.color = theColor;
        roofOpt.logoMat.color = theColor;
      }
      AddBuildingBlocky(shape, rng, b.base, b.height, opt, roofOpt);
      break;
    case kTileBuildingModern:
      var opt = new BuildingModernOptions(rng, params, b.height > 48.0);
      if (!nightMode) {
        opt.trimIndex = -1;
      }
      AddBuildingModern(shape, rng, b.base, b.height, opt);
      break;
    case kTileBuildingSimple:
      var opt = new BuildingSimpleOptions(rng, params);
      AddBuildingSimple(shape, rng, b.base, b.height, opt);
      break;
    default:
      LogError("BAD ${b.kind}");
      assert(false);
  }
}
