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
This file contains code for laying out buildings in the world
and managing the cars.
*/

library pc_floorplan;

import 'dart:math';
import 'dart:typed_data';
import 'geometry.dart';
import 'logging.dart' as log;


const int kWorldBorder = 0;
const double kMaxCarMovement = 0.5;

const int kMinBuildingSize = 12;
const int kMinRoadDistance = 25;

const int kTileEmpty = 0;

// Order is important
const int kTileSidewalkLight = 1;
const int kTileSidewalk = 2;
const int kTileDivider = 3;
const int kTileLane = 4;

const int kTileBuildingBorder = 8;
const int kTileBuildingTower = 9;
const int kTileBuildingBlocky = 10;
const int kTileBuildingModern = 11;
const int kTileBuildingSimple = 12;

const int kDirEast = 16;
const int kDirWest = 32;
const int kDirNorth = 64;
const int kDirSouth = 128;

int FloorplanGetTileType(int t) {
  return t & 0xf;
}

int FloorplanGetTileDir(int t) {
  return t & 0xf0;
}

int CountBits(int i) {
  int n = 0;
  int b = i;
  while (true) {
    if (b == 0) break;
    n++;
    b &= b - 1;
  }
  return n;
}

bool OnlyOneBitSet(int b) {
  return b & (b - 1) == 0;
}

int RandomSetBit(Random rng, int bits, int n) {
  if (n == 1) return bits;
  int s = 1 + rng.nextInt(n - 1);
  int last;
  for (int i = 0; i < s; i++) {
    last = bits;
    bits &= bits - 1;
  }
  return last ^ bits;
}

class WorldConfig {
  final int _dimension;

  WorldConfig(this._dimension);

  int Dimension() {
    return _dimension;
  }

  int CenterDimension() {
    return _dimension ~/ 2;
  }

  int NumSkyscapers() {
    return CenterDimension() * CenterDimension() ~/ 10000;
  }

  int NumCars() {
    return Dimension() * Dimension() ~/ 2048;
  }

  bool IsWithinCenter(Rect r) {
    final int lo = Dimension() ~/ 2 - CenterDimension() ~/ 2;
    final int hi = Dimension() ~/ 2 + CenterDimension() ~/ 2;
    if (r.x + r.w < lo) return false;
    if (r.x > hi) return false;
    if (r.y + r.h < lo) return false;
    if (r.y > hi) return false;
    return true;
  }

  bool IsAtBorder(Rect r) {
    if (r.x + r.w > _dimension - kMinRoadDistance) return true;
    if (r.x < kMinRoadDistance) return true;
    if (r.y + r.h > _dimension - kMinRoadDistance) return true;
    if (r.y < kMinRoadDistance) return true;
    return false;
  }
}

class WorldMap {
  final int _w;
  final int _h;
  Uint8List _tiles;
  Map<PosInt, Car> _carLocations = {};
  //Uint8List _cars;

  WorldMap(this._w, this._h) {
    _tiles = new Uint8List(_w * _h);
    for (int i = 0; i < _w * _h; i++) {
      _tiles[i] = kTileEmpty;
    }
  }

  get width => _w;
  get height => _h;

  Car GetCarAtPos(final PosInt p) {
    return _carLocations[p];
  }

  bool HasCarPos(final PosInt p) {
    return GetCarAtPos(p) != null;
  }

  void SetCarPos(PosInt p, Car car) {
    if (car == null) {
      _carLocations.remove(p);
    } else {
      _carLocations[p] = car;
    }
  }

  int GetTile(int x, int y) {
    int index = x + y * _h;
    return _tiles[index];
  }

  int GetTilePos(final PosInt pos) {
    if (pos.x < 0 || pos.y < 0 || pos.x >= _w || pos.y >= _h) return kTileEmpty;
    return GetTile(pos.x, pos.y);
  }

  bool IsEmpty(int x, int y) {
    int index = x + y * _h;
    return _tiles[index] == kTileEmpty;
  }

  bool IsEmptyPlot(int x, int y, int w, int d) {
    for (int i = 0; i < w; i++) {
      if (!IsEmpty(x + i, y)) return false;
      if (!IsEmpty(x + i, y + d - 1)) return false;
    }

    for (int i = 0; i < d; i++) {
      if (!IsEmpty(x, y + i)) return false;
      if (!IsEmpty(x + w - 1, y + i)) return false;
    }

    return true;
  }

