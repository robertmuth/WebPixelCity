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

library rgb;

import 'dart:core';
import 'dart:math' as Math;
import 'package:vector_math/vector_math.dart' as VM;

final Map<String, String> _HtmlColors = {
  "aliceblue": "f0f8ff",
  "antiquewhite": "faebd7",
  "aqua": "00ffff",
  "aquamarine": "7fffd4",
  "azure": "f0ffff",
  "beige": "f5f5dc",
  "bisque": "ffe4c4",
  "black": "000000",
  "blanchedalmond": "ffebcd",
  "blue": "0000ff",
  "blueviolet": "8a2be2",
  "brown": "a52a2a",
  "burlywood": "deb887",
  "cadetblue": "5f9ea0",
  "chartreuse": "7fff00",
  "chocolate": "d2691e",
  "coral": "ff7f50",
  "cornflowerblue": "6495ed",
  "cornsilk": "fff8dc",
  "crimson": "dc143c",
  "cyan": "00ffff",
  "darkblue": "00008b",
  "darkcyan": "008b8b",
  "darkgoldenrod": "b8860b",
  "darkgray": "a9a9a9",
  "darkgrey": "a9a9a9",
  "darkgreen": "006400",
  "darkkhaki": "bdb76b",
  "darkmagenta": "8b008b",
  "darkolivegreen": "556b2f",
  "darkorange": "ff8c00",
  "darkorchid": "9932cc",
  "darkred": "8b0000",
  "darksalmon": "e9967a",
  "darkseagreen": "8fbc8f",
  "darkslateblue": "483d8b",
  "darkslategray": "2f4f4f",
  "darkslategrey": "2f4f4f",
  "darkturquoise": "00ced1",
  "darkviolet": "9400d3",
  "deeppink": "ff1493",
  "deepskyblue": "00bfff",
  "dimgray": "696969",
  "dimgrey": "696969",
  "dodgerblue": "1e90ff",
  "firebrick": "b22222",
  "floralwhite": "fffaf0",
  "forestgreen": "228b22",
  "fuchsia": "ff00ff",
  "gainsboro": "dcdcdc",
  "ghostwhite": "f8f8ff",
  "gold": "ffd700",
  "goldenrod": "daa520",
  "gray": "808080",
  "grey": "808080",
  "green": "008000",
  "greenyellow": "adff2f",
  "honeydew": "f0fff0",
  "hotpink": "ff69b4",
  "indianred": "cd5c5c",
  "indigo": "4b0082",
  "ivory": "fffff0",
  "khaki": "f0e68c",
  "lavender": "e6e6fa",
  "lavenderblush": "fff0f5",
  "lawngreen": "7cfc00",
  "lemonchiffon": "fffacd",
  "lightblue": "add8e6",
  "lightcoral": "f08080",
  "lightcyan": "e0ffff",
  "lightgoldenrodyellow": "fafad2",
  "lightgray": "d3d3d3",
  "lightgrey": "d3d3d3",
  "lightgreen": "90ee90",
  "lightpink": "ffb6c1",
  "lightsalmon": "ffa07a",
  "lightseagreen": "20b2aa",
  "lightskyblue": "87cefa",
  "lightslategray": "778899",
  "lightslategrey": "778899",
  "lightsteelblue": "b0c4de",
  "lightyellow": "ffffe0",
  "lime": "00ff00",
  "limegreen": "32cd32",
  "linen": "faf0e6",
  "magenta": "ff00ff",
  "maroon": "800000",
  "mediumaquamarine": "66cdaa",
  "mediumblue": "0000cd",
  "mediumorchid": "ba55d3",
  "mediumpurple": "9370db",
  "mediumseagreen": "3cb371",
  "mediumslateblue": "7b68ee",
  "mediumspringgreen": "00fa9a",
  "mediumturquoise": "48d1cc",
  "mediumvioletred": "c71585",
  "midnightblue": "191970",
  "mintcream": "f5fffa",
  "mistyrose": "ffe4e1",
  "moccasin": "ffe4b5",
  "navajowhite": "ffdead",
  "navy": "000080",
  "oldlace": "fdf5e6",
  "olive": "808000",
  "olivedrab": "6b8e23",
  "orange": "ffa500",
  "orangered": "ff4500",
  "orchid": "da70d6",
  "palegoldenrod": "eee8aa",
  "palegreen": "98fb98",
  "paleturquoise": "afeeee",
  "palevioletred": "db7093",
  "papayawhip": "ffefd5",
  "peachpuff": "ffdab9",
  "peru": "cd853f",
  "pink": "ffc0cb",
  "plum": "dda0dd",
  "powderblue": "b0e0e6",
  "purple": "800080",
  "rebeccapurple": "663399",
  "red": "ff0000",
  "rosybrown": "bc8f8f",
  "royalblue": "4169e1",
  "saddlebrown": "8b4513",
  "salmon": "fa8072",
  "sandybrown": "f4a460",
  "seagreen": "2e8b57",
  "seashell": "fff5ee",
  "sienna": "a0522d",
  "silver": "c0c0c0",
  "skyblue": "87ceeb",
  "slateblue": "6a5acd",
  "slategray": "708090",
  "slategrey": "708090",
  "snow": "fffafa",
  "springgreen": "00ff7f",
  "steelblue": "4682b4",
  "tan": "d2b48c",
  "teal": "008080",
  "thistle": "d8bfd8",
  "tomato": "ff6347",
  "turquoise": "40e0d0",
  "violet": "ee82ee",
  "wheat": "f5deb3",
  "white": "ffffff",
  "whitesmoke": "f5f5f5",
  "yellow": "ffff00",
  "yellowgreen": "9acd32",
};

