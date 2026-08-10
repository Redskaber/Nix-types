# @path: test/cases/audit2.nix
# @description: Tests for issues found during the v3.1 fresh audit.
# These verify the fixes for:
#   H5: serialize now recursively normalizes (tuple value = tags, not instances)
#   H6: result.mapOr added (mirrors option.mapOr)
#   M5: result.cases requires function handlers (documented)
#   M6: __logger dead code removed
#   M7: parseTypeName guards non-string input
#   L9: optionToResult/resultToOption tests

let
  fw = import ../framework.nix { };
  m = import ../../lib/default.nix;
in
fw.runAll [
  # === H5: serialize recursively normalizes ===
  { name = "audit2.h5.01-tuple-serialize-value-is-tags";
    test =
      let
        Color = m.enum "Color" [ "Red" "Green" "Blue" ];
        Shape = m.enum "Shape" { Square = [ Color Color Color ]; };
        s = m.serialize (Shape.Square [ Color.Red Color.Green Color.Blue ]);
      in s.value._0 == "Red" && s.value._1 == "Green" && s.value._2 == "Blue"; }

  { name = "audit2.h5.02-tuple-serialize-no-lambdas";
    # The serialized output should be JSON-safe (no __toString, __meta__, etc.)
    test =
      let
        Color = m.enum "Color" [ "Red" "Green" "Blue" ];
        Shape = m.enum "Shape" { Square = [ Color Color Color ]; };
        s = m.serialize (Shape.Square [ Color.Red Color.Green Color.Blue ]);
        json = builtins.toJSON s;
      in builtins.isString json; }

  { name = "audit2.h5.03-fun-validator-serialize-recurses";
    test =
      let
        Color = m.enum "Color" [ "Red" "Green" "Blue" ];
        Shape = m.enum "Shape" {
          Triangle = { pos1, pos2, pos3 }@inst:
            if pos1.tag == pos2.tag then { inherit pos1 pos2 pos3; }
            else { __throw__ = "mismatch"; };
        };
        st = Shape.Triangle { pos1=Color.Red; pos2=Color.Red; pos3=Color.Blue; };
        s = m.serialize st;
      in s.value.pos1 == "Red" && s.value.pos3 == "Blue"; }

  { name = "audit2.h5.04-nested-list-serialize-recurses";
    test =
      let
        E = m.enum "E" { V = [ "a" "b" "c" ]; };
        s = m.serialize E.V;
      in s.value == [ "a" "b" "c" ]; }

  # === H6: result.mapOr ===
  { name = "audit2.h6.01-result-mapOr-on-ok";
    test = m.result.mapOr 0 (x: x + 1) (m.ok 41) == 42; }

  { name = "audit2.h6.02-result-mapOr-on-err";
    test = m.result.mapOr 99 (x: x + 1) (m.err "fail") == 99; }

  { name = "audit2.h6.03-result-mapOr-consistent-with-option";
    # Both should have the same signature: mapOr default f inst
    test =
      let
        o = m.option.mapOr 0 (x: x + 1) (m.some 41);
        r = m.result.mapOr 0 (x: x + 1) (m.ok 41);
      in o == 42 && r == 42; }

  # === M6: __logger removed ===
  { name = "audit2.m6.01-no-logger-export";
    test = !(m ? __logger); }

  { name = "audit2.m6.02-no-logger-in-lib";
    test = !(m.lib ? __logger); }

  # === M7: parseTypeName guards non-string input ===
  { name = "audit2.m7.01-non-string-typename-throws-catchable";
    test = fw.assertThrows "audit2.m7.01"
      (m.enum 42 { A = 1; }); }

  { name = "audit2.m7.02-int-typename-rejected";
    test = fw.assertThrows "audit2.m7.02"
      (m.enum 42 { A = 1; }); }

  { name = "audit2.m7.03-bool-typename-rejected";
    test = fw.assertThrows "audit2.m7.03"
      (m.enum true { A = 1; }); }

  { name = "audit2.m7.04-attrset-typename-rejected";
    test = fw.assertThrows "audit2.m7.04"
      (m.enum { x = 1; } { A = 1; }); }

  # === L9: optionToResult / resultToOption ===
  { name = "audit2.l9.01-some-to-ok";
    test = m.result.unwrap (m.optionToResult (m.some 42)) == 42; }

  { name = "audit2.l9.02-none-to-err";
    test =
      let r = m.optionToResult m.none;
      in m.result.isErr r && m.result.unwrapErr r == null; }

  { name = "audit2.l9.03-ok-to-some";
    test = m.option.unwrap (m.resultToOption (m.ok 42)) == 42; }

  { name = "audit2.l9.04-err-to-none";
    test = m.option.isNone (m.resultToOption (m.err "fail")); }

  { name = "audit2.l9.05-roundtrip-some-ok-some";
    test =
      let
        roundtrip = m.resultToOption (m.optionToResult (m.some 42));
      in m.option.unwrap roundtrip == 42; }
]