  // This relies on having streets all around - sentinels
  Rect MaxEmptyPlotContaining(int x, int y) {
    int x1 = x;
    int x2 = x;
    int y1 = y;
    int y2 = y;
    for (x1--; IsEmpty(x1, y); x1--);
    x1++;
    for (x2++; IsEmpty(x2, y); x2++);
    x2--;
    for (y1--; IsEmpty(x, y1); y1--);
    y1++;
    for (y2++; IsEmpty(x, y2); y2++);
    y2--;
    return new Rect(x1 * 1.0, y1 * 1.0, x2 - x1 + 1.0, y2 - y1 + 1.0);
  }

  void MergeTile(int x, int y, int new_kind) {
    //LogInfo("merge");
    final int index = x + y * _h;
    final int old_kind = _tiles[index];
    final int old_type = FloorplanGetTileType(old_kind);
    final int new_type = FloorplanGetTileType(new_kind);
    if (new_type == old_type) {
      _tiles[index] = new_kind | old_kind;
      assert(CountBits(FloorplanGetTileDir(_tiles[index])) <= 2);
    } else if (old_type < new_type) {
      _tiles[index] = new_kind;
    }
  }

  void ForceTile(int x, int y, int kind) {
    int index = x + y * _h;
    _tiles[index] = kind;
  }

  void ForceTilePos(PosInt p, int kind) {
    return ForceTile(p.x, p.y, kind);
  }

  void MarkPlot(Rect plot, int kind) {
    int x = plot.x.floor();
    int y = plot.y.floor();
    int w = plot.w.floor();
    int h = plot.h.floor();
    for (int i = 0; i < w; i++) {
      for (int j = 0; j < h; j++) {
        ForceTile(x + i, y + j, kind);
      }
    }
  }

  void MarkStrip(int y, int x1, int x2, int dir, int kind) {
    for (int x = x1; x < x2; x++) {
      if (dir & (kDirEast | kDirWest) != 0) {
        MergeTile(x, y, kind | dir);
      } else {
        MergeTile(y, x, kind | dir);
      }
    }
  }

  Map<int, int> TileHistogram() {
    List<int> counters = new List<int>(256);
    for (int i = 0; i < counters.length; i++) counters[i] = 0;

    for (int i = 0; i < _w * _h; i++) {
      counters[FloorplanGetTileType(_tiles[i])]++;
    }
    Map<int, int> c = {};
    for (int i = 0; i < counters.length; i++) {
      if (counters[i] > 0) c[i] = counters[i];
    }
    return c;
  }
}

class Road {
  int _pos;
  int _width;
  int _divider;
  int _sidewalk;
  int _lanes;

  Road(this._pos, int dir1, int dir2, int width, WorldMap map) {
    _width = width;
    _divider = 0;
    if (width % 2 == 1) {
      width--;
      _divider = 1;
    }
    _sidewalk = max(2, (width - 10)) ~/ 2;
    width -= 2 * _sidewalk;
    _lanes = width ~/ 2;

    int x1 = kWorldBorder + 1;
    int x2 = map._w - kWorldBorder - 1;
    int y = _pos;
    int t = y;
    t += _sidewalk - 1;
    for (; y < t; y++) map.MarkStrip(y, x1, x2, dir1, kTileSidewalk);
    t += 1;
    for (; y < t; y++) map.MarkStrip(y, x1, x2, dir1, kTileSidewalkLight);
    t += _lanes;
    for (; y < t; y++) map.MarkStrip(y, x1, x2, dir1, kTileLane);
    t += _divider;
    for (; y < t; y++) map.MarkStrip(y, x1, x2, dir1, kTileDivider);
    t += _lanes;
    for (; y < t; y++) map.MarkStrip(y, x1, x2, dir2, kTileLane);
    t += 1;
    for (; y < t; y++) map.MarkStrip(y, x1, x2, dir2, kTileSidewalkLight);
    t += _sidewalk - 1;
    for (; y < t; y++) map.MarkStrip(y, x1, x2, dir2, kTileSidewalk);
  }

  String toString() {
    return "${_pos}: ${_width}";
  }
}

