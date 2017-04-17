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
This file contains code to generate textures for facades.
We avoid using Canvas as much as possible so that this code
could be used outside of the browser
*/

library facade;

import 'dart:html' as HTML;
import 'dart:math' as Math;
import 'dart:typed_data';

import 'rgb.dart';
import 'config.dart';

import 'geometry.dart';
import 'logging.dart' as log;

RGB MakeWindowColor(Math.Random rng, bool lit) {
  RGB rgb;
  if (lit) {
    rgb = new RGB.fromGray(128);
    RGB colNoise = new RGB.fromRandom(rng);
    colNoise.scale(0.15);
    rgb.add(colNoise);
    RGB grayNoise = new RGB.fromRandomGray(rng);
    grayNoise.scale(0.25);
    rgb.add(grayNoise);
  } else {
    rgb = new RGB.fromRandomGray(rng);
    rgb.scale(0.2);
  }

  return rgb;
}

class Area {
  int x;
  int y;
  int w;
  int h;

  Area(this.x, this.y, this.w, this.h);

  void Shrink(int offset) {
    x += offset;
    y += offset;
    w -= 2 * offset;
    h -= 2 * offset;
  }
}

// Performance sensitive (at startup)
void _AddStripNoisePattern(Math.Random rng, Uint8ClampedList data, int width,
    int colorAverage, Area a, bool lit) {
  if (a.w < 4 || a.h < 4) return;
  final int w = kStdCanvasDim ~/ kWindowsHorizontal;
  int height = rng.nextInt(a.h * 3 ~/ 4);

  for (int x = 0; x < a.w; x++) {
    if (rng.nextInt(w ~/ 3) == 0) {
      height = rng.nextInt(a.h * 3 ~/ 4);
    }

    double alphaBot = 0.5; // * rng.nextDouble();
    double alphaTop = 0.25 + 0.25 * rng.nextDouble();
    for (int y = 0; y < height; y++) {
      final double alpha = alphaBot + (alphaTop - alphaBot * y / height);
      final int i = 4 * ((a.y + a.h - y - 1) * width + a.x + x);
      data[i + 0] = (data[i + 0] * (1.0 - alpha)).floor();
      data[i + 1] = (data[i + 1] * (1.0 - alpha)).floor();
      data[i + 2] = (data[i + 2] * (1.0 - alpha)).floor();
    }
  }
}

void _SolidRectangle(
    Uint8ClampedList data, int width, int x, int y, int w, int h, RGB color) {
  if (h == 0 || w == 0) return;
  final int r = color.r;
  final int g = color.g;
  final int b = color.b;
  for (int yy = y; yy < y + h; yy++) {
    for (int xx = x; xx < x + w; xx++) {
      final int i = 4 * (yy * width + xx);
      data[i + 0] = r;
      data[i + 1] = g;
      data[i + 2] = b;
    }
  }
}

void _FillCanvas(HTML.CanvasElement canvas, RGB color) {
  canvas.context2D
    ..fillStyle = color.ToString()
    ..fillRect(0, 0, canvas.width, canvas.height);
}

typedef void DrawWindowFunction(Math.Random rng, Uint8ClampedList data,
    int width, RGB color, Area a, bool isLit);

void DrawFacadeWindowMiniGap(Math.Random rng, Uint8ClampedList data, int width,
    RGB color, Area a, bool isLit) {
  a.Shrink(1);
  _SolidRectangle(data, width, a.x, a.y, a.w, a.h, color);

  _AddStripNoisePattern(rng, data, width, color.average(), a, isLit);
}

void DrawFacadeWindowLongSleek(Math.Random rng, Uint8ClampedList data, int width,
    RGB color, Area a, bool isLit) {
  int d = a.w ~/ 3;
  a.x += d;
  a.w -= d + d;
  a.y += 1;
  a.h -= 2;
  _SolidRectangle(data, width, a.x, a.y, a.w, a.h, color);
  _AddStripNoisePattern(rng, data, width, color.average(), a, isLit);
}

