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

import 'logging.dart' as LOG;
import 'option.dart';
import 'dart:html' as HTML;

Options gOptions;

const String oWorldSize = "worldSize";
const String oMode = "mode";
const String oSkyColor = "skyColor";
const String oWireframeColor = "wireframeColor";
const String oCameraMode = "cameraMode";
const String oCameraHeight = "cameraHeight";
const String oCameraLevelChange = "cameraLevelChange";
const String oHideAbout = "hideAbout";
const String oShowCars = "showCars";
const String oShowSky = "showSky";
const String oShowBuildings = "showBuildings";
const String oRandomSeed = "randomSeed";
const String oLogLevel = "logLevel";
const String oFov = "fov";
const String oCull = "cull";
const String oLogo = "logo";
const String oFog = "fog";

const String kModeDay = "day";
const String kModeNight = "night";
const String kModeWireframe = "wireframe";
const String kModeShadow = "shadow";

void OptionsSetup() {
  gOptions = new Options("pixelcity")
    ..AddOption(oWorldSize, "O", "medium")
    ..AddOption(oMode, "O", "night")
    ..AddOption(oSkyColor, "S", "random")
    ..AddOption(oWireframeColor, "S", "random")
    ..AddOption(oCameraMode, "O", "orbitInner")
    ..AddOption(oCameraHeight, "D", "50")
    ..AddOption(oCameraLevelChange, "B", "false")
    ..AddOption(oRandomSeed, "I", "0")
    ..AddOption(oFov, "I", "75")
    ..AddOption(oLogo, "S", "")
    ..AddOption(oHideAbout, "B", "false", true)
    ..AddOption(oFog, "D", "3.0")
    // Only in debug mode
    ..AddOption(oLogLevel, "I", "0", true)
    ..AddOption(oShowCars, "B", "true", true)
    ..AddOption(oShowSky, "B", "true", true)
    ..AddOption(oCull, "B", "true", true)
    ..AddOption(oShowBuildings, "B", "true", true);

  gOptions.AddSetting("Standard", {
    oWorldSize: "medium",
    oMode: kModeNight,
    oSkyColor: "random",
    oCameraMode: "orbitOuter",
    oCameraHeight: "60",
    oCameraLevelChange: "false",
    oRandomSeed: "0",
    oFov: "40",
    oFog: "3.0",
    oShowSky: "true",
  });

  gOptions.AddSetting("InnerPurple", {
    oWorldSize: "medium",
    oMode: kModeNight,
    oSkyColor: "#ff00ff",
    oCameraMode: "orbitInner",
    oCameraHeight: "60",
    oCameraLevelChange: "false",
    oRandomSeed: "0",
    oFov: "40",
    oShowSky: "true",
  });

  gOptions.AddSetting("OuterHigh", {
    oWorldSize: "medium",
    oMode: kModeNight,
    oSkyColor: "random",
    oCameraMode: "orbitOuter",
    oCameraHeight: "100",
    oCameraLevelChange: "false",
    oRandomSeed: "0",
    oFov: "40",
    oShowSky: "true",
  });

  gOptions.AddSetting("Outer", {
    oWorldSize: "medium",
    oMode: kModeNight,
    oSkyColor: "random",
    oCameraMode: "orbitOuter",
    oCameraHeight: "70",
    oCameraLevelChange: "false",
    oRandomSeed: "0",
    oFov: "40",
    oShowSky: "true",
  });

  gOptions.AddSetting("RotateRed", {
    oWorldSize: "medium",
    oMode: kModeNight,
    oSkyColor: "red",
    oCameraMode: "rotateNear",
    oCameraHeight: "40",
    oCameraLevelChange: "false",
    oRandomSeed: "0",
    oFov: "40",
    oShowSky: "true",
  });

  gOptions.AddSetting("BackwardYellow", {
    oWorldSize: "medium",
    oMode: kModeNight,
    oSkyColor: "yellow",
    oCameraMode: "carBack",
    oCameraHeight: "40",
    oCameraLevelChange: "false",
    oRandomSeed: "0",
    oFov: "40",
    oShowSky: "true",
  });

  gOptions.AddSetting("ForwardGreen", {
    oWorldSize: "medium",
    oMode: kModeNight,
    oSkyColor: "#00ff00",
    oCameraMode: "carFront",
    oCameraHeight: "60",
    oCameraLevelChange: "false",
    oRandomSeed: "0",
    oFov: "40",
    oShowSky: "true",
  });

  gOptions.AddSetting("SmallerCity", {
    oWorldSize: "small",
    oMode: kModeNight,
    oSkyColor: "random",
    oCameraMode: "orbitOuter",
    oCameraHeight: "50",
    oCameraLevelChange: "false",
    oRandomSeed: "0",
    oFov: "40",
    oShowSky: "true",
  });

  gOptions.AddSetting("WireFrameBlue", {
    oWorldSize: "medium",
    oMode: kModeWireframe,
    oSkyColor: "#000000",
    oWireframeColor: "blue",
    oCameraMode: "orbitOuter",
    oCameraHeight: "280",
    oCameraLevelChange: "false",
    oRandomSeed: "0",
    oFov: "30",
    oShowSky: "false",
  });

  gOptions.AddSetting("WireFrameRed", {
    oWorldSize: "medium",
    oMode: kModeWireframe,
    oSkyColor: "#000000",
    oWireframeColor: "#FF6347",
    oCameraMode: "orbitOuter",
    oCameraHeight: "280",
    oCameraLevelChange: "false",
    oRandomSeed: "0",
    oFov: "30",
    oShowSky: "false",
  });

  gOptions.AddSetting("DayLight", {
    oWorldSize: "medium",
    oMode: kModeDay,
    oCameraMode: "orbitOuter",
    oCameraHeight: "120",
    oCameraLevelChange: "false",
    oRandomSeed: "0",
    oShowSky: "false",
  });

  gOptions.ProcessUrlHash();

  LOG.gLogLevel = gOptions.GetInt(oLogLevel);

  HTML.SelectElement presets = HTML.querySelector("#preset");
  for (String name in gOptions.SettingsNames()) {
    HTML.OptionElement o = new HTML.OptionElement(data: name, value: name);
    presets.append(o);
  }
}
