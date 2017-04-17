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


import 'dart:math' as Math;

import 'config.dart';
import 'building.dart';
import 'geometry.dart';
import 'floor_plan.dart';
import 'logging.dart';

import 'package:vector_math/vector_math.dart' as VM;

void main(List<String> args) {
  gLogLevel = 1;
  if (args.length == 0) {
    LogError("Not enough args: ${args}");
    return;
  }
  final int dimension = int.parse(args[0]);
  LogInfo("dimensions: ${dimension}");
  Math.Random rng = new Math.Random(1);

  WorldConfig wc = new WorldConfig(dimension);

  LogInfo("Create Floorplan");
  Floorplan floorplan = new Floorplan(wc, rng);
  LogInfo("${floorplan}");

  LogInfo("Errecting Buildings");
  List<FaceMat> walls = [];
  for (int i = 0; i < 10; i++) {
    walls.add(new FaceMat("wall $i"));
  }
  final BuildingParameters params = new BuildingParameters()
    ..wallMats = walls
    ..logoMat = new FaceMat("logo")
    ..lightTrimMat = new FaceMat("lightTrimM")
    ..pointLightMat = new FaceMat("pointLight")
    ..flashingLightMat = new FaceMat("lashingLight")
    ..radioTowerMat = new FaceMat("radioTower")
    ..wallColors = kBuildingColors
    ..ledgeColors = kLedgeColors
    ..baseColors = kBaseColors
    ..num_logos = kNumBuildingLogos
    ..solidMat = new FaceMat("solid");
  Shape shape = new Shape();
  int count = 0;
  for (Building b in floorplan.GetBuildings()) {
    if (count % 100 == 0) {
      LogInfo("initialize buidings ${count}");
    }
    count++;
    VM.Vector3 theColor = new VM.Vector3.zero();
    RoofOptions roofOpt = new RoofOptions(rng, params);
    AddOneBuilding(shape, rng, params, roofOpt, b, theColor, true);
  }
  LogInfo("Done");
}