void DrawFacadeWindowSideBySide(Math.Random rng, Uint8ClampedList data, int width,
    RGB color, Area a, bool isLit) {
  int d = a.w ~/ 3;
  int w2 = a.w ~/ 2 - 2;
  int x1 = a.x + 1;
  int x2 = a.x + 1 + a.w ~/ 2;
  a.h -= d + 1;
  a.y += 1;
  _SolidRectangle(data, width, x1, a.y, w2, a.h, color);
  _SolidRectangle(data, width, x2, a.y, w2, a.h, color);
  _AddStripNoisePattern(rng, data, width, color.average(), a, isLit);
}

void DrawFacadeWindowBlinds(Math.Random rng, Uint8ClampedList data, int width,
    RGB color, Area a, bool isLit) {
  a.Shrink(1);
  _SolidRectangle(data, width, a.x, a.y, a.w, a.h, color);
  _AddStripNoisePattern(rng, data, width, color.average(), a, isLit);
  //blind
  color.scale(0.3);
  a.h = rng.nextInt(a.h);
  _SolidRectangle(data, width, a.x, a.y, a.w, a.h, color);
}

void DrawFacadeWindowVerticalStripes(Math.Random rng, Uint8ClampedList data, int width,
    RGB color, Area a, bool isLit) {
  int d = a.w ~/ 3;
  int wLine = a.w ~/ 8;
  int x1 = a.x + d - wLine ~/ 2;
  int x2 = a.x + a.w - d - wLine ~/ 2;
  a.Shrink(1);
  _SolidRectangle(data, width, a.x, a.y, a.w, a.h, color);
  _AddStripNoisePattern(rng, data, width, color.average(), a, isLit);
  color.scale(0.7);
  _SolidRectangle(data, width, x1, a.y, wLine, a.h, color);
  color.scale(0.3 / 0.7);
  _SolidRectangle(data, width, x2, a.y, wLine, a.h, color);
}

void DrawFacadeWindowNotFloorToCeiling(Math.Random rng, Uint8ClampedList data, int width,
    RGB color, Area a, bool isLit) {
  a.x += 1;
  a.w -= 2;
  a.y += 1;
  a.h = a.h - a.h ~/ 3 - 1;
  _SolidRectangle(data, width, a.x, a.y, a.w, a.h, color);
  _AddStripNoisePattern(rng, data, width, color.average(), a, isLit);
}

void DrawFacadeWindowFourPane(Math.Random rng, Uint8ClampedList data, int width,
    RGB color, Area a, bool isLit) {
  a.Shrink(1);
  int wm = a.w ~/ 8;
  int hm = a.w ~/ 8;
  int xm = a.x + a.w ~/ 2 - wm ~/ 2;
  int ym = a.y + a.h ~/ 2 - hm ~/ 2;
  _SolidRectangle(data, width, a.x, a.y, a.w, a.h, color);
  _AddStripNoisePattern(rng, data, width, color.average(), a, isLit);
  // cross bar - original had 0.2
  color.scale(0.3);
  _SolidRectangle(data, width, xm, a.y, wm, a.h, color);
  _SolidRectangle(data, width, a.x, ym, a.w, hm, color);
}

void DrawFacadeWindowNarrowNotFloorToCeiling(Math.Random rng, Uint8ClampedList data, int width,
    RGB color, Area a, bool isLit) {
  a.x += a.w ~/ 2 - a.w ~/ 4;
  a.w ~/= 4;
  a.y += 1;
  a.h -= a.h ~/ 3 + 1;
  _SolidRectangle(data, width, a.x, a.y, a.w, a.h, color);
  _AddStripNoisePattern(rng, data, width, color.average(), a, isLit);
}

void DrawFacadeWindowCenteredNarrow(Math.Random rng, Uint8ClampedList data, int width,
    RGB color, Area a, bool isLit) {
  a.x += 1;
  a.w -= 2;
  a.y += a.h ~/ 3;
  a.h -= 2 * a.h ~/ 3;
  _SolidRectangle(data, width, a.x, a.y, a.w, a.h, color);
  _AddStripNoisePattern(rng, data, width, color.average(), a, isLit);
}