class Building {
  Rect plot;
  Rect base;
  int offset;
  double height;
  int kind;

  Building(this.plot, this.offset, this.height, this.kind, WorldMap map) {
    base = new Rect(plot.x + offset, plot.y + offset, plot.w - 2 * offset,
        plot.h - 2 * offset);
    if (map != null) {
      map.MarkPlot(plot, kTileBuildingBorder);
      map.MarkPlot(base, kind);
    }
  }
}

class PosInt {
  int x;
  int y;
  PosInt(this.x, this.y);

  PosInt.fromPosDouble(PosDouble p) {
    x = p.x.floor();
    y = p.y.floor();
  }

  PosInt.Clone(PosInt p) {
    x = p.x;
    y = p.y;
  }

  PosInt.CloneWithDir(PosInt p, int dir) {
    x = p.x;
    y = p.y;
    UpdatePos(dir, 1);
  }

  void UpdatePos(int dir, int dist) {
    switch (dir) {
      case kDirNorth:
        y -= dist;
        break;
      case kDirSouth:
        y += dist;
        break;
      case kDirEast:
        x += dist;
        break;
      case kDirWest:
        x -= dist;
        break;
    }
  }

  String toString() {
    return "($x, $y)";
  }

  bool operator ==(o) => o.x == x && o.y == y;

  int get hashCode => y * 16 * 1024 + x;
}

int ManhattanDiststance(PosInt a, PosInt b) {
  int dx = a.x - b.x;
  if (dx < 0) dx = -dx;
  int dy = a.y - b.y;
  if (dy < 0) dy = -dy;
  return max(dx, dy);
}

class PosDouble {
  double x;
  double y;

  PosDouble(this.x, this.y);

  PosDouble.fromClone(PosDouble p) {
    x = p.x;
    y = p.y;
  }

  PosDouble.fromPosInt(PosInt p) {
    x = p.x * 1.0;
    y = p.y * 1.0;
  }

  bool InSameCell(PosDouble p) {
    return x.floor() == p.x.floor() && y.floor() == p.y.floor();
  }

  void UpdatePos(int dir, double speed) {
    switch (dir) {
      case kDirNorth:
        y -= speed;
        break;
      case kDirSouth:
        y += speed;
        break;
      case kDirEast:
        x += speed;
        break;
      case kDirWest:
        x -= speed;
        break;
    }
  }
}

class Car {
  final int no;
  final bool _isCameraCar;
  PosDouble _pos;
  PosInt _posi;
  // square per msec
  double _max_speed;
  double _speed;
  PosInt _last_turni;
  int _dir_final;
  // int _dir_start;
  //int _tile_current;

  PosDouble Pos() {
    return _pos;
  }

  PosInt Posi() {
    return _posi;
  }

  String toString() {
    return "[$no] ";
  }

  void SetState(PosDouble p, PosInt pi, int tile, int dir_start, dir_final) {
    assert(tile & dir_final == dir_final);
    assert(tile & dir_start == dir_start);
    //_tile_current = tile;
    //_dir_start = dir_start;
    _dir_final = dir_final;
    _pos = p;
    _posi = pi;
    if (dir_start != dir_final) {
      _last_turni = pi;
    }
  }

  Car(this.no, Random rng, WorldMap map, bool this._isCameraCar) {
    _max_speed = (8 + rng.nextInt(3)) / 1000;
    _speed = 0.6 * _max_speed;
    if (_isCameraCar) {
      _max_speed = 8 / 1000;
      _speed = _max_speed;
    }
    final int dim = map._w;
    final PosInt center = new PosInt(dim ~/ 2, dim ~/ 2);
    while (true) {
      PosInt pi = new PosInt(map._w ~/ 4 + rng.nextInt(map._w ~/ 2),
          map._w ~/ 4 + rng.nextInt(map._w ~/ 2));
      if (_isCameraCar && ManhattanDiststance(center, pi) > dim ~/ 4) {
        continue;
      }
      int tile = map.GetTilePos(pi);
      if (FloorplanGetTileType(tile) != kTileLane) continue;
      int dir = FloorplanGetTileDir(tile);
      if (!OnlyOneBitSet(dir)) continue;
      if (map.HasCarPos(pi)) continue;
      SetState(new PosDouble.fromPosInt(pi), pi, tile, dir, dir);
      if (_isCameraCar) {
        // allow turns right away
        _last_turni = new PosInt(0, 0);
      } else {
        _last_turni = pi;
      }
      if (!_isCameraCar) {
        map.SetCarPos(pi, this);
      }
      break;
    }
  }

