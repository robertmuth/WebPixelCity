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
This file contains code to generate the sky texture.
TODO: do not you use Canvas for this
*/

library pc_sky;

import 'dart:html' as HTML;
import 'dart:math' as Math;

import 'rgb.dart';



int _BuildingHeight(int h) {
  return h ~/ 64;
}

void _DrawRemoteBuildings(
    Math.Random rng, HTML.CanvasRenderingContext2D c, int w, int h, RGB color) {
  int averageW = w ~/ 256;
  int averageHThird = _BuildingHeight(h) ~/ 3;
  int spacing = averageW * 2;  // this needs to be a function of world size
  for (int i = 0; i < w; i += rng.nextInt(spacing)) {
    int theH = rng.nextInt(averageHThird) +
        rng.nextInt(averageHThird) +
        rng.nextInt(averageHThird);
    int theW = averageW ~/ 2 + rng.nextInt(averageW) ~/ 2;
    c
      ..fillStyle = color.ToString()
      ..fillRect(i, h + 1 - theH, theW, theH);
  }
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

class CloudFudge {
  double wAdjust;
  double hAdjust;
  bool isBlack;

  CloudFudge(this.wAdjust, this.hAdjust, this.isBlack);
}

List<CloudFudge> kCloudFudge = [
  new CloudFudge(0.5, 2.0, true),
  new CloudFudge(0.75, 1.75, true),
  new CloudFudge(1.0, 1.5, true),
  new CloudFudge(1.25, 1.25, false),
];

void DrawSingleCloud(HTML.CanvasRenderingContext2D c, int cx, int cy, int rw, int rh,
    RGB color, RGB black) {
  //RGB nothing = new RGB.fromGray(0)..a = 0.2;
  for (CloudFudge cf in kCloudFudge) {
    //if (cf.isBlack) continue;
    _DrawOvalGradient(c, cx, cy, (rw * cf.wAdjust).floor(),
        (rh * cf.hAdjust).floor(), color, black);
  }
}

void DrawClouds(Math.Random rng, HTML.CanvasRenderingContext2D c, int w, int h,
    RGB color, RGB black) {
  int minH = h ~/ 128;
  int bh = _BuildingHeight(h);
  for (int cy = h - bh; cy > 5; cy -= h ~/ bh) {
    int cx = rng.nextInt(w);
    double scale = 1.0 - cy / h;
    // The higher the cloud the thicker
    int cw = rng.nextInt(w ~/ 2) + (w ~/ 2 * scale).floor();
    int ch = Math.max(minH, (cw ~/ 8 * scale).floor());
    //LogInfo("Cloud: $cx $cy $cw $ch");
    // Make the canvas tilable
    DrawSingleCloud(c, cx, cy, cw, ch, color, black);
    DrawSingleCloud(c, cx + w, cy, cw, ch, color, black);
    DrawSingleCloud(c, cx - w, cy, cw, ch, color, black);
  }
}

HTML.CanvasElement MakeCanvasSky(Math.Random rng, int w, int h, RGB colorHorizon1,
    RGB colorHorizon2, RGB colorCloud) {
  HTML.CanvasElement canvas = new HTML.CanvasElement();
  canvas
    ..width = w
    ..height = h;
  HTML.CanvasRenderingContext2D c = canvas.context2D;
  c
    ..fillStyle = colorHorizon1.ToInt()
    ..fillRect(0, 0, w, h);

  RGB white = new RGB.fromClone(colorHorizon2)..a = 0.2;
  HTML.CanvasGradient g = c.createLinearGradient(0, h ~/ 2, 0, h);
  g.addColorStop(0, colorHorizon1.ToString());
  g.addColorStop(1, colorHorizon2.ToString());
  c
    ..fillStyle = g
    ..fillRect(0, 0, w, h);
  _DrawRemoteBuildings(rng, c, w, h, colorHorizon1);
  //c..globalAlpha = 0.5;
  DrawClouds(rng, c, w, h, white, kRGBtransparent);
  //c..globalAlpha = 1.0;
  //DrawClouds(rng, c, w, h, bloom);
  // Clear out top
  int fadeH = h ~/ 8;
  HTML.CanvasGradient fadeOut = c.createLinearGradient(0, 0, 0, fadeH);
  fadeOut.addColorStop(0, "rgba(0,0,0,1)");
  fadeOut.addColorStop(1, "rgba(0,0,0,0)");

  c
    ..fillStyle = fadeOut
    ..fillRect(0, 0, w, fadeH);
  return canvas;
}
