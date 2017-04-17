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

import 'dart:html' as HTML;
import 'dart:math';

import 'sky.dart';
import 'floor_plan.dart';

import 'logging.dart';
import 'renderer.dart';
import 'rgb.dart';
import 'geometry.dart';
import 'facade.dart';


final HTML.SelectElement gSelect =
    HTML.document.querySelector('#myselect') as HTML.SelectElement;
final HTML.Element gContainer = HTML.document.getElementById("test");
final HTML.HeadingElement gTitle = HTML.document.getElementById("title");

final Random gRng = new Random(0);
final WorldConfig wc = new WorldConfig(400);
final Floorplan gFloorplan = new Floorplan(wc, gRng);

final int cellW = 2;
final int cellH = 2;

HTML.CanvasElement Sky(Random rng) {
  double hue = 0.5 + 0.2 * rng.nextDouble();
  double sat = 0.1 + 0.8 * rng.nextDouble();
  RGB horizon = new RGB.fromHSL(hue, sat, 0.5);
  RGB clouds = new RGB.fromHSL(hue, 0.15, 0.1);
  return MakeCanvasSky(rng, 2048, 1024, kRGBblack, horizon, clouds);
}

HTML.CanvasElement World(Random rng) {
  HTML.CanvasElement canvas = gFloorplan.world_map.RenderToCanvas(cellW, cellH);
  List<Rect> lights = gFloorplan.GetTileStrips(kTileSidewalkLight);
  LogInfo("found ${lights.length} light strips");
  HTML.CanvasRenderingContext2D c = canvas.context2D;
  for (Rect r in lights) {
    c
      ..fillStyle = "black"
      ..fillRect(r.x * cellW, r.y * cellH, r.w * cellW, r.h * cellH);
  }
  return canvas;
}

void UpdateCars(HTML.CanvasElement canvas, double msecs) {
  HTML.CanvasRenderingContext2D c = canvas.context2D;
  for (Car car in gFloorplan.GetCars()) {
    PosDouble pos = car.Pos();
    c
      ..fillStyle = "gray"
      ..fillRect(pos.x.floor() * cellW, pos.y.floor() * cellH, cellW, cellH);
  }
  gFloorplan.UpdateCars(gRng, msecs);

  for (Car car in gFloorplan.GetCars()) {
    PosInt pos = car.Posi();
    c
      ..fillStyle = "black"
      ..fillRect(pos.x * cellW, pos.y * cellH, cellW, cellH);
  }
}

RGB MyWhite = new RGB.fromGray(255)..a = 0.99;
double skyHue = 0.5;
double skySat = 0.5;
RGB black = new RGB.fromGray(0);
RGB horizon = new RGB.fromHSL(skyHue, skySat, 0.2);
RGB clouds = new RGB.fromHSL(skyHue, 0.15, 0.1);

HTML.CanvasElement MakeTestCanvas(double now) {
  now = 0.0;
  int d = 512;
  var canvas = new HTML.CanvasElement();
  canvas.width = d;
  canvas.height = d;

  double ca = now / (400 * 20.0);
  double cx = 100 * sin(ca);
  double cz = 100 * cos(ca);
  double ta = ca + PI;
  double tx = 100 * sin(ta);
  double tz = 100 * cos(ta);

  HTML.CanvasRenderingContext2D c = canvas.context2D;
  c
    ..fillStyle = "white"
    ..fillRect(0, 0, d, d)
    ..fillStyle = "black"
    ..fillStyle = "blue"
    ..fillRect(d / 2 - 10, d / 2 - 10, 20, 20)
    ..fillStyle = "black"
    ..beginPath()
    ..moveTo(cx + d / 2, cz + d / 2)
    ..lineTo(tx + d / 2, tz + d / 2)
    ..stroke();
  return canvas;
}

bool dayLight = true;