final List<DrawWindowFunction> kFacadeDrawerNight = [
  DrawFacadeWindowMiniGap,
  DrawFacadeWindowLongSleek,
  DrawFacadeWindowSideBySide,
  DrawFacadeWindowBlinds,
  DrawFacadeWindowVerticalStripes,
  DrawFacadeWindowNotFloorToCeiling,
  DrawFacadeWindowFourPane,
  DrawFacadeWindowNarrowNotFloorToCeiling,
  DrawFacadeWindowCenteredNarrow,
];

final List<DrawWindowFunction> kFacadeDrawerDay = [
  DrawFacadeWindowMiniGap,
  DrawFacadeWindowLongSleek,
  DrawFacadeWindowSideBySide,
  DrawFacadeWindowVerticalStripes,
  DrawFacadeWindowNotFloorToCeiling,
  DrawFacadeWindowFourPane,
];

HTML.CanvasElement MakeCanvasFacade(
    Math.Random rng, RGB wallColor, DrawWindowFunction drawFun, bool day) {
  final int w = kStdCanvasDim ~/ kWindowsHorizontal;
  final int h = kStdCanvasDim ~/ kWindowsVertical;

  HTML.CanvasElement canvas = new HTML.CanvasElement();
  canvas
    ..width = kStdCanvasDim
    ..height = kStdCanvasDim;
  _FillCanvas(canvas, wallColor);
  HTML.ImageData id =
      canvas.context2D.getImageData(0, 0, canvas.width, canvas.height);
  final Uint8ClampedList data = id.data;
  final int width = id.width;
  //SolidRectangle(id, 0, 0, id.width, id.height, wallColor);
  int run = 0;
  int run_len = 0;
  bool lit = false;
  int lit_density = 0;

  Area area = new Area(0, 0, 0, 0);
  for (int y = 0; y < kWindowsVertical; y++) {
    if (y % 8 == 0) {
      run_len = 2 + rng.nextInt(9);
      run = 0;
      lit_density = 2 + rng.nextInt(2) + rng.nextInt(3);
    }
    for (int x = 0; x < kWindowsHorizontal; x++) {
      if (run < 1) {
        run = rng.nextInt(run_len);
        lit = rng.nextInt(lit_density) == 0;
      }
      if (day) lit = true;

      run--;
      // The callee is allowed to change these value
      area.x = x * w;
      area.y = y * h;
      area.w = w;
      area.h = h;
      drawFun(rng, data, width, MakeWindowColor(rng, lit), area, lit);
    }
  }
  canvas.context2D.putImageData(id, 0, 0);
  return canvas;
}

HTML.CanvasElement MakeCanvasText(int w, int h, String fontProps,
    String fontName, List<String> lines, RGB colorText, RGB colorBG) {
  int lineH = h ~/ lines.length;
  int fontSize = (lineH * 0.85).floor();
  HTML.CanvasElement canvas = new HTML.CanvasElement();
  canvas
    ..width = w
    ..height = h;
  HTML.CanvasRenderingContext2D c = canvas.context2D;
  c
    ..fillStyle = colorBG.ToString()
    ..fillRect(0, 0, w, h)
    ..strokeStyle = colorText.ToString()
    ..fillStyle = colorText.ToString()
    ..textBaseline = "middle"
    ..font = '${fontProps} ${fontSize}px ${fontName}';

  //LogInfo("base ${c.textBaseline}");
  //LogInfo("asc ${c.measureText("qgMT").fontBoundingBoxAscent}");
  //LogInfo("des ${c.measureText("qgMT").fontBoundingBoxDescent}");
  int offset = lineH ~/ 2;
  for (String s in lines) {
    c..fillText(s, w / 16, offset);
    offset += lineH;
  }
  return canvas;
}

