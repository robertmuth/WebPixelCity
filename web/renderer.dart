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

library renderer;

import 'dart:html' as HTML;
import 'dart:typed_data';

import 'package:chronosgl/chronosgl.dart';
import 'package:vector_math/vector_math.dart' as VM;

import 'rgb.dart';
import 'geometry.dart';
import 'floor_plan.dart';
import 'logging.dart' as log;

const String uFlashing = "uFlashing";

HTML.CanvasElement DebugPatternCanvas(int r) {
  HTML.CanvasElement canvas = new HTML.CanvasElement();
  canvas
    ..width = 2 * r
    ..height = 2 * r;
  int m = r ~/ 4;
  int n = 2 * r - 2 * m;
  int fh = m ~/ 2;
  HTML.CanvasRenderingContext2D c = canvas.context2D;
  c
    ..fillStyle = "blue"
    ..fillRect(0, 0, 2 * r, 2 * r)
    ..fillStyle = "white"
    ..fillRect(m, m, m, m)
    ..fillRect(m, n, m, m)
    ..fillRect(n, m, m, m)
    ..fillRect(n, n, m, m)
    ..fillStyle = "black"
    ..font = "${fh}px Arial"
    ..fillText("0 0", m, m + fh)
    ..fillText("0 1", m, n + fh)
    ..fillText("1 0", n, m + fh)
    ..fillText("1 1", n, n + fh);
  return canvas;
}

// For actual rendering
// TODO: check whether the gpu supports this big a texture.
HTML.CanvasElement RenderCanvasWorldMapSlow(WorldMap wm) {
  HTML.CanvasElement canvas = new HTML.CanvasElement();
  final int w = wm.width;
  final int h = wm.height;
  canvas
    ..width = w
    ..height = h;
  HTML.CanvasRenderingContext2D c = canvas.context2D;
  c
    ..fillStyle = "#141414"
    ..fillRect(0, 0, w, h);
  c..fillStyle = "#101010";
  // Note, this was a performance bottleneck at one point.
  for (int x = 0; x < w; x++) {
    for (int y = 0; y < h; y++) {
      int tile = FloorplanGetTileType(wm.GetTile(x, y));
      if (tile == kTileLane) {
        // Make texture produced from canvas compatible with our work orientation.
        int ix = w - x - 1;
        int iy = h - y - 1;
        c..fillRect(ix, iy, 1, 1);
      }
    }
  }
  return canvas;
}

HTML.CanvasElement RenderCanvasWorldMap(WorldMap wm, RGB lane, RGB other) {
  HTML.CanvasElement canvas = new HTML.CanvasElement();
  final int w = wm.width;
  final int h = wm.height;
  canvas
    ..width = w
    ..height = h;
  HTML.CanvasRenderingContext2D c = canvas.context2D;
  HTML.ImageData id = c.createImageData(w, h);
  Uint8ClampedList data = id.data;

  final int or = other.r;
  final int og = other.g;
  final int ob = other.b;
  for (int i = 0; i < w * h * 4; i += 4) {
    data[i + 0] = or;
    data[i + 1] = og;
    data[i + 2] = ob;
    data[i + 3] = 255;
  }

  final int r = lane.r;
  final int g = lane.g;
  final int b = lane.b;
  for (int x = 0; x < w; x++) {
    for (int y = 0; y < h; y++) {
      int tile = FloorplanGetTileType(wm.GetTile(x, y));
      if (tile == kTileLane) {
        // Make texture produced from canvas compatible with our work orientation.
        final int ix = w - x - 1;
        final int iy = h - y - 1;
        final int i = 4 * (iy * w + ix);
        data[i + 0] = r;
        data[i + 1] = g;
        data[i + 2] = b;
        data[i + 3] = 255;
      }
    }
  }
  c.putImageData(id, 0, 0);
  return canvas;
}

// For debugging
HTML.CanvasElement RenderWorldMapToCanvas(WorldMap wm, int cellW, int cellH) {
  HTML.CanvasElement canvas = new HTML.CanvasElement();
  final int w = wm.width;
  final int h = wm.height;
  canvas
    ..width = w * cellW
    ..height = h * cellH;
  HTML.CanvasRenderingContext2D c = canvas.context2D;
  for (int x = 0; x < w; x++) {
    for (int y = 0; y < h; y++) {
      String color = "white";
      final int tile = wm.GetTile(x, y);
      switch (FloorplanGetTileType(tile)) {
        case kTileLane:
          int dirs = FloorplanGetTileDir(tile);
          if (dirs & (dirs - 1) == 0) {
            color = "gray";
          } else {
            color = "red";
          }
          break;
        case kTileSidewalk:
          color = "blue";
          break;
        case kTileSidewalkLight:
          color = "yellow";
          break;
        case kTileDivider:
          color = "green";
          break;
        case kTileBuildingSimple:
          color = "#00ff00";
          break;
        case kTileBuildingTower:
        case kTileBuildingModern:
        case kTileBuildingBlocky:
          color = "#00dd00";
          break;
        case kTileBuildingBorder:
          color = "#00bb00";
          break;
      }
      c
        ..fillStyle = color
        ..fillRect(x * cellW, y * cellH, cellW, cellH);
    }
  }
  return canvas;
}

// For now we will ignore texture tinting and colapse all tinted
// texture to one.
Map<HTML.CanvasElement, Texture> _gTextureCache = {};