  double Dir() {
    switch (_dir_final) {
      case kDirNorth:
        return 0.0;
      case kDirWest:
        return 90.0;
      case kDirSouth:
        return 180.0;
      case kDirEast:
        return 270.0;
      default:
        assert(false);
        return 0.0;
    }
  }

  bool _ShouldTurn(
      Random rng, WorldMap map, int old_dir, int other_dir, PosInt pi) {
    // we turned recently
    if (ManhattanDiststance(_last_turni, _posi) < kMinRoadDistance * 5) {
      return false;
    }
    // hack
    final int dim = map._w;
    final PosInt center = new PosInt(dim ~/ 2, dim ~/ 2);
    if (_isCameraCar) {
      if (ManhattanDiststance(center, pi) > dim ~/ 5) {
        PosInt next = new PosInt.CloneWithDir(pi, old_dir);
        PosInt next_other = new PosInt.CloneWithDir(pi, other_dir);
        if (ManhattanDiststance(center, next) >
            ManhattanDiststance(center, next_other)) {
          return true;
        }
      }
    }

    return rng.nextInt(12) == 0;
  }

  void UpdateTileAndDir(
      Random rng, int old_dir, PosDouble p, PosInt pi, WorldMap map) {
    int tile = map.GetTilePos(pi);
    // Note there can only be two possible dirs at most and one of them as to be
    //old_dir
    int possible_dirs = FloorplanGetTileDir(tile);
    assert(old_dir & possible_dirs == old_dir);

    // Check if we must continue in the old dir
    if (possible_dirs == old_dir) {
      SetState(p, pi, tile, old_dir, old_dir);
      return;
    }
    int other_dir = possible_dirs & ~old_dir;
    assert(OnlyOneBitSet(other_dir));
    // We cannot switch dirs if we cannot continue on with the new dir
    PosInt pi_next1 = new PosInt.CloneWithDir(pi, other_dir);
    int tile_next1 = map.GetTilePos(pi_next1);
    if (FloorplanGetTileType(tile_next1) != kTileLane) {
      SetState(p, pi, tile, old_dir, old_dir);
      return;
    }

    // We must switch dirs if we cannot continue with the old dir
    PosInt pi_next2 = new PosInt.CloneWithDir(pi, old_dir);
    int tile_next2 = map.GetTilePos(pi_next2);
    if (FloorplanGetTileType(tile_next2) != kTileLane) {
      if (_isCameraCar) {
        int d = ManhattanDiststance(_last_turni, pi);
        log.LogInfo(
            "opt switch dir ${pi} [delta ${d}] ${old_dir} ${other_dir}");
      }
      SetState(p, pi, tile, old_dir, other_dir);
      return;
    }
    // We do not want to turn too frequently
    if (!_ShouldTurn(rng, map, old_dir, other_dir, pi)) {
      SetState(p, pi, tile, old_dir, old_dir);
      return;
    }

    if (_isCameraCar) {
      int d = ManhattanDiststance(_last_turni, pi);
      log.LogDebug("switch dir ${pi} [delta ${d}] ${old_dir} ${other_dir}");
    }
    SetState(p, pi, tile, old_dir, other_dir);
  }

  void _UpdateSpeed(double msecs, WorldMap map) {
    if (_isCameraCar) {
      return;
    }

    final double accel = 0.005 * _max_speed * msecs;
    if (_speed < 0.0) {
      _speed = _max_speed * 0.25;
      return;
    }
    final PosInt next = new PosInt.Clone(_posi)..UpdatePos(_dir_final, 1);
    final Car car = map.GetCarAtPos(next);
    if (car != null) {
      if (car._dir_final == _dir_final) {
        _speed = car._speed;
      } else {
        _speed *= 0.4;
      }
      return;
    }
    final PosInt nextnext = new PosInt.Clone(_posi)..UpdatePos(_dir_final, 2);
    final Car carcar = map.GetCarAtPos(nextnext);
    if (carcar != null && carcar._dir_final == _dir_final) {
      _speed = (_speed + carcar._speed) / 2.0;
      return;
    }

    _speed += accel;
    if (_speed > _max_speed) _speed = _max_speed;
  }