List<String> GetBuildingLogos(Math.Random rng) {
  List<String> lines = [];
  int rovingPrefix = rng.nextInt(kCompanyPrefix.length);
  int rovingMain = rng.nextInt(kCompanyMain.length);
  int rovingSuffix = rng.nextInt(kCompanySuffix.length);
  for (int i = 0; i < kNumBuildingLogos; i++) {
    if (rng.nextBool()) {
      lines.add(kCompanyPrefix[rovingPrefix] + kCompanyMain[rovingMain]);
    } else {
      lines.add(kCompanyMain[rovingMain] + kCompanySuffix[rovingSuffix]);
    }
    rovingPrefix = (rovingPrefix + 1) % kCompanyPrefix.length;
    rovingMain = (rovingMain + 1) % kCompanyMain.length;
    rovingSuffix = (rovingSuffix + 1) % kCompanySuffix.length;
  }
  return lines;
}

HTML.CanvasElement MakeCanvasBuildingLogos(
    List<String> lines, RGB colorText, RGB colorBG) {
  return MakeCanvasText(kStdCanvasDim, kStdCanvasDim * 2, "bold", "Arial",
      lines, colorText, colorBG);
}

// For reference how to write pixels directly
HTML.CanvasElement generateTexture() {
  HTML.CanvasElement canvas = new HTML.CanvasElement();
  canvas.width = 256;
  canvas.height = 256;

  var context = canvas.context2D;
  var image = context.getImageData(0, 0, 256, 256);

  var x = 0, y = 0;

  for (var i = 0, j = 0, l = image.data.length; i < l; i += 4, j++) {
    x = j % 256;
    y = x == 0 ? y + 1 : y;

    image.data[i] = 255;
    image.data[i + 1] = 255;
    image.data[i + 2] = 255;
    image.data[i + 3] = (x ^ y).floor();
  }
  context.putImageData(image, 0, 0);
  return canvas;
}

HTML.CanvasElement MakeCanvasLightTrimTexture() {
  assert(kLightTrimContinousRows == 8); // must be power of 2
  final int cellDim = kLightTrimCellDim;
  HTML.CanvasElement canvas = new HTML.CanvasElement()
    ..width = cellDim * kLightTrimGranularity
    ..height = cellDim * kLightTrimContinousRows;
  _FillCanvas(canvas, kRGBblack);
  HTML.CanvasRenderingContext2D c = canvas.context2D;

  for (int y = 0; y < kLightTrimPatterns.length; y++) {
    List<int> pattern = kLightTrimPatterns[y];
    int patWidth = LightTrimPatternLength(y) * cellDim;

    double cy = y * cellDim * 1.0;
    for (int x = 0; x < kLightTrimGranularity * cellDim; x += patWidth) {
      double cx = x * 1.0;
      for (int i = 0; i < pattern.length; i++) {
        double cw = pattern[i] * cellDim / 2.0;
        double ch = cellDim * 1.0;
        // only draw the full ones
        if (i % 2 == 1) {
          HTML.CanvasGradient g = c.createRadialGradient(cx + cw / 2,
              cy + ch / 2, 0.0, cx + cw / 2, cy + ch / 2, cw / 1.5);
          g..addColorStop(0.0, "#ffffff")..addColorStop(1.0, "#808080");
          c
            ..fillStyle = g
            ..fillRect(cx, cy, cw, ch);
        }
        cx += cw;
      }
    }
  }
  return canvas;
}

HTML.CanvasElement MakeOrientationTestPattern() {
  List<String> lines = [
    "9999999999",
    "8888888889",
    "7777777789",
    "6666666789",
    "5555556789",
    "4444456789",
    "3333456789",
    "2223456789",
    "1123456789",
    "0123456789",
  ];
  return MakeCanvasText(kStdCanvasDim ~/ 4, kStdCanvasDim ~/ 2, "bold", "Arial",
      lines, kRGBwhite, kRGBblack);
}

