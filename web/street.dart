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

// TODO: merge this file into another one. It is too small to be stand alone.

library pc_street;

import 'dart:math' as Math;
import 'package:vector_math/vector_math.dart' as VM;

import 'geometry.dart';
import 'config.dart';


Quad MakeFloor(double w, double h) {
  return new Quad.fromXZ(new Rect(0.0, 0.0, w, h), 0.0, true, kFullUV);
}


void AddCar(Shape shape, ColorMat m) {
  final Rect footprint =
      new Rect(-kCarSpriteSizeW / 2, -kCarSpriteSizeW / 2, kCarSpriteSizeW, kCarSpriteSizeW);
  shape.AddQuad(
      new Quad.fromXZ(footprint, kCarLevel, true, kFullUV), m);
}

void AddCarBody(Shape shape, ColorMat mat) {
  final double w = kCarWidth;
  final double l = kCarLength;
  final double h = kCarHeight;
  final Rect top = new Rect(-w / 2, -l / 2, w, l);
  final Rect fb = new Rect(-w / 2, kCarLevel, w, h + kCarLevel);
  final Rect lr = new Rect(-l / 2, kCarLevel, l, h + kCarLevel);

  shape.AddQuad(new Quad.fromXZ(top, h + kCarLevel, true, kFullUV), mat);
  shape.AddQuad(new Quad.fromXY(fb, -l / 2, true, kFullUV), mat);
  shape.AddQuad(new Quad.fromXY(fb, l / 2, true, kFullUV), mat);
  shape.AddQuad(new Quad.fromZY(lr, -w / 2, true, kFullUV), mat);
  shape.AddQuad(new Quad.fromZY(lr, w / 2, true, kFullUV), mat);
}

List<VM.Vector2> MakeRegularPolygonShape(int n, double r, double cx, double cy) {
  List<VM.Vector2> out = [];
  for (int i = 0; i < n; i++) {
    double angle = 2.0 * Math.PI * i / n;
    double x = cx + r * Math.cos(angle);
    double y = cy + r * Math.sin(angle);
    out.add(new VM.Vector2(x, y));
  }
  return out;
}
