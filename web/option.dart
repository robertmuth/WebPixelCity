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
library option;

import 'dart:html';
import 'dart:core';
import 'logging.dart' as log;

class Option {
  final Element element;
  final String defaultValue;
  final String name;
  final String type;

  Option(this.name, this.type, this.defaultValue, this.element) {
    if (!window.localStorage.containsKey(name)) {
      Save(defaultValue);
    }
    log.LogInfo("Loading ${name}");
    String value = window.localStorage[name];
    SetCurrentFromString(value);
  }

  String GetCurrentAsString() {
    if (type == "B") {
      return (element as InputElement).checked.toString();
    } else if (type == "O") {
      return (element as SelectElement).value;
    } else {
      return (element as InputElement).value;
    }
  }

  double GetCurrentAsDouble() {
    return (element as InputElement).valueAsNumber * 1.0;
  }

  void SetCurrentFromString(String s) {
    if (type == "B") {
      (element as InputElement).checked = (s == "true");
    } else if (type == "O") {
      (element as SelectElement).value = s;
    } else {
      (element as InputElement).value = s;
    }
  }

  void Save(String s) {
    log.LogInfo("Saving ${name} ${s}");
    window.localStorage[name] = s;
  }
}

/*
 * Example: inputs
 * <input type="checkbox" id="hideAbout">
 * <input type="number" id="minAngle" min=0 value=88 max=180 step=.1>
 * <input type="text" id="grainColor" value="random" >
 * <input type="number" id="numGrains" min=0 value=64 max=1000 step=1>
 *
 * Corresponding to:
 *  AddOption("hideAbout", "B", "false");
 *  AddOption("minAngle", "D", "88.0");
 *  AddOption("grainColor", "S", "random");
 *  AddOption("numGrains", "I", "64");
 */
Map<String, String> _kOptionTypeMap = {
  "B": "checkbox",
  "I": "number",
  "D": "number",
  "O": "text",
  "S": "text",
};

class Options {
  final String _prefix;
  Map<String, Option> _o = new Map<String, Option>();
  Map<String, Map<String, String>> _settings =
      new Map<String, Map<String, String>>();

  String AddPrefix(String name) {
    return _prefix + ":" + name;
  }

  void AddOption(String name, String type, String defaultValue,
      [useFake = false]) {
    Element e = querySelector("#" + name);
    if (e == null && useFake) {
      e = new InputElement()..type = _kOptionTypeMap[type];
    }
    if (e == null) throw "Missing widget for options ${name}";
    _o[name] = new Option(AddPrefix(name), type, defaultValue, e);
  }

  Options(this._prefix);

  String Get(String name) {
    assert(_o.containsKey(name));
    return _o[name].GetCurrentAsString();
  }

  void _SanityCheck(String name, String type) {
    if (!_o.containsKey(name)) throw "unknown options ${name}";
    if (_o[name].type != type) throw "bad type ${type} for options ${name}";
  }

  bool GetBool(String name) {
    _SanityCheck(name, "B");
    return _o[name].GetCurrentAsString() == "true";
  }

  int GetInt(String name) {
    _SanityCheck(name, "I");
    final double d = _o[name].GetCurrentAsDouble();
    if (d.isNaN) return int.parse(_o[name].defaultValue);
    return d.floor();
  }

  double GetDouble(String name) {
    _SanityCheck(name, "D");
    final double d = _o[name].GetCurrentAsDouble();
    if (d.isNaN) return double.parse(_o[name].defaultValue);
    return d;
  }

  void SaveToLocalStorage() {
    _o.forEach((name, o) {
      //print ("###SAVE: ${name} [${o.GetCurrentAsString()}]");
      o.Save(o.GetCurrentAsString());
    });
  }

  void SetNewSettings(String name) {
    if (!_settings.containsKey(name)) {
      log.LogError("Unknown Setting ${name}");
      return;
    }
    _settings[name].forEach((name, s) {
      _o[name].Save(s);
      _o[name].SetCurrentFromString(s);
    });
    window.location.hash = "#" + name;
  }

  void Set(String name, String value) {
    assert(_o.containsKey(name));
    _o[name].Save(value);
    _o[name].SetCurrentFromString(value);
  }

  void AddSetting(String name, Map<String, String> s) {
    assert(!_settings.containsKey(name));
    s.forEach((k, v) {
      if (!_o.containsKey(k)) throw "missing setting ${k} in ${name}";
    });
    _settings[name] = s;
  }

  Iterable<String> SettingsNames() {
    return _settings.keys;
  }

  void ProcessUrlHash() {
    String hash = window.location.hash;
    if (hash == "") return;
    hash = hash.substring(1);
    List<String> pairs = hash.split("&");
    for (String p in pairs) {
      List<String> tv = p.split("=");
      if (tv.length == 1) {
        log.LogInfo("SetSetting ${tv[0]}");
        SetNewSettings(tv[0]);
      } else if (tv.length == 2) {
        Set(tv[0], tv[1]);
      }
    }
  }
}