// For inspecting the light colors
HTML.CanvasElement MakeLightColorPattern() {
  int w = kStdCanvasDim ~/ 2;
  int h = kBuildingColors.length * 64;
  var canvas = new HTML.CanvasElement()
    ..width = w
    ..height = h;
  _FillCanvas(canvas, kRGBblack);
  HTML.CanvasRenderingContext2D c = canvas.context2D;
  for (int i = 0; i < kBuildingColors.length; i++) {
    final RGB color = kBuildingColorsRGB[i];
    c
      ..fillStyle = color.ToString()
      ..fillRect(0, i * 64, w, 64);
  }
  return canvas;
}

void _DrawOvalGradient(HTML.CanvasRenderingContext2D c, int cx, int cy, int rw,
    int rh, RGB color, RGB black) {
  HTML.CanvasGradient g =
      c.createRadialGradient(cx / rw, cy / rh, 0.0, cx / rw, cy / rh, 1.0);
  g..addColorStop(0.0, color.ToString())..addColorStop(1.0, black.ToString());
  c
    ..fillStyle = g
    ..setTransform(rw, 0, 0, rh, 0, 0)
    ..fillRect(cx / rw - 1.0, cy / rh - 1.0, 2, 2)
    ..setTransform(1.0, 0, 0, 1.0, 0, 0);
}

const int kStreetlightStretch = 4;
// A single street light in the middle of a rectangle
HTML.CanvasElement _MakeCommonLight(int r, RGB color, RGB bg, int stretch) {
  HTML.CanvasElement canvas = new HTML.CanvasElement();
  canvas
    ..width = stretch * 2 * r
    ..height = 2 * r;
  HTML.CanvasRenderingContext2D c = canvas.context2D;
  c
    ..fillStyle = bg.ToString()
    ..fillRect(0, 0, stretch * 2 * r, 2 * r);
  _DrawOvalGradient(c, stretch * r, r, r, r, color, bg);
  return canvas;
}

HTML.CanvasElement MakeCanvasStreetLight(int r, RGB color, RGB bg) {
  return _MakeCommonLight(r, color, bg, kStreetlightStretch);
}

HTML.CanvasElement MakeCanvasPointLight(int r, RGB color, RGB bg) {
  return _MakeCommonLight(r, color, bg, 1);
}

HTML.CanvasElement MakeCanvasHeadLights() {
  // TODO: this should kRGBtransparent;
  final int w = kStdCanvasDim ~/ 4;
  final int h = kStdCanvasDim ~/ 4;
  final double ratio = w / kCarSpriteSizeW;
  final double carFront = ratio * (kCarSpriteSizeW - kCarLength) / 2;
  final double carBack = ratio * (kCarSpriteSizeW + kCarLength) / 2;
  final double carLeft = ratio * (kCarSpriteSizeW - kCarWidth) / 2;
  final double carRight = ratio * (kCarSpriteSizeW + kCarWidth) / 2;
  final double radHead = ratio * kCarWidth / 6;
  final double radTail = ratio * kCarWidth / 8;

  final RGB bg = new RGB.fromGray(0)..a = 0.0;
  final RGB fg = new RGB.fromGray(255)..a = 1.0;
  HTML.CanvasElement canvas = new HTML.CanvasElement();
  canvas
    ..width = w
    ..height = h;
  _FillCanvas(canvas, bg);
  HTML.CanvasRenderingContext2D c = canvas.context2D;

  final double r1 = 0.0;
  final double r2 = ratio * kCarSpriteSizeW / 4.0;
  final double d = radHead;
  HTML.CanvasGradient gr = c.createRadialGradient(
      carLeft + d, carFront, r1, carLeft + d, carFront / 2, r2);
  gr..addColorStop(0.0, fg.ToString())..addColorStop(1.0, bg.ToString());
  HTML.CanvasGradient gl = c.createRadialGradient(
      carRight - d, carFront, r1, carRight - d, carFront / 2, r2);
  gl..addColorStop(0.0, fg.ToString())..addColorStop(1.0, bg.ToString());

  // head light spots
  c
    ..fillStyle = "white"
    ..fillRect(carLeft + radHead * 0.5, carFront - radHead, radHead, radHead)
    ..fillRect(carRight - radHead * 1.5, carFront - radHead, radHead, radHead);

  // tail light spots
  c
    ..fillStyle = "red"
    ..fillRect(carLeft + radTail, carBack, radTail, radTail)
    ..fillRect(carRight - 2 * radTail, carBack, radTail, radTail);

  // light cloud
  c
    ..fillStyle = gr
    ..fillRect(0, 0, w, h / 2)
    ..fillStyle = gl
    ..fillRect(0, 0, w, h / 2);

  // draw car shape
  c
    ..fillStyle = "black"
    ..fillRect(carLeft, carFront, ratio * kCarWidth, ratio * kCarLength);
  return canvas;
}

