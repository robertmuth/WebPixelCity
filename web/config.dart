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
This file contains global constants and simple helpers using them
*/

library config;

import 'dart:math' as Math;
import 'package:vector_math/vector_math.dart' as VM;

import 'rgb.dart';
import 'geometry.dart';


const double kCarSpriteSizeW = 3.0;
const double kCarWidth = 0.4;
const double kCarLength = 1.0;
const double kCarHeight = 0.2;
const double kCarLevel = 0.1;

final List<List<int>> kLightTrimPatterns = [
  // blank, full alternating - multiplied by 2
  [1, 2, 1], // 4
  [2, 4, 2], // 8
  [4, 8, 4], // 16
  [1, 6, 1], // 8
  [2, 12, 2], // 16
  [3, 2, 3], // 8
  [6, 4, 6], // 16
  //[1, 4, 2, 2, 2, 4, 1], // 16
  //[4, 2, 4, 2, 4], // 16
  [0, 2], // solid strip of individual lights
];

final int kLightTrimContinousRows = kLightTrimPatterns.length;
const int kLightTrimGranularity = 16;
const int kLightTrimCellDim = kStdCanvasDim ~/ 2 ~/ kLightTrimGranularity;

/*
const int kStdCanvasDim = 1024;
const int kWindowsHorizontal = 64;
const int kWindowsVertical = 64;
*/

const int kStdCanvasDim = 512;
const int kWindowsHorizontal = 32;
const int kWindowsVertical = 32;

const int _kRowsFacade = kWindowsVertical;
const int _kColsFacade = kWindowsHorizontal;
const int _kCanonicalWindowPixelWidth = kStdCanvasDim ~/ kWindowsHorizontal;

const int kNumBuildingLogos = 32;

Rect GetWindowUVContinous(double offset, double w, double h) {
  return new Rect(
      offset / _kColsFacade, 0.0, w / _kColsFacade, h / _kRowsFacade);
}

Rect GetWindowUV(Math.Random rng, double w, double h) {
  double x = rng.nextInt(kWindowsHorizontal) / _kColsFacade;
  double y = rng.nextInt(kWindowsVertical) / _kRowsFacade;
  return new Rect(x, y, w / _kColsFacade, h / _kRowsFacade);
}

int CommonTail(int w, int h) {
  int out = 1;
  while (w != 0 && h != 0 && (w & 1) == (h & 1)) {
    out = out << 1;
    w = w >> 1;
    h = h >> 1;
  }
  return out;
}

int LightTrimPatternLength(int pattern) {
  int n = 0;
  for (int p in kLightTrimPatterns[pattern]) {
    n += p;
  }
  return n ~/ 2;
}

int GetLightTrimPatternForCentered(Math.Random rng, double w, double h) {
  // Largest power of two divining both base.w and base.h
  final int repeat = CommonTail(w.floor() & ~1, h.floor() & ~1);
  //LogInfo("GetLightTrimPatternForRepeat $repeat");
  List<int> suitable = [];
  for (int i = 0; i < kLightTrimPatterns.length; i++) {
    int patLen = LightTrimPatternLength(i);
    if (patLen <= repeat && w >= 2 * patLen && h >= 2 * patLen) {
      suitable.add(i);
    }
  }
  if (suitable.length == 0) return -1;
  return suitable[rng.nextInt(suitable.length)];
}

int GetLightTrimPatternForContinous(Math.Random rng) {
  return rng.nextInt(3);
}

double GetLightTrimCenteredOffset(int pat, double w) {
  int patWidth = LightTrimPatternLength(pat);
  double covered = (w / patWidth).floor() * patWidth * 1.0;
  return (w - covered) / 2.0;
}

Rect GetLightTrimCenteredUV(int pat, Rect r) {
  //LogInfo("light strip pattern is ${r.w}x${r.h} ${pat}");
  double w = r.w / kLightTrimGranularity;
  double h = 0.96 / kLightTrimContinousRows;
  double x = 0.0;
  double y =
      (kLightTrimContinousRows - pat - 1 + 0.02) / kLightTrimContinousRows;
  return new Rect(x, y, w, h);
}

Rect GetLightTrimUVContinous(int pat, double offset, double w) {
  //LogInfo("light strip pattern continous is ${offset} ${w}x ${pat}");
  w = w / kLightTrimGranularity;
  double h = 1.0 / kLightTrimContinousRows;
  double x = offset / kLightTrimGranularity;
  double y = (kLightTrimContinousRows - pat - 1) / kLightTrimContinousRows;
  return new Rect(x, y, w, h);
}

Rect GetLogoUV(int n) {
  double logoH = 1 / kNumBuildingLogos;
  return new Rect(0.0, n * logoH, 1.0, logoH);
}

double LogoAspectRatio() {
  return kStdCanvasDim / (kStdCanvasDim * 2 / kNumBuildingLogos);
}

const double kNonSaturated = 0.93;
const double kMildSaturated = 0.90;

