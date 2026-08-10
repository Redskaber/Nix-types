# @path: test/cases/serialize.nix
# @description: Serialization tests.
# Uses standardized naming (no `fn-` prefix).
# Tests BOTH library-level `serialize` and enum-carried `Shape.serialize` (alias).

let
  fw = import ../framework.nix { };
  shared = import ./shared.nix;
  inherit (shared) Color Drive Position lib;

  LocalShape = shared.enum "Shape" {
    Circle   = Color;
    Square   = [ Color Color Color ];
    Triangle = { pos1, pos2, pos3 }@instance:
      if pos1.tag == pos2.tag then { inherit pos1 pos2 pos3; }
      else { __throw__ = "Triangle requires pos1 == pos2"; };
  };
in
fw.runAll [
  { name = "serialize.01-unit-instance-lib";
    test = (lib.serialize Color.Red) == {
      tag = "Red"; typename = "Color"; value = null;
    }; }
  { name = "serialize.02-unit-instance-alias";
    test = (Color.serialize Color.Red) == {
      tag = "Red"; typename = "Color"; value = null;
    }; }
  { name = "serialize.03-enum-typed-instance";
    # Single nested instance → value is the tag (string).
    test = (lib.serialize (LocalShape.Circle Color.Red)) == {
      tag = "Circle"; typename = "Shape"; value = "Red";
    }; }
  { name = "serialize.04-tuple-instance";
    # Tuple → value is an attrset of RECURSIVELY serialized values (tags).
    test =
      let
        s = lib.serialize (LocalShape.Square [ Color.Red Color.Green Color.Blue ]);
      in
      s.tag == "Square"
      && s.value._0 == "Red"
      && s.value._1 == "Green"
      && s.value._2 == "Blue"; }
  { name = "serialize.05-literal-instance";
    test = (lib.serialize Drive.intel).value == "intel"; }
  { name = "serialize.06-enum-instance-as-literal";
    test = (lib.serialize Drive.self).value == "Red"; }
  { name = "serialize.07-fun-validator-instance";
    # Function validator → value is the validator's returned attrset,
    # recursively serialized (nested instances become tags).
    test =
      let
        st = LocalShape.Triangle { pos1=Color.Red; pos2=Color.Red; pos3=Color.Blue; };
        s = lib.serialize st;
      in
      s.tag == "Triangle"
      && s.value.pos1 == "Red"
      && s.value.pos2 == "Red"
      && s.value.pos3 == "Blue"; }
  { name = "serialize.08-returns-flat-record";
    test =
      let s = lib.serialize Color.Red;
      in builtins.attrNames s == [ "tag" "typename" "value" ]; }
  { name = "serialize.09-multiple-instances-have-same-typename";
    test =
      let
        s1 = lib.serialize Color.Red;
        s2 = lib.serialize Color.Green;
        s3 = lib.serialize Color.Blue;
      in
      s1.typename == s2.typename && s2.typename == s3.typename; }
  { name = "serialize.10-position-instance";
    test = (lib.serialize Position.local).tag == "local"; }
  { name = "serialize.11-enum-instance-serialize-equals-tag";
    test = (lib.serialize (LocalShape.Circle Color.Red)).value
           == (LocalShape.Circle Color.Red).value.tag; }
  { name = "serialize.12-lib-and-alias-produce-same-result";
    test = lib.serialize (LocalShape.Circle Color.Red)
           == LocalShape.serialize (LocalShape.Circle Color.Red); }
  { name = "serialize.13-output-is-json-safe";
    # The serialized output should contain NO lambdas or internal markers.
    # `toJSON` should succeed and produce a string.
    test =
      let
        s = lib.serialize (LocalShape.Square [ Color.Red Color.Green Color.Blue ]);
        json = builtins.toJSON s;
      in builtins.isString json; }
  { name = "serialize.14-tuple-json-content";
    test =
      let
        s = lib.serialize (LocalShape.Square [ Color.Red Color.Green Color.Blue ]);
        json = builtins.toJSON s;
      in json == ''{"tag":"Square","typename":"Shape","value":{"_0":"Red","_1":"Green","_2":"Blue"}}''; }
]