HTML.CanvasElement MakeRadioTowerTexture() {
  int dim = kStdCanvasDim ~/ 4;
  double lineW = dim / 16;
  HTML.CanvasElement canvas = new HTML.CanvasElement();
  canvas
    ..width = dim
    ..height = dim;
  RGB fg = new RGB.fromGray(32);
  RGB bg = new RGB.fromGray(8);
  bg = kRGBtransparent;
  _FillCanvas(canvas, bg);
  HTML.CanvasRenderingContext2D c = canvas.context2D;
  c
    ..fillStyle = fg.ToString()
    ..strokeStyle = fg.ToString()
    ..lineWidth = lineW;

  void drawline(x1, y1, x2, y2) {
    c
      ..moveTo(x1, y1)
      ..lineTo(x2, y2);
  }

  drawline(dim / 2, 0, dim / 2, dim);
  drawline(0, dim / 2, dim, dim / 2);
  c..stroke();
  return canvas;
}

List<FaceMat> MakeWallsNight(Math.Random rng, RGB wallColor) {
  List<FaceMat> m = [];

  for (DrawWindowFunction d in kFacadeDrawerNight) {
    int n = 1 + m.length;
    log.LogInfo("Create Windows $n");
    m.add(new FaceMat("facade $n")
      ..canvas = MakeCanvasFacade(rng, wallColor, d, false));
  }
  return m;
}

List<FaceMat> MakeWallsDay(Math.Random rng, RGB wallColor) {
  List<FaceMat> m = [];

  for (DrawWindowFunction d in kFacadeDrawerDay) {
    int n = 1 + m.length;
    log.LogInfo("Create Windows $n");
    m.add(new FaceMat("facade $n")
      ..canvas = MakeCanvasFacade(rng, wallColor, d, true));
  }
  return m;
}

FaceMat MakeSolid() {
  return new FaceMat("Solid");
}

FaceMat MakeLogo(List<String> logo, RGB textColor, RGB wallColor) {
  return new FaceMat("logos")
    ..canvas = MakeCanvasBuildingLogos(logo, textColor, wallColor);
}

FaceMat MakeLightTrims() {
  return new FaceMat("trimlight")..canvas = MakeCanvasLightTrimTexture();
}

FaceMat MakePointLight() {
  RGB white = new RGB.fromGray(255)..a = 0.99;
  return new FaceMat("pointlight")
    ..is_points = true
    ..canvas = MakeCanvasPointLight(64, white, kRGBtransparent)
    ..depthWrite = false
    ..transparent = true;
}

FaceMat MakeFlashingLight() {
  RGB white = new RGB.fromGray(255)..a = 0.99;
  return new FaceMat("pointlightFlash")
    ..is_points = true
    ..canvas = MakeCanvasPointLight(64, white, kRGBtransparent)
    ..flashing = true
    ..transparent = true;
}

FaceMat MakeRadioTower() {
  return new FaceMat("radiotower")
    ..canvas = MakeRadioTowerTexture()
    ..depthWrite = false
    ..transparent = true;
}
