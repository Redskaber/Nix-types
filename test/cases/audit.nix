# @path: test/cases/audit.nix
# @description: Tests for issues found during the v3.0 deep audit.
# These verify the fixes for:
#   H1: tuple instance._0 direct access (dead code removed)
#   H2: option.unwrapOrElse now calls f
#   H3: tuple-position function validators route through validateFunRst
#   H4: function validator's returned attrset enriches the instance
#   L8: empty attrset variants rejected

let
  fw = import ../framework.nix { };
  m = import ../../lib/default.nix;
in
fw.runAll [
  # === H1: tuple instance.value._0 works (instance._0 direct access not provided) ===
  { name = "audit.h1.01-tuple-value-_0-works";
    test =
      let
        Color = m.enum "Color" [ "Red" "Green" "Blue" ];
        Shape = m.enum "Shape" { Square = [ Color Color Color ]; };
        ss = Shape.Square [ Color.Red Color.Green Color.Blue ];
      in ss.value._0.tag == "Red"; }

  { name = "audit.h1.02-tuple-instance-does-not-have-_0-directly";
    # instance._0 is NOT provided (the broken spread was removed).
    # Only instance.value._0 works.
    test =
      let
        Color = m.enum "Color" [ "Red" "Green" "Blue" ];
        Shape = m.enum "Shape" { Square = [ Color Color Color ]; };
        ss = Shape.Square [ Color.Red Color.Green Color.Blue ];
      in !(ss ? _0); }

  # === H2: option.unwrapOrElse calls f ===
  { name = "audit.h2.01-unwrapOrElse-calls-f-on-none";
    test =
      m.option.unwrapOrElse (_: 99) m.none == 99; }

  { name = "audit.h2.02-unwrapOrElse-returns-value-on-some";
    test =
      m.option.unwrapOrElse (_: 99) (m.some 42) == 42; }

  { name = "audit.h2.03-unwrapOrElse-f-receives-null";
    # The function f receives null (since None has no value).
    test =
      m.option.unwrapOrElse (x: x) m.none == null; }

  # === H3: tuple-position function validators route through validateFunRst ===
  { name = "audit.h3.01-tuple-fn-validator-throws-on-throw-attr";
    # A function validator inside a tuple position that returns
    # { __throw__ = "..." } should throw.
    test =
      let
        Color = m.enum "Color" [ "Red" "Green" "Blue" ];
        E = m.enum "E" {
          Tuple = [ Color (_: { __throw__ = "nested fail"; }) Color ];
        };
      in fw.assertThrows "audit.h3.01"
        (E.Tuple [ Color.Red Color.Green Color.Blue ]); }

  { name = "audit.h3.02-tuple-fn-validator-passes-on-true";
    test =
      let
        Color = m.enum "Color" [ "Red" "Green" "Blue" ];
        E = m.enum "E" {
          Tuple = [ Color (_: true) Color ];
        };
      in (E.Tuple [ Color.Red Color.Green Color.Blue ]).tag == "Tuple"; }

  { name = "audit.h3.03-tuple-fn-validator-passes-on-attrset";
    # A function validator returning an attrset passes validation.
    # Note: the returned attrset does NOT enrich the tuple position's value
    # (the original input is kept). This is a known limitation of the tuple
    # path — enrichment only works for top-level function validators (H4).
    test =
      let
        Color = m.enum "Color" [ "Red" "Green" "Blue" ];
        E = m.enum "E" {
          Tuple = [ Color ({ x }: { checked = true; }) Color ];
        };
        inst = E.Tuple [ Color.Red { x = 1; } Color.Blue ];
      in inst.value._1.x == 1; }

  # === H4: function validator's returned attrset enriches the instance ===
  { name = "audit.h4.01-fun-validator-attrset-enriches-value";
    # When a function validator returns an attrset, that attrset becomes
    # the instance's value (not the original input).
    test =
      let
        E = m.enum "E" {
          V = { a, b }@inst: { sum = a + b; product = a * b; };
        };
        inst = E.V { a = 3; b = 4; };
      in inst.value.sum == 7 && inst.value.product == 12; }

  { name = "audit.h4.02-fun-validator-true-keeps-original";
    # When a function validator returns true, the original input is kept.
    test =
      let
        E = m.enum "E" {
          V = _: true;
        };
        inst = E.V { x = 42; };
      in inst.value.x == 42; }

  { name = "audit.h4.03-fun-validator-enriched-display";
    # The display string reflects the enriched value.
    test =
      let
        Color = m.enum "Color" [ "Red" "Green" "Blue" ];
        Shape = m.enum "Shape" {
          Triangle = { pos1, pos2, pos3 }@inst:
            if pos1.tag == pos2.tag then { inherit pos1 pos2 pos3; }
            else { __throw__ = "mismatch"; };
        };
        st = Shape.Triangle { pos1=Color.Red; pos2=Color.Red; pos3=Color.Blue; };
      in st.value.pos1.tag == "Red" && st.value.pos3.tag == "Blue"; }

  # === L8: empty attrset variants rejected ===
  { name = "audit.l8.01-empty-attrset-variants-rejected";
    test = fw.assertThrows "audit.l8.01"
      (m.enum "E" { }); }

  { name = "audit.l8.02-empty-list-variants-allowed";
    # Empty list is allowed (unit enum with no variants).
    test = (m.enum "E" [ ]) ? __meta__; }

  # === Framework correctness verification ===
  { name = "audit.framework.01-false-test-fails";
    # Verify the framework now correctly catches false results.
    test =
      let fw2 = import ../framework.nix {};
      in !(fw2.run "should-fail" (1 == 2)).ok; }

  { name = "audit.framework.02-true-test-passes";
    test =
      let fw2 = import ../framework.nix {};
      in (fw2.run "should-pass" (1 == 1)).ok; }

  { name = "audit.framework.03-throw-test-fails";
    test =
      let fw2 = import ../framework.nix {};
      in !(fw2.run "should-fail" (throw "x")).ok; }
]
