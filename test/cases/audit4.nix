# @path: test/cases/audit4.nix
# @description: Tests for issues found during the v3.3 exhaustive audit.
# These verify the fixes for:
#   H10: variant name validation (empty, duplicate, internal collision, non-string)
#   H11: option/result predicates guard against non-attrsets
#   H12: cases validates handler types are functions
#   M14: serialize handles lambdas safely
#   M15: nested tuple serialization (documented behavior)

let
  fw = import ../framework.nix { };
  m = import ../../lib/default.nix;
in
fw.runAll [
  # === H10: variant name validation ===
  { name = "audit4.h10.01-empty-variant-name-rejected";
    test = fw.assertThrows "audit4.h10.01"
      (m.enum "E" [ "" "A" ]); }

  { name = "audit4.h10.02-duplicate-variant-names-rejected";
    test = fw.assertThrows "audit4.h10.02"
      (m.enum "E" [ "Red" "Red" ]); }

  { name = "audit4.h10.03-variant-collides-with-meta-rejected";
    test = fw.assertThrows "audit4.h10.03"
      (m.enum "E" { __meta__ = 1; }); }

  { name = "audit4.h10.04-variant-collides-with-match-rejected";
    test = fw.assertThrows "audit4.h10.04"
      (m.enum "E" { match = 1; }); }

  { name = "audit4.h10.05-variant-collides-with-serialize-rejected";
    test = fw.assertThrows "audit4.h10.05"
      (m.enum "E" { serialize = 1; }); }

  { name = "audit4.h10.06-variant-collides-with-variants-rejected";
    test = fw.assertThrows "audit4.h10.06"
      (m.enum "E" { __variants__ = 1; }); }

  { name = "audit4.h10.07-non-string-variant-name-rejected";
    test = fw.assertThrows "audit4.h10.07"
      (m.enum "E" [ "A" 42 "B" ]); }

  { name = "audit4.h10.08-valid-hyphenated-variant-name-accepted";
    # Hyphens are allowed in variant names (e.g., "intel-nvidia").
    test =
      let E = m.enum "E" { intel-nvidia = 1; };
      in E.intel-nvidia.value == 1; }

  { name = "audit4.h10.09-valid-underscore-variant-name-accepted";
    test =
      let E = m.enum "E" { _internal = 1; };
      in E._internal.value == 1; }

  # === H11: predicates guard against non-attrsets ===
  { name = "audit4.h11.01-isSome-on-int-returns-false";
    # Should not crash; should return false.
    test = m.option.isSome 42 == false; }

  { name = "audit4.h11.02-isSome-on-string-returns-false";
    test = m.option.isSome "hello" == false; }

  { name = "audit4.h11.03-isSome-on-null-returns-false";
    test = m.option.isSome null == false; }

  { name = "audit4.h11.04-isNone-on-int-returns-false";
    test = m.option.isNone 42 == false; }

  { name = "audit4.h11.05-isOk-on-int-returns-false";
    test = m.result.isOk 42 == false; }

  { name = "audit4.h11.06-isErr-on-int-returns-false";
    test = m.result.isErr 42 == false; }

  { name = "audit4.h11.07-isSome-on-fake-attrset-returns-true";
    # Duck-typing: an attrset with tag "Some" is considered Some.
    # This is intentional (documented in option.nix).
    test = m.option.isSome { tag = "Some"; } == true; }

  { name = "audit4.h11.08-isSome-on-real-some-returns-true";
    test = m.option.isSome (m.some 42) == true; }

  { name = "audit4.h11.09-isNone-on-real-none-returns-true";
    test = m.option.isNone m.none == true; }

  # === H12: cases validates handler types ===
  { name = "audit4.h12.01-option-cases-some-not-function-throws";
    test = fw.assertThrows "audit4.h12.01"
      (m.option.cases (m.some 42) { some = 42; none = 0; }); }

  { name = "audit4.h12.02-option-cases-some-string-throws";
    test = fw.assertThrows "audit4.h12.02"
      (m.option.cases (m.some 42) { some = "not-fn"; none = 0; }); }

  { name = "audit4.h12.03-result-cases-ok-not-function-throws";
    test = fw.assertThrows "audit4.h12.03"
      (m.result.cases (m.ok 42) { ok = 42; err = e: -1; }); }

  { name = "audit4.h12.04-result-cases-err-not-function-throws";
    test = fw.assertThrows "audit4.h12.04"
      (m.result.cases (m.ok 42) { ok = x: x; err = "not-fn"; }); }

  { name = "audit4.h12.05-option-cases-valid-handlers-work";
    test = m.option.cases (m.some 42) { some = x: x + 1; none = 0; } == 43; }

  { name = "audit4.h12.06-result-cases-valid-handlers-work";
    test = m.result.cases (m.ok 42) { ok = x: x + 1; err = e: -1; } == 43; }

  # === M14: serialize handles lambdas ===
  { name = "audit4.m14.01-serialize-lambda-in-attrset";
    test =
      let
        E = m.enum "E" { V = _: { fn = x: x; }; };
        inst = E.V { x = 1; };
        s = m.serialize inst;
      in s.value.fn == "<lambda>"; }

  { name = "audit4.m14.02-serialize-with-lambda-is-json-safe";
    test =
      let
        E = m.enum "E" { V = _: { fn = x: x; num = 42; }; };
        inst = E.V { x = 1; };
        s = m.serialize inst;
        json = builtins.toJSON s;
      in builtins.isString json; }

  # === M15: nested tuple serialization (documented behavior) ===
  { name = "audit4.m15.01-nested-tuple-construction-works";
    test =
      let
        Color = m.enum "Color" [ "Red" "Green" "Blue" ];
        Pair = m.enum "Pair" { Two = [ Color Color ]; };
        Nested = m.enum "Nested" { PairPair = [ Pair Pair ]; };
        inst = Nested.PairPair [
          (Pair.Two [ Color.Red Color.Green ])
          (Pair.Two [ Color.Blue Color.Red ])
        ];
      in inst.value._0.value._1.tag == "Green"; }

  { name = "audit4.m15.02-nested-tuple-display-works";
    test =
      let
        Color = m.enum "Color" [ "Red" "Green" "Blue" ];
        Pair = m.enum "Pair" { Two = [ Color Color ]; };
        Nested = m.enum "Nested" { PairPair = [ Pair Pair ]; };
        inst = Nested.PairPair [
          (Pair.Two [ Color.Red Color.Green ])
          (Pair.Two [ Color.Blue Color.Red ])
        ];
      in builtins.isString inst.display; }

  # === L25: additional test coverage gaps ===
  { name = "audit4.l25.01-match-wrong-enum-instance";
    # match on an instance of a different enum — works by tag (documented).
    test =
      let
        Color = m.enum "Color" [ "Red" "Green" "Blue" ];
        Shape = m.enum "Shape" [ "Red" "Circle" ];
      in Shape.match Color.Red { Red = v: "r"; _ = v: "other"; } == "r"; }

  { name = "audit4.l25.02-andThen-returns-none";
    test =
      let
        parse = s: if s == "" then m.none else m.some (builtins.stringLength s);
      in m.option.isNone (m.option.andThen parse (m.some "")); }

  { name = "audit4.l25.03-andThen-returns-some";
    test =
      let
        parse = s: if s == "" then m.none else m.some (builtins.stringLength s);
      in m.option.unwrap (m.option.andThen parse (m.some "hello")) == 5; }

  { name = "audit4.l25.04-result-andThen-returns-err";
    test =
      let
        divide = x: if x == 0 then m.err "div0" else m.ok (10 / x);
      in m.result.isErr (m.result.andThen divide (m.ok 0)); }

  { name = "audit4.l25.05-result-andThen-chains-ok";
    test =
      let
        divide = x: if x == 0 then m.err "div0" else m.ok (10 / x);
      in m.result.unwrap (m.result.andThen divide (m.ok 2)) == 5; }
]
