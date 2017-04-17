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
This file contains abstractions for Meshes and Materials that isolate us
from the underlying rendering system.
renderer.dart translates these abstractions to ChronosGL
*/

library geometry;

import 'package:vector_math/vector_math.dart' as VM;

int defaultAnisoLevel = 1;

class FaceMat {
  dynamic canvas = null;
  String name;
  bool clamp = false;
  bool transparent = false;
  bool depthWrite = true;
  int pointSize = -1;
  bool is_points = false;
  bool flashing = false;
  int anisoLevel = defaultAnisoLevel;

  FaceMat(this.name) {
    //LogInfo("adding facemat: $name");
    //assert(!_gFaceMatNames.contains(name));
  }
}

class Rect {
  double x;
  double y;
  double w;
  double h;
  Rect(this.x, this.y, this.w, this.h) {
    assert(w >= 0);
    assert(h >= 0);
  }

  Rect Clone() {
    return new Rect(x, y, w, h);
  }

  Rect.withOffset(double x, double y, double w, double h, double offset)
      : this(x - offset, y - offset, w + 2 * offset, h + 2 * offset);

  void IncreaseByOffset(double offset) {
    x -= offset;
    y -= offset;
    w += 2 * offset;
    h += 2 * offset;
  }

  String toString() {
    return "Rect($x, $y, $w, $h)";
  }

  bool Contains(Rect o) {
    return x <= o.x && o.x + o.w <= x + w && y <= o.y && o.y + o.h <= y + h;
  }
}

final List<VM.Vector2> kNoUV3 = [
  new VM.Vector2(0.0, 0.0),
  new VM.Vector2(0.0, 0.0),
  new VM.Vector2(0.0, 0.0)
];

class Triad {
  List<VM.Vector3> v;
  List<VM.Vector2> t;

  Triad(this.v, [uvs = null]) {
    t = (uvs == null) ? kNoUV3 : uvs;
  }
}

class Quad {
  List<VM.Vector3> v = [];
  List<VM.Vector2> t = [];

  Quad(this.v, Rect uv) {
    _PopulateUV(uv);
  }

  Quad.fromXZ(Rect r, double y, bool front, Rect uv) {
    VM.Vector3 vec(double a, double b) {
      return new VM.Vector3(a, y, b);
    }

    VM.Vector3 a = vec(r.x, r.y);
    VM.Vector3 b = vec(r.x, r.y + r.h);
    VM.Vector3 c = vec(r.x + r.w, r.y + r.h);
    VM.Vector3 d = vec(r.x + r.w, r.y);
    _PopulateVertices([a, b, c, d], front);
    _PopulateUV(uv);
  }

  Quad.fromXZflipped(Rect r, double y, bool front, Rect uv) {
    VM.Vector3 vec(double a, double b) {
      return new VM.Vector3(a, y, b);
    }

    VM.Vector3 a = vec(r.x, r.y);
    VM.Vector3 b = vec(r.x, r.y + r.h);
    VM.Vector3 c = vec(r.x + r.w, r.y + r.h);
    VM.Vector3 d = vec(r.x + r.w, r.y);
    _PopulateVertices([a, b, c, d], front);
    _PopulateUVFlipped(uv);
  }

  Quad.fromXY(Rect r, double z, bool front, Rect uv) {
    VM.Vector3 vec(double a, double b) {
      return new VM.Vector3(a, b, z);
    }

    VM.Vector3 a = vec(r.x, r.y);
    VM.Vector3 b = vec(r.x, r.y + r.h);
    VM.Vector3 c = vec(r.x + r.w, r.y + r.h);
    VM.Vector3 d = vec(r.x + r.w, r.y);
    _PopulateVertices([a, b, c, d], front);
    _PopulateUV(uv);
  }

  Quad.fromZY(Rect r, double x, bool front, Rect uv) {
    VM.Vector3 vec(double a, double b) {
      return new VM.Vector3(x, a, b);
    }

    VM.Vector3 a = vec(r.y, r.x);
    VM.Vector3 b = vec(r.y + r.h, r.x);
    VM.Vector3 c = vec(r.y + r.h, r.x + r.w);
    VM.Vector3 d = vec(r.y, r.x + r.w);
    _PopulateVertices([a, b, c, d], front);
    _PopulateUV(uv);
  }