  void _UpdatePos(Random rng, double msecs, WorldMap map) {
    _UpdateSpeed(msecs, map);
    final double distance = min(_speed * msecs, kMaxCarMovement);
    if (distance < 0.0) return;
    final PosDouble pos = new PosDouble.fromClone(_pos)
      ..UpdatePos(_dir_final, distance);
    final PosInt posi = new PosInt.fromPosDouble(pos);
    if (pos.InSameCell(_pos)) {
      // gradually center car on lane
      switch (_dir_final) {
        case kDirNorth:
        case kDirSouth:
          pos.x = (pos.x + posi.x) / 2.0;
          break;
        case kDirWest:
        case kDirEast:
          pos.y = (pos.y + posi.y) / 2.0;
          break;
      }
      _pos = pos;
      return;
    }

    // We would moved to a new cell
    if (!_isCameraCar) {
      if (map.HasCarPos(posi)) {
        _speed = 0.0;
        return;
      }

      // We need to advance to a new cell
      map.SetCarPos(_posi, null);
      map.SetCarPos(posi, this);
    }
    UpdateTileAndDir(rng, _dir_final, pos, posi, map);
  }
}

class Floorplan {
  List<Building> _buildings = [];
  List<Road> _roads = [];
  List<Car> _cars = [];
  WorldConfig _wc;
  WorldMap _map;

  Floorplan(this._wc, Random rng) {
    log.LogInfo("Creating world");
    _map = new WorldMap(_wc.Dimension(), _wc.Dimension());
    log.LogInfo("Creating Roads");
    InitRoads(rng, kDirSouth, kDirNorth);
    InitRoads(rng, kDirWest, kDirEast);
    log.LogInfo("Creating Skyscrapers");
    InitSkyscrapers(rng, _wc.NumSkyscapers());
    log.LogInfo("Creating Regular Buildings");
    InitBuildings(rng);
    InitCars(rng, _wc.NumCars());
    log.LogInfo(
        "World has ${_buildings.length} buildings, ${_roads.length} roads");
  }

  get world_map => _map;

  List<Car> GetCars() {
    return _cars;
  }

  List<Rect> GetTileStrips(int kind) {
    final int dim = _wc.Dimension();
    List<Rect> out = [];
    for (int x = 0; x < dim; x++) {
      int count = 0;
      for (int y = 0; y <= dim; y++) {
        final int tile =
            (y < dim) ? FloorplanGetTileType(_map.GetTile(x, y)) : kind + 1;
        if (tile == kind) {
          count++;
        } else {
          if (count > 1) {
            out.add(new Rect(x * 1.0, (y - count) * 1.0, 1.0, count * 1.0));
          }
          count = 0;
        }
      }
    }
    for (int y = 0; y < dim; y++) {
      int count = 0;
      for (int x = 0; x <= dim; x++) {
        final int tile =
            (x < dim) ? FloorplanGetTileType(_map.GetTile(x, y)) : kind + 1;
        if (tile == kind) {
          count++;
        } else {
          if (count > 1) {
            out.add(new Rect((x - count) * 1.0, y * 1.0, count * 1.0, 1.0));
          }
          count = 0;
        }
      }
    }

    return out;
  }

  List<Building> GetBuildings() {
    return _buildings;
  }

  void InitRoads(Random rng, int dir1, int dir2) {
    int outerW = 11;
    _roads.add(new Road(kWorldBorder, dir1, dir2, outerW, _map));
    _roads.add(new Road(
        _wc.Dimension() - kWorldBorder - outerW, dir1, dir2, outerW, _map));
    for (int x = kWorldBorder + kMinRoadDistance;
        x < _wc.Dimension() - kWorldBorder - kMinRoadDistance - outerW ~/ 2;
        x += kMinRoadDistance + rng.nextInt(kMinRoadDistance)) {
      int width = 6 + rng.nextInt(6);
      _roads.add(new Road(x, dir1, dir2, width, _map));
    }
  }