double hue2rgb(double p, double q, double t) {
  if (t < 0.0) t += 1.0;
  if (t > 1.0) t -= 1.0;
  if (t < 1 / 6) return p + (q - p) * 6.0 * t;
  if (t < 1 / 2) return q;
  if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6.0;
  return p;
}

int hue2rgb255(double p, double q, double t) {
  return (hue2rgb(p, q, t) * 255.0).floor();
}

class RGB {
  // range 0-255
  int r;
  int g;
  int b;
  double a = 1.0;

  RGB(this.r, this.g, this.b);

  RGB.fromName(String name) {
    String hex;
    if (name[0] == "#") {
      hex = name.substring(1);
    } else {
      hex = _HtmlColors[name];
      assert(hex != null, "unknown color: ${name}");
    }
    int t = int.parse(hex, radix: 16);
    b = t & 0xff;
    t >>= 8;
    g = t & 0xff;
    t >>= 8;
    r = t & 0xff;
  }

  RGB.fromGray(int gray) {
    r = gray;
    g = gray;
    b = gray;
  }

  RGB.fromRandom(Math.Random rng) {
    r = (rng.nextDouble() * 256.0).floor();
    g = (rng.nextDouble() * 256.0).floor();
    b = (rng.nextDouble() * 256.0).floor();
  }

  RGB.fromRandomGray(Math.Random rng) {
    r = (rng.nextDouble() * 256).floor();
    g = r;
    b = r;
  }

  RGB.fromClone(RGB other) {
    r = other.r;
    g = other.g;
    b = other.b;
    a = other.a;
  }

  RGB.fromHSL(double h, double s, double l) {
    if (s == 0.0) {
      r = (255.0 * l).floor();
      g = (255.0 * l).floor();
      b = (255.0 * l).floor();
      return;
    }
    double q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    double p = 2.0 * l - q;
    r = hue2rgb255(p, q, h + 1 / 3);
    g = hue2rgb255(p, q, h);
    b = hue2rgb255(p, q, h - 1 / 3);
  }

  VM.Vector3 GlColor() {
    return new VM.Vector3(r / 255.0, g / 255.0, b / 255.0);
  }

  VM.Vector4 GlColorWithAlpha(double alpha) {
    return new VM.Vector4(r / 255.0, g / 255.0, b / 255.0, alpha);
  }

  void scale(double s) {
    r = (r * s).floor();
    g = (g * s).floor();
    b = (b * s).floor();
  }

  void add(RGB c) {
    r += c.r;
    g += c.g;
    b += c.b;
  }

  void addNoise(Math.Random rng, double noisePercent) {
    scale(1.0 - noisePercent);
    RGB random = new RGB.fromRandom(rng);
    random.scale(noisePercent);
    add(random);
  }

  double Hue() {
    int m = Math.min(Math.min(r, g), b);
    int M = Math.max(Math.max(r, g), b);
    int C = M - m;
    if (C == 0) return 0.0;

    if (M == r) {
      double v = ((g - b) / C + 0) / 3;
      if (v < 0.0) v += 1.0;
      return v;
    } else if (M == g) {
      return ((b - r) / C + 1) / 3;
    } else {
      return ((r - g) / C + 2) / 3;
    }
  }

  int ToInt() {
    return ((r * 256) + g) * 256 + b;
  }

  String ToString() {
    return "rgba($r, $g, $b, $a)";
  }

  String ToString256() {
    return "rgba($r, $g, $b, ${(a * 255.0).floor()})";
  }

  int average() {
    return (r + g + b) ~/ 3;
  }
}

final RGB kRGBblack = new RGB(0, 0, 0);
final RGB kRGBwhite = new RGB(255, 255, 255);
final RGB kRGBred = new RGB(255, 0, 0);
final RGB kRGBgreen = new RGB(0, 255, 0);
final RGB kRGBblue = new RGB(0, 0, 255);
final RGB kRGByellow = new RGB(255, 255, 0);
final RGB kRGBcyan = new RGB(0, 255, 255);
final RGB kRGBmagenta = new RGB(255, 0, 255);
final RGB kRGBtransparent = new RGB.fromGray(0)..a = 0.0;