  void _PopulateVertices(List<VM.Vector3> vertices, bool front) {
    if (front) {
      // 23
      // 14
      v.addAll(vertices);
    } else {
      // 32
      // 41
      v.addAll(vertices.reversed);
    }
  }

  void _PopulateUV(Rect uv) {
    t.add(new VM.Vector2(uv.x + uv.w, uv.y));
    t.add(new VM.Vector2(uv.x + uv.w, uv.y + uv.h));
    t.add(new VM.Vector2(uv.x, uv.y + uv.h));
    t.add(new VM.Vector2(uv.x, uv.y));
  }

  void _PopulateUVFlipped(Rect uv) {
    t.add(new VM.Vector2(uv.x, uv.y + uv.h));
    t.add(new VM.Vector2(uv.x + uv.w, uv.y + uv.h));
    t.add(new VM.Vector2(uv.x + uv.w, uv.y));
    t.add(new VM.Vector2(uv.x, uv.y));
  }
}

final _epsilon = 0.05;
final Rect kFullUV = new Rect(0.0, 0.0, 1.0, 1.0);
final Rect kAlmostFullUV =
    new Rect(_epsilon, _epsilon, 1.0 - 2 * _epsilon, 1.0 - 2 * _epsilon);

class ColorMat {
  FaceMat mat;
  VM.Vector3 color;
  ColorMat(this.mat, this.color);
}

class Shape {
  Set<FaceMat> materials = new Set<FaceMat>();

  Map<FaceMat, List<VM.Vector3>> pointsPos = {};
  Map<FaceMat, List<double>> pointsSize = {};
  Map<FaceMat, List<VM.Vector3>> pointsColor = {};

  //
  Map<FaceMat, List<Quad>> quadsPos = {};
  Map<FaceMat, List<VM.Vector3>> quadsColor = {};

  //
  Map<FaceMat, List<Triad>> triadsPos = {};
  Map<FaceMat, List<VM.Vector3>> triadsColor = {};

  void AddPoint(VM.Vector3 pos, double size, ColorMat m) {
    materials.add(m.mat);
    List<VM.Vector3> p = pointsPos[m.mat];
    List<VM.Vector3> c = pointsColor[m.mat];
    List<double> s = pointsSize[m.mat];
    if (p == null) {
      p = new List<VM.Vector3>();
      pointsPos[m.mat] = p;
      c = new List<VM.Vector3>();
      pointsColor[m.mat] = c;
      s = new List<double>();
      pointsSize[m.mat] = s;
    }
    p.add(pos);
    s.add(size);
    c.add(m.color);
  }

  void AddManyPoints(List<VM.Vector3> pos, size, ColorMat m) {
    materials.add(m.mat);
    List<VM.Vector3> p = pointsPos[m.mat];
    List<VM.Vector3> c = pointsColor[m.mat];
    List<double> s = pointsSize[m.mat];
    if (p == null) {
      p = new List<VM.Vector3>();
      pointsPos[m.mat] = p;
      c = new List<VM.Vector3>();
      pointsColor[m.mat] = c;
      s = new List<double>();
      pointsSize[m.mat] = s;
    }
    p.addAll(pos);
    for (int i = 0; i < pos.length; ++i) {
      s.add(size);
      c.add(m.color);
    }
  }

  void AddQuad(Quad q, ColorMat m) {
    materials.add(m.mat);
    List<Quad> p = quadsPos[m.mat];
    List<VM.Vector3> c = quadsColor[m.mat];
    if (p == null) {
      p = new List<Quad>();
      quadsPos[m.mat] = p;
      c = new List<VM.Vector3>();
      quadsColor[m.mat] = c;
    }
    p.add(q);
    c.add(m.color);
  }

  void AddTriad(Triad t, ColorMat m) {
    materials.add(m.mat);
    List<Triad> p = triadsPos[m.mat];
    List<VM.Vector3> c = triadsColor[m.mat];
    if (p == null) {
      p = new List<Triad>();
      triadsPos[m.mat] = p;
      c = new List<VM.Vector3>();
      triadsColor[m.mat] = c;
    }
    p.add(t);
    c.add(m.color);
  }
}