  void InitSkyscrapers(Random rng, int n) {
    int numTower = 0;
    int numBlocky = 0;
    int numModern = 0;
    double height = 45.0 + rng.nextInt(10);
    while (n > 0) {
      int x = rng.nextInt(_wc.Dimension());
      int y = rng.nextInt(_wc.Dimension());
      if (!_map.IsEmpty(x, y)) continue;
      Rect plot = _map.MaxEmptyPlotContaining(x, y);
      if (!_wc.IsWithinCenter(plot)) continue;

      if (plot.w < 15 || plot.h < 15) continue;
      while (plot.w * plot.h > 800) {
        if (plot.w > plot.h) {
          double half = (plot.w / 2).floor() * 1.0;
          if (rng.nextBool()) {
            plot.x += plot.w - half;
          }
          plot.w = half;
        } else {
          double half = (plot.h / 2).floor() * 1.0;
          if (rng.nextBool()) {
            plot.y += plot.h - half;
          }
          plot.h = half;
        }
      }
      assert(plot.h >= 10);
      assert(plot.w >= 10);
      int kind = 0;
      // For Skyscrapers we want a base whose sides are multiples of two.
      plot.w = 2.0 * (plot.w / 2.0).floor();
      plot.h = 2.0 * (plot.h / 2.0).floor();
      if ((plot.w - plot.h).abs() < 10 && plot.w + plot.h > 35) {
        numModern++;
        kind = kTileBuildingModern;
      } else if (numModern <= numBlocky && numModern <= numTower) {
        numModern++;
        kind = kTileBuildingModern;
      } else if (numBlocky <= numModern && numBlocky <= numTower) {
        numBlocky++;
        kind = kTileBuildingBlocky;
      } else if (numTower <= numBlocky && numTower <= numModern) {
        numTower++;
        kind = kTileBuildingTower;
      }
      _buildings.add(new Building(plot, 1, height, kind, _map));
      n--;
    }
  }

  // Fill rest of m
  void InitBuildings(Random rng) {
    final int dim = _wc.Dimension();
    Rect plot = new Rect(0.0, 0.0, 0.0, 0.0);
    for (int x = 0; x < dim - kMinBuildingSize; x++) {
      for (int y = 0; y < dim - kMinBuildingSize; y++) {
        if (!_map.IsEmpty(x, y)) continue;
        int w = kMinBuildingSize + rng.nextInt(20);
        int h = kMinBuildingSize + rng.nextInt(20);
        int m = min(w, h);

        if (x + w > dim) w = dim - x;
        if (y + h > dim) h = dim - y;

        for (int yy = y; yy < y + h; yy++) {
          if (_map.IsEmpty(x, yy)) continue;
          int delta = y + h - yy;
          if (delta > 0) {
            h -= delta;
            w -= delta;
          }
        }

        if (w < 9) continue;
        if (h < 9) continue;

        for (int xx = x; xx < x + w; xx++) {
          if (_map.IsEmpty(xx, y)) continue;
          int delta = x + w - xx;
          if (delta > 0) {
            h -= delta;
            w -= delta;
          }
        }
        if (w < 9) continue;
        if (h < 9) continue;

        double altitude;
        int offset = 1;
        int kind;
        plot.x = x * 1.0;
        plot.y = y * 1.0;
        plot.w = w * 1.0;
        plot.h = h * 1.0;
        if (_wc.IsWithinCenter(plot)) {
          altitude = 15.0 + rng.nextInt(15);

          kind = rng.nextBool() ? kTileBuildingTower : kTileBuildingBlocky;
        } else if (_wc.IsAtBorder(plot)) {
          altitude = (m).floor() * 1.0 + rng.nextInt(5);
          kind = kTileBuildingSimple;
        } else {
          altitude = (m / 2).floor() * 1.0 + rng.nextInt(5);
          kind = kTileBuildingSimple;
        }

        _buildings.add(new Building(plot, offset, altitude, kind, _map));
      }
    }
  }

  void InitCars(Random rng, int n) {
    for (int i = 0; i < n; i++) {
      // The first car is allowed to break rules as it is used to guide the camera
      _cars.add(new Car(i, rng, _map, i == 0));
    }
  }

  void UpdateCars(Random rng, double msecs) {
    for (Car car in _cars) {
      car._UpdatePos(rng, msecs, _map);
    }
  }

  String toString() {
    return "Floorplan buildings[${_buildings.length}]";
  }
}
