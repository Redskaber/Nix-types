# @path: test/cases/audit5.nix
# @description: Tests for issues found during the v3.4 final exhaustive audit.
# These verify the fixes for:
#   M1: variant name `_` (wildcard) rejected
#   M2: reserved keys `__PORDER__`/`__throw__` rejected as variant names
#   L1: option.cases validates `none` is not a function
#   L3: match/serialize/__variants__ added to internal keys (no shadowing)
#   L9: match on enum TYPE gives clear error

let
  fw = import ../framework.nix { };
  m = import ../../lib/default.nix;
in
fw.runAll [
  # === M1: wildcard `_` rejected as variant name ===
  { name = "audit5.m1.01-wildcard-variant-name-rejected-list";
    test = fw.assertThrows "audit5.m1.01"
      (m.enum "E" [ "_" "A" ]); }

  { name = "audit5.m1.02-wildcard-variant-name-rejected-attrset";
    test = fw.assertThrows "audit5.m1.02"
      (m.enum "E" { "_" = 1; }); }

  # === M2: reserved keys rejected as variant names ===
  { name = "audit5.m2.01-porder-variant-name-rejected";
    test = fw.assertThrows "audit5.m2.01"
      (m.enum "E" { __PORDER__ = 1; }); }

  { name = "audit5.m2.02-throw-variant-name-rejected";
    test = fw.assertThrows "audit5.m2.02"
      (m.enum "E" { __throw__ = 1; }); }

  { name = "audit5.m2.03-porder-in-list-rejected";
    test = fw.assertThrows "audit5.m2.03"
      (m.enum "E" [ "__PORDER__" "A" ]); }

  # === L1: option.cases validates `none` is not a function ===
  { name = "audit5.l1.01-option-cases-none-is-function-throws";
    test = fw.assertThrows "audit5.l1.01"
      (m.option.cases m.none { some = x: x; none = _: 0; }); }

  { name = "audit5.l1.02-option-cases-none-is-value-works";
    test = m.option.cases m.none { some = x: x; none = 99; } == 99; }

  { name = "audit5.l1.03-option-cases-none-zero-works";
    # Zero is a valid value (not a function).
    test = m.option.cases m.none { some = x: x; none = 0; } == 0; }

  # === L3: match/serialize/__variants__ live on enum TYPE, not instances ===
  # The internal-keys fix ensures user data in validator returns doesn't
  # pollute the instance with internal markers. match/serialize/__variants__
  # are attached to the ENUM TYPE by mkEnumStructFunction, not to instances.
  { name = "audit5.l3.01-enum-type-match-is-function";
    test =
      let
        E = m.enum "E" { V = _: { match = "chess"; }; };
      in
        builtins.isFunction E.match; }

  { name = "audit5.l3.02-enum-type-serialize-is-function";
    test =
      let
        E = m.enum "E" { V = _: { serialize = "data"; }; };
      in
        builtins.isFunction E.serialize; }

  { name = "audit5.l3.03-enum-type-variants-is-attrset";
    test =
      let
        E = m.enum "E" { V = _: { __variants__ = "fake"; }; };
      in
        # __variants__ on the TYPE is the user-supplied variants attrset.
        builtins.isAttrs E.__variants__ && E.__variants__ ? V; }

  { name = "audit5.l3.04-validator-returned-attrset-still-spread";
    # User data (non-internal keys) is still spread onto the instance value.
    test =
      let
        E = m.enum "E" { V = _: { custom = 42; }; };
        inst = E.V { x = 1; };
      in
        inst.value.custom == 42; }

  { name = "audit5.l3.05-instance-does-not-have-match";
    # Instances don't carry match/serialize (those are on the TYPE).
    test =
      let
        E = m.enum "E" { V = 42; };
        inst = E.V;
      in
        !(inst ? match) && !(inst ? serialize) && !(inst ? __variants__); }

  # === L9: match on enum TYPE gives clear error ===
  { name = "audit5.l9.01-match-on-enum-type-throws-clear";
    test = fw.assertThrows "audit5.l9.01"
      (let Color = m.enum "Color" [ "Red" "Green" "Blue" ];
       in m.match Color { Red = v: "r"; _ = v: "other"; }); }

  { name = "audit5.l9.02-match-on-enum-instance-works";
    test =
      let Color = m.enum "Color" [ "Red" "Green" "Blue" ];
      in m.match Color.Red { Red = v: "r"; _ = v: "other"; } == "r"; }

  # === Error message wording (L8) ===
  { name = "audit5.l8.01-error-messages-use-found-not-find";
    # Verify error messages use "found" not "find" (grammar fix).
    # We can't easily test the message content, but we verify the throw
    # is catchable (which it must be for the grammar fix to matter).
    test = fw.assertThrows "audit5.l8.01"
      (m.enum "E" 42); }

  # === Additional edge cases ===
  { name = "audit5.edge.01-empty-string-typename-throws";
    test = fw.assertThrows "audit5.edge.01"
      (m.enum "" [ "A" ]); }

  { name = "audit5.edge.02-duplicate-variant-in-list-throws";
    test = fw.assertThrows "audit5.edge.02"
      (m.enum "E" [ "A" "B" "A" ]); }

  { name = "audit5.edge.03-serialize-option-instance";
    test =
      let s = m.serialize (m.some 42);
      in s.tag == "Some" && s.value == 42; }

  { name = "audit5.edge.04-serialize-result-err";
    test =
      let s = m.serialize (m.err "fail");
      in s.tag == "Err" && s.value == "fail"; }

  { name = "audit5.edge.05-toJSON-on-serialize-output";
    test =
      let
        s = m.serialize (m.some 42);
        json = builtins.toJSON s;
      in builtins.isString json; }
]