// This should be a TextureWrapper.
Material ConvertToChronosMaterial(ChronosGL cgl, FaceMat facemat) {
  Texture tw;
  if (facemat.canvas == null) {
    tw = MakeSolidColorTexture(cgl, facemat.name, "white");
  } else {
    if (!_gTextureCache.containsKey(facemat.canvas)) {
      HTML.CanvasElement canvas = facemat.canvas;
      log.LogInfo(
          "Setting up ${facemat.name} ${canvas} ${canvas.width}x${canvas.height}");

      TextureProperties tp = new TextureProperties();
      if (facemat.clamp) {
        tp.clamp = true;
      }
      tp.SetMipmapLinear();
      tp.mipmap = true;
      if (facemat.anisoLevel != 1) {
        tp.anisotropicFilterLevel = facemat.anisoLevel;
      }

      tw = new ImageTexture(cgl, facemat.name, facemat.canvas, false, tp);
      _gTextureCache[facemat.canvas] = tw;
    }
    tw = _gTextureCache[facemat.canvas];
  }
  Material mat = new Material(facemat.name)..SetUniform(uTexture, tw);
  if (facemat.transparent) {
    mat
      ..ForceUniform(cBlend, true)
      ..SetUniform(cBlendEquation, new BlendEquation.Standard());
  }
  if (!facemat.depthWrite) {
    mat.ForceUniform(cDepthWrite, false);
  }
  if (facemat.pointSize >= 0) {
    mat.SetUniform(uPointSize, facemat.pointSize * 1.0);
  }
  if (facemat.flashing) {
    mat.SetUniform(uFlashing, 1.0);
  }

  return mat;
}

void AddOneMesh(GeometryBuilder gb, FaceMat m, Shape shape) {
  final List<Quad> qpos = shape.quadsPos[m];
  final List<Triad> tpos = shape.triadsPos[m];
  final List<VM.Vector3> ppos = shape.pointsPos[m];
  if (qpos != null || tpos != null) {
    assert(ppos == null);
    if (!gb.HasAttribute(aColor)) {
      gb.EnableAttribute(aTextureCoordinates);
      gb.EnableAttribute(aColor);
    }
    if (qpos != null) {
      assert(qpos.length > 0);
      final List<VM.Vector3> qcol = shape.quadsColor[m];
      for (int i = 0; i < qpos.length; i++) {
        final Quad q = qpos[i];
        final VM.Vector3 c = qcol[i];
        gb.AddFaces4(1);
        gb.AddVertices(q.v);
        gb.AddAttributesVector2(aTextureCoordinates, q.t);
        gb.AddAttributesVector3(aColor, [c, c, c, c]);
      }
    }
    if (tpos != null) {
      assert(tpos.length > 0);
      final List<VM.Vector3> tcol = shape.triadsColor[m];
      for (int i = 0; i < tpos.length; i++) {
        final Triad t = tpos[i];
        final VM.Vector3 c = tcol[i];
        gb.AddFaces3(1);
        gb.AddVertices(t.v);
        gb.AddAttributesVector2(aTextureCoordinates, t.t);
        gb.AddAttributesVector3(aColor, [c, c, c]);
      }
    }
  } else {
    if (!gb.HasAttribute(aColor)) {
      gb.EnableAttribute(aPointSize);
      gb.EnableAttribute(aColor);
    }
    for (VM.Vector3 p in ppos) {
      gb.AddVertex(p);
    }
    gb.AddAttributesDouble(aPointSize, shape.pointsSize[m]);
    gb.AddAttributesVector3(aColor, shape.pointsColor[m]);
  }
}

Node ConvertToChronosGLSingle(String name, ChronosGL cgl, Shape shape) {
  assert(shape.materials.length == 1);
  FaceMat m = shape.materials.first;
  GeometryBuilder gb = new GeometryBuilder(m.is_points);
  AddOneMesh(gb, m, shape);
  if (!gb.pointsOnly) gb.GenerateWireframeCenters();
  Material mat = ConvertToChronosMaterial(cgl, m);
  return new Node(name, GeometryBuilderToMeshData(mat.name, cgl, gb), mat);
}

Node ConvertToChronosGLSingleWithInstancer(
    String name, ChronosGL cgl, Shape shape, InstancerData instancer) {
  assert(shape.materials.length == 1);
  FaceMat m = shape.materials.first;
  GeometryBuilder gb = new GeometryBuilder(m.is_points);
  AddOneMesh(gb, m, shape);
  if (!gb.pointsOnly) gb.GenerateWireframeCenters();
  Material mat = ConvertToChronosMaterial(cgl, m);
  return new Node.WithInstances(
      name, GeometryBuilderToMeshData(mat.name, cgl, gb), instancer, mat);
}

List<Node> ConvertToChronosGL(ChronosGL cgl, Shape shape) {
  log.LogInfo(
      "Converting ${shape.quadsPos.length} face4 and ${shape.triadsPos.length} face3");

  Map<FaceMat, GeometryBuilder> meshes = {};
  Map<FaceMat, Material> mats = {};
  for (FaceMat m in shape.materials) {
    if (meshes[m] == null) {
      mats[m] = ConvertToChronosMaterial(cgl, m);
      meshes[m] = new GeometryBuilder(m.is_points);
    }
  }

  for (FaceMat m in shape.materials) {
    GeometryBuilder gb = meshes[m];
    AddOneMesh(gb, m, shape);
  }
  List<Node> out = [];
  for (FaceMat m in meshes.keys) {
    GeometryBuilder gb = meshes[m];
    log.LogInfo("mesh [${m.name}] has ${gb.vertices.length} vertices");
    // For wireframe
    if (!gb.pointsOnly) gb.GenerateWireframeCenters();
    out.add(
        new Node("mesh", GeometryBuilderToMeshData(m.name, cgl, gb), mats[m]));
  }

  log.LogInfo("conversion done");
  return out;
}