final Map<String, HTML.CanvasElement> gCanvases = {
  "HeadLights": MakeCanvasHeadLights(),
  "PointLights": MakeCanvasPointLight(20, kRGBwhite, kRGBtransparent),
  "Sky": MakeCanvasSky(gRng, 2048, 1024, black, horizon, clouds),
  "RadioTower": MakeRadioTowerTexture(),
  "Facade1": MakeCanvasFacade(gRng, kRGBblack, DrawFacadeWindowMiniGap, dayLight),
  "Facade2": MakeCanvasFacade(gRng, kRGBblack, DrawFacadeWindowLongSleek, dayLight),
  "Facade3": MakeCanvasFacade(gRng, kRGBblack, DrawFacadeWindowSideBySide, dayLight),
  "Facade4": MakeCanvasFacade(gRng, kRGBblack, DrawFacadeWindowBlinds, dayLight),
  "Facade5": MakeCanvasFacade(gRng, kRGBblack, DrawFacadeWindowVerticalStripes, dayLight),
  "Facade6": MakeCanvasFacade(gRng, kRGBblack, DrawFacadeWindowNotFloorToCeiling, dayLight),
  "Facade7": MakeCanvasFacade(gRng, kRGBblack, DrawFacadeWindowFourPane, dayLight),
  "Facade8": MakeCanvasFacade(gRng, kRGBblack, DrawFacadeWindowNarrowNotFloorToCeiling,dayLight),
  "Facade9": MakeCanvasFacade(gRng, kRGBblack, DrawFacadeWindowCenteredNarrow, dayLight),
  // "World": World(rng),
//MakeCanvasLightTrim(),
  "StreetLight": MakeCanvasStreetLight(32, MyWhite, kRGBred),
  "LightPattern": MakeLightColorPattern(),
//MakeCanvasLightTrim(),
  "Orientation": MakeOrientationTestPattern(),
  "Logos":
      MakeCanvasBuildingLogos(GetBuildingLogos(gRng), kRGBwhite, kRGBblack),
  "Test": MakeTestCanvas(0.0),
  "Lanes": RenderCanvasWorldMap(gFloorplan.world_map, new RGB(0x40, 0x40, 0x40),
      new RGB(0x15, 0x16, 0x16)),
  "Map": RenderWorldMapToCanvas(gFloorplan.world_map, cellW, cellH),
};

String gCurrent = "Facade1";

double last = 0.0;

void animate(num now) {
  if (last == 0.0) {
    last = now.toDouble();
  }
  gCurrent = gSelect.options[gSelect.selectedIndex].value;
  last = now.toDouble();
  gContainer.children.clear();
  gContainer.children.add(gCanvases[gCurrent]);
  gTitle.setInnerHtml("<span>${gCurrent}</span>");
  // UpdateCars(gCanvas, delta);
  HTML.window.requestAnimationFrame(animate);
}

void main() {
  print("configure all options");
  gSelect.children.clear();
  for (String o in gCanvases.keys) {
    print("adding [$o]");
    gSelect.appendHtml("<option>$o</option>");
  }
  print("AFTER ${gSelect.children}");

  gSelect.onChange.listen((HTML.Event e) {});

  (HTML.document.querySelector("#prev") as HTML.ButtonElement)
      .onClick
      .listen((HTML.MouseEvent e) {
    print("prev: (before) ${gSelect.selectedIndex}");
    if (gSelect.selectedIndex == 0) {
      gSelect.selectedIndex = gSelect.length - 1;
    } else {
      gSelect.selectedIndex -= 1;
    }
    e.preventDefault();
  });

  (HTML.document.querySelector("#next") as HTML.ButtonElement)
      .onClick
      .listen((HTML.MouseEvent e) {
    print("next: (before) ${gSelect.selectedIndex}");
    gSelect.selectedIndex += 1;
    if (gSelect.selectedIndex == gSelect.length - 1) {
      gSelect.selectedIndex = 0;
    } else {
      gSelect.selectedIndex += 1;
    }

    e.preventDefault();
  });
  animate(0.0);
}