final List<RGB> kBuildingColorsRGB = [
  new RGB.fromHSL(0.04, 0.9, kNonSaturated), //Amber / pink
  new RGB.fromHSL(0.055, 0.95, kNonSaturated), //Slightly brighter amber
  new RGB.fromHSL(0.08, 0.7, kNonSaturated), //Very pale amber
  new RGB.fromHSL(0.07, 0.9, kNonSaturated), //Very pale orange
  new RGB.fromHSL(0.1, 0.9, kMildSaturated), //Peach
  new RGB.fromHSL(0.13, 0.9, kNonSaturated), //Pale Yellow

  new RGB.fromHSL(0.15, 0.9, kNonSaturated), //Yellow

  //new RGB.fromHSL(0.17, 1.0, kMildSaturated), //Saturated Yellow

  new RGB.fromHSL(0.55, 0.9, kNonSaturated), //Cyan

  new RGB.fromHSL(0.55, 0.9, kMildSaturated), //Cyan - pale, almost white

  new RGB.fromHSL(0.6, 0.9, kNonSaturated), //Pale blue
  new RGB.fromHSL(0.65, 0.9, kNonSaturated), //Pale Blue II, The Palening
  new RGB.fromHSL(0.65, 0.4, 0.99), //Pure white. Bo-ring.
  new RGB.fromHSL(0.65, 0.0, 0.8), //Dimmer white.
  new RGB.fromHSL(0.65, 0.0, 0.6) //Dimmest white
  //
  // Ledge Colors
];

List<VM.Vector3> _MakeBuildingColors(List<RGB> rgbs) {
  List<VM.Vector3> out = [];
  for (RGB c in rgbs) {
    out.add(c.GlColor());
  }
  return out;
}

final List<VM.Vector3> kBuildingColors =
    _MakeBuildingColors(kBuildingColorsRGB);

final List<VM.Vector3> kLedgeColors = [
  new RGB(8, 8, 8).GlColor(),
  new RGB(12, 12, 12).GlColor(),
  new RGB(16, 16, 16).GlColor(),
];

final List<VM.Vector3> kOffsetColors = [
  new RGB(4, 4, 4).GlColor(),
];

final List<VM.Vector3> kBaseColors = [
  new RGB(2, 2, 2).GlColor(),
  new RGB(4, 4, 4).GlColor(),
  new RGB(6, 6, 6).GlColor(),
  new RGB(8, 8, 8).GlColor(),
];

final List<VM.Vector3> kAcColors = [
  new RGB(16, 16, 16).GlColor(),
];

final List<RGB> kDaylightBuildingColors = [
  // Lime
  new RGB(0xdf, 0xd9, 0xbb),
  new RGB(0xdf, 0xd9, 0xbb),
  // light blue
  new RGB(0x7a, 0xce, 0xe8),
  new RGB(0x7a, 0xce, 0xe8),
  // blue turquise
  new RGB(0x12, 0x74, 0xdf),
  new RGB(0x15, 0x94, 0xf7),
  // brown
  new RGB(0xfc, 0xa6, 0x76),
  new RGB(0xe3, 0x82, 0x3c),
  // red
  new RGB(0xfb, 0x2d, 0x20),
  new RGB(0x9e, 0x26, 0x14),
  // white
  new RGB(0xdd, 0xde, 0xe3),
  new RGB(0xf9, 0xfc, 0xfb),
  new RGB(0xdd, 0xde, 0xe3),
  new RGB(0xf9, 0xfc, 0xfb),
  new RGB(0xdd, 0xde, 0xe3),
  new RGB(0xf9, 0xfc, 0xfb),
  new RGB(0xdd, 0xde, 0xe3),
  new RGB(0xf9, 0xfc, 0xfb),
  new RGB(0xdd, 0xde, 0xe3),
  new RGB(0xf9, 0xfc, 0xfb),

  // yellow
  //new RGB(0xfe,0xd8,0x5d),
  //new RGB(0xfd,0xbf,0x39),
];

final List<String> kFonts = [
  "Courier New",
  "Arial",
  "Times New Roman",
  "Arial Black",
  "Impact",
  "Agency FB",
  "Book Antiqua",
];

final List<String> kCompanySuffix = [
  " Corp",
  " Inc.",
  "Co",
  "World",
  ".Com",
  //" USA",
  " Ltd.",
  "Net",
  " Tech",
  " Labs",
  " Mfg.",
  //" UK",
  " Unlimited",
  " One",
  " LLC",
];

final List<String> kCompanyPrefix = [
  "i",
  "Acme ",
  //"Green ",
  "Mega",
  //"Super ",
  "Pan ",
  "Omni",
  "e",
  "Cyber",
  "Global ",
  "Quantum ",
  "Next ",
  "Metro",
  "Unity ",
  "Star ",
  "Q-",
  "Trans",
  //"Infinity ",
  //"Monolith ",
  "First ",
  "Union ",
  "Cosmos ",
  //"Galactic ",
  //"National ",
];

final List<String> kCompanyMain = [
  "Alpha",
  "Bionic",
  "Info",
  "Data",
  "Solar",
  "Aerospace",
  "Motors",
  "Nano",
  "Gadgets"
      "Online",
  "Circuits",
  "Dynamics",
  "Energy",
  "Med",
  "Bergmann",
  "Robotic",
  "Rockets",
  "Exports",
  "Security",
  "Systems",
  "Financial",
  "Machines",
  //"Industrial",
  "Media",
  "Materials",
  "Muth",
  "Foods",
  "Networks",
  "Shipping",
  "Tools",
  "Medical",
  "Young",
  //"Publishing",

  // "Enterprises",
  //"Audio",
  "Sound",
  "Health",
  "Bank",
  "Imports",
  "Apparel",
  "Hulha",
  // "Petroleum",
  "Studios",
  "Galaxy ",
  //"Industries",
];
