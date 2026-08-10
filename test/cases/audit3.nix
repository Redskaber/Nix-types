# @path: test/cases/audit3.nix
# @description: Tests for issues found during the v3.2 final audit.
# These verify the fixes for:
#   H7: match with non-instance elements → catchable throw
#   H8: serialize on non-instance → catchable throw
#   H9: option.cases/result.cases with missing handler keys → catchable throw
#   M8: isType distinguishes enums with different variant sets
#   M9: __PORDER__ with duplicate keys → catchable throw

let
  fw = import ../framework.nix { };
  m = import ../../lib/default.nix;
  Color = m.enum "Color" [ "Red" "Green" "Blue" ];
in
fw.runAll [
  # === H7: match with non-instance list elements ===
  { name = "audit3.h7.01-match-list-with-non-instance-throws";
    test = fw.assertThrows "audit3.h7.01"
      (m.match [ 42 ] { _._ = { ... }: "wild"; }); }

  { name = "audit3.h7.02-match-list-with-mixed-throws";
    test = fw.assertThrows "audit3.h7.02"
      (m.match [ Color.Red 42 ] { _._ = { ... }: "wild"; }); }

  { name = "audit3.h7.03-match-attrset-with-non-instance-throws";
    test = fw.assertThrows "audit3.h7.03"
      (m.match { x = 42; } { _ = { ... }: "wild"; }); }

  { name = "audit3.h7.04-match-attrset-with-mixed-throws";
    test = fw.assertThrows "audit3.h7.04"
      (m.match { a = Color.Red; b = "not-instance"; } { _ = { ... }: "wild"; }); }

  { name = "audit3.h7.05-match-enum-type-as-input-throws";
    # Passing an enum TYPE (not instance) should throw, not silently
    # iterate its internal fields.
    test = fw.assertThrows "audit3.h7.05"
      (m.match Color { Red = v: "r"; _ = v: "other"; }); }

  { name = "audit3.h7.06-match-list-with-valid-instances-works";
    test = m.match [ Color.Red Color.Green ] {
      Red.Green = { _1, _2 }: "rg";
      _._ = { ... }: "wild";
    } == "rg"; }

  # === H8: serialize on non-instance ===
  { name = "audit3.h8.01-serialize-on-int-throws";
    test = fw.assertThrows "audit3.h8.01"
      (m.serialize 42); }

  { name = "audit3.h8.02-serialize-on-string-throws";
    test = fw.assertThrows "audit3.h8.02"
      (m.serialize "hello"); }

  { name = "audit3.h8.03-serialize-on-plain-attrset-throws";
    test = fw.assertThrows "audit3.h8.03"
      (m.serialize { x = 1; }); }

  { name = "audit3.h8.04-serialize-on-null-throws";
    test = fw.assertThrows "audit3.h8.04"
      (m.serialize null); }

  { name = "audit3.h8.05-serialize-on-enum-type-throws";
    test = fw.assertThrows "audit3.h8.05"
      (m.serialize Color); }

  # === H9: option.cases with missing handler keys ===
  { name = "audit3.h9.01-option-cases-missing-some-throws";
    test = fw.assertThrows "audit3.h9.01"
      (m.option.cases (m.some 42) { none = 0; }); }

  { name = "audit3.h9.02-option-cases-missing-none-throws";
    test = fw.assertThrows "audit3.h9.02"
      (m.option.cases (m.some 42) { some = x: x; }); }

  { name = "audit3.h9.03-option-cases-with-both-works";
    test = m.option.cases (m.some 42) { some = x: x + 1; none = 0; } == 43; }

  { name = "audit3.h9.04-option-cases-none-with-both-works";
    test = m.option.cases m.none { some = x: x + 1; none = 99; } == 99; }

  # === H9: result.cases with missing handler keys ===
  { name = "audit3.h9.05-result-cases-missing-ok-throws";
    test = fw.assertThrows "audit3.h9.05"
      (m.result.cases (m.ok 42) { err = e: -1; }); }

  { name = "audit3.h9.06-result-cases-missing-err-throws";
    test = fw.assertThrows "audit3.h9.06"
      (m.result.cases (m.ok 42) { ok = x: x; }); }

  { name = "audit3.h9.07-result-cases-with-both-works";
    test = m.result.cases (m.ok 42) { ok = x: x + 1; err = e: -1; } == 43; }

  { name = "audit3.h9.08-result-cases-err-with-both-works";
    test = m.result.cases (m.err "fail") { ok = x: x; err = e: -1; } == -1; }

  # === M8: isType distinguishes enums with different variant sets ===
  { name = "audit3.m8.01-same-typename-different-variants-not-equal";
    test =
      let
        Color1 = m.enum "Color" [ "Red" "Green" "Blue" ];
        Color2 = m.enum "Color" [ "Red" "Green" "Blue" "Yellow" ];
      in !(m.isType Color1.Red Color2); }

  { name = "audit3.m8.02-same-typename-same-variants-equal";
    test =
      let
        Color1 = m.enum "Color" [ "Red" "Green" "Blue" ];
        Color2 = m.enum "Color" [ "Red" "Green" "Blue" ];
      in m.isType Color1.Red Color2; }

  { name = "audit3.m8.03-different-typename-not-equal";
    test =
      let
        Color = m.enum "Color" [ "Red" "Green" "Blue" ];
        Shape = m.enum "Shape" { Circle = Color; };
      in !(m.isType Color.Red Shape); }

  { name = "audit3.m8.04-postable-same-variant-names-equal";
    test =
      let
        E1 = m.enum "E" { A = 1; B = 2; };
        E2 = m.enum "E" { A = 10; B = 20; };
      in m.isType E1.A E2; }

  # === M9: __PORDER__ with duplicate keys ===
  { name = "audit3.m9.01-porder-duplicate-keys-throws";
    test = fw.assertThrows "audit3.m9.01"
      (let
        color = Color.Red;
        shape = (m.enum "Shape" { Circle = Color; }).Circle Color.Red;
      in m.match { inherit color shape; } {
        __PORDER__ = [ "color" "color" ];
        _._ = { ... }: 0;
      }); }

  { name = "audit3.m9.02-porder-unique-keys-works";
    test =
      let
        color = Color.Red;
        shape = (m.enum "Shape" { Circle = Color; }).Circle Color.Red;
      in m.match { inherit color shape; } {
        __PORDER__ = [ "color" "shape" ];
        Red.Circle = { color, shape }: "ok";
        _._ = { ... }: 0;
      } == "ok"; }

  # === L16/L17: null and empty-list display edge cases ===
  { name = "audit3.l16.01-some-null-value-is-null";
    # some null stores null as the value (collision with non-postable sentinel
    # affects display, but value is correct).
    test = (m.some null).value == null; }

  { name = "audit3.l16.02-some-null-isSome-true";
    test = m.option.isSome (m.some null); }

  { name = "audit3.l16.03-some-null-unwrap-returns-null";
    test = m.option.unwrap (m.some null) == null; }

  { name = "audit3.l17.01-some-empty-list-value-is-empty-list";
    test = (m.some [ ]).value == [ ]; }

  { name = "audit3.l17.02-some-empty-list-isSome-true";
    test = m.option.isSome (m.some [ ]); }
]
