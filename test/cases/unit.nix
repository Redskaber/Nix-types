# @path: test/cases/unit.nix
# @description: Unit / tuple-less enum test cases.

let
  fw = import ../framework.nix { };
  shared = import ./shared.nix;
  inherit (shared) Color Singleton types lib;
in
fw.runAll [
  { name = "unit.01-create-and-tag";
    test = Color.Red.tag == "Red"; }
  { name = "unit.02-all-variants-have-correct-tag";
    test = Color.Red.tag == "Red" && Color.Green.tag == "Green" && Color.Blue.tag == "Blue"; }
  { name = "unit.03-display-format";
    test = Color.Red.display == "enum::Color::Red"; }
  { name = "unit.04-display-green";
    test = Color.Green.display == "enum::Color::Green"; }
  { name = "unit.05-unit-value-is-null-sentinel";
    test = Color.Red.value == null; }
  { name = "unit.06-meta-typename";
    test = Color.__meta__.typename == "Color"; }
  { name = "unit.07-variants-list-recorded";
    test = Color.__variants__ == [ "Red" "Green" "Blue" ]; }
  { name = "unit.08-each-variant-is-instance";
    test = builtins.all (v: types.isInst v) [ Color.Red Color.Green Color.Blue ]; }
  { name = "unit.09-instance-meta-equals-enum-meta";
    test = Color.Red.__meta__ == Color.__meta__; }
  { name = "unit.10-singleton-enum";
    test = Singleton.Only.tag == "Only"; }
  { name = "unit.11-singleton-variants-list";
    test = Singleton.__variants__ == [ "Only" ]; }
  { name = "unit.12-instance-attr-names-include-internal";
    test = builtins.all (k: builtins.hasAttr k Color.Red)
      [ "__enumInstance__" "__meta__" "tag" "value" "display" "__toString" ]; }
  { name = "unit.13-instance-marker-is-true";
    test = Color.Red.__enumInstance__ == true; }
  { name = "unit.14-enum-attr-names-include-public";
    test = builtins.all (k: builtins.hasAttr k Color)
      [ "__meta__" "__variants__" "match" "serialize" ]; }
  { name = "unit.15-enum-meta-is-record-with-typename";
    test = builtins.isAttrs Color.__meta__ && Color.__meta__ ? typename; }
  { name = "unit.16-color-is-enum-type";
    test = types.isEnum Color; }
  { name = "unit.17-color-red-is-instance";
    test = types.isInst Color.Red; }
  { name = "unit.18-color-red-belongs-to-color";
    test = types.isType Color.Red Color; }
  { name = "unit.19-library-level-match-works";
    test = lib.match Color.Red { Red = v: "r"; _ = v: "other"; } == "r"; }
  { name = "unit.20-enum-carried-match-is-alias";
    test = Color.match Color.Red { Red = v: "r"; _ = v: "other"; }
          == lib.match Color.Red { Red = v: "r"; _ = v: "other"; }; }
  { name = "unit.21-library-level-serialize-works";
    test = (lib.serialize Color.Red).tag == "Red"; }
  { name = "unit.22-enum-carried-serialize-is-alias";
    test = (Color.serialize Color.Red).tag
          == (lib.serialize Color.Red).tag; }
  { name = "unit.23-string-interpolation-via-toString";
    test = "${Color.Red}" == "enum::Color::Red"; }
]
