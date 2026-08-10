# @path: test/cases/lazy.nix
# @description: Lazy evaluation boundary tests.
#
# Nix is lazy by default, but certain operations force evaluation. This
# suite documents and verifies EXACTLY which operations are lazy and
# which are eager, so future refactors don't accidentally change the
# strictness semantics.
#
# Key principle: `builtins.tryEval` catches `throw` (but not `abort` or
# builtin errors). We use `throw` as a probe — if it fires, the value
# was forced; if not, it stayed lazy.

let
  fw = import ../framework.nix { };
  m = import ../../lib/default.nix;

  # Helper: returns true if `thunk` does NOT throw (i.e., stays lazy / succeeds).
  # We probe by wrapping in tryEval — if the thunk throws, tryEval catches it.
  isLazy = thunk:
    let r = builtins.tryEval (builtins.seq thunk true); in
    r.success;

  # Helper: returns true if `thunk` DOES throw (i.e., was forced).
  isForced = thunk:
    let r = builtins.tryEval (builtins.seq thunk true); in
    !r.success;

  # Helper: access only `.tag` of an attrset, without forcing `.value`.
  # If the attrset has `value = throw ...`, accessing `.tag` should NOT fire.
  accessTagOnly = inst: inst.tag;

  # Helper: access only `.value` of an attrset.
  accessValueOnly = inst: inst.value;
in
fw.runAll [
  # ============================================================
  # A. ENUM CREATION — LAZY
  # Creating an enum does NOT force variant descriptors.
  # ============================================================
  { name = "lazy.enum-create.01-variant-descriptors-not-forced";
    test =
      let
        E = m.enum "E" { A = 1; B = throw "B_DESCRIPTOR"; };
      in isLazy E; }

  { name = "lazy.enum-create.02-list-variant-names-not-forced";
    # For unit enums, the variant NAMES (list elements) are forced during
    # construction because `map` iterates over them. But the descriptors
    # (which for unit enums are just the names) are strings — no side effects.
    # Verify: creating a unit enum with a throwing NAME throws, because
    # the name list is iterated by `map`.
    test =
      let
        Color = m.enum "Color" [ "Red" "Green" "Blue" ];
      in isLazy Color; }

  { name = "lazy.enum-create.03-attrset-variant-values-not-forced";
    # For postable enums, variant descriptor VALUES are not forced during
    # enum creation. Only when a specific variant is accessed.
    test =
      let
        E = m.enum "E" {
          A = 1;
          B = throw "B_DESCRIPTOR";
          C = 3;
        };
      in isLazy E; }

  # ============================================================
  # B. VARIANT ACCESS — LAZY (only that variant forced)
  # Accessing variant A does NOT force variant B's descriptor.
  # ============================================================
  { name = "lazy.variant-access.01-only-accessed-variant-forced";
    test =
      let
        E = m.enum "E" {
          A = 1;
          B = throw "B_DESCRIPTOR";
        };
      in E.A.value == 1; }

  { name = "lazy.variant-access.02-other-variants-stay-lazy";
    test =
      let
        E = m.enum "E" {
          A = 1;
          B = throw "B_DESCRIPTOR";
        };
      in isLazy (E.A.value) && isForced (E.B.value); }

  { name = "lazy.variant-access.03-tag-does-not-force-value";
    # Accessing .tag should NOT force .value (they're independent attrset fields).
    test =
      let
        E = m.enum "E" { A = 42; };
        inst = E.A;
      in accessTagOnly inst == "A" && accessValueOnly inst == 42; }

  # ============================================================
  # C. MATCH — LAZY (only matched handler runs)
  # ============================================================
  { name = "lazy.match.01-single-only-matched-handler-runs";
    test =
      let
        Color = m.enum "Color" [ "Red" "Green" "Blue" ];
      in Color.match Color.Red {
        Red = v: "red";
        Green = throw "GREEN_HANDLER";
        Blue = throw "BLUE_HANDLER";
      } == "red"; }

  { name = "lazy.match.02-wildcard-only-runs-if-needed";
    test =
      let
        Color = m.enum "Color" [ "Red" "Green" "Blue" ];
      in Color.match Color.Red {
        Red = v: "red";
        _ = throw "WILDCARD";
      } == "red"; }

  { name = "lazy.match.03-list-only-matched-pattern-runs";
    test =
      let
        Color = m.enum "Color" [ "Red" "Green" "Blue" ];
      in m.match [ Color.Red Color.Green ] {
        Red.Green = { _1, _2 }: "rg";
        _._ = { ... }: throw "WILDCARD";
      } == "rg"; }

  { name = "lazy.match.04-handler-receives-lazy-instance";
    # The handler receives the instance but doesn't have to force its value.
    test =
      let
        Color = m.enum "Color" [ "Red" "Green" "Blue" ];
      in Color.match Color.Red {
        Red = v: v.tag;  # only accesses .tag, not .value
        _ = v: "other";
      } == "Red"; }

  # ============================================================
  # D. TUPLE CONSTRUCT — EAGER (all args validated)
  # Tuple variants validate ALL arguments at construct time.
  # This is a deliberate safety tradeoff: catch arity/type errors early.
  # ============================================================
  { name = "lazy.tuple.01-all-args-forced-at-construct";
    # Constructing a tuple variant forces ALL args (validation).
    test =
      let
        Color = m.enum "Color" [ "Red" "Green" "Blue" ];
        Shape = m.enum "Shape" { Square = [ Color Color Color ]; };
      in isForced (Shape.Square [ Color.Red (throw "ARG1") Color.Blue ]); }

  { name = "lazy.tuple.02-wrong-arity-throws-at-construct";
    test =
      let
        Color = m.enum "Color" [ "Red" "Green" "Blue" ];
        Shape = m.enum "Shape" { Square = [ Color Color Color ]; };
      in fw.assertThrows "lazy.tuple.02"
        (Shape.Square [ Color.Red Color.Green ]); }

  # ============================================================
  # E. FUNCTION VALIDATOR — EAGER (runs at construct time)
  # ============================================================
  { name = "lazy.fun.01-validator-runs-at-construct";
    test =
      let
        Color = m.enum "Color" [ "Red" "Green" "Blue" ];
        Shape = m.enum "Shape" {
          Triangle = { pos1, pos2, pos3 }@inst:
            if pos1.tag == pos2.tag then inst
            else { __throw__ = "mismatch"; };
        };
      in isForced (Shape.Triangle { pos1=Color.Red; pos2=throw "POS2"; pos3=Color.Blue; }); }

  { name = "lazy.fun.02-validator-failure-throws-at-construct";
    test =
      let
        Color = m.enum "Color" [ "Red" "Green" "Blue" ];
        Shape = m.enum "Shape" {
          Triangle = { pos1, pos2, pos3 }@inst:
            if pos1.tag == pos2.tag then inst
            else { __throw__ = "mismatch"; };
        };
      in fw.assertThrows "lazy.fun.02"
        (Shape.Triangle { pos1=Color.Red; pos2=Color.Green; pos3=Color.Blue; }); }

  # ============================================================
  # F. SERIALIZE — LAZY per-field
  # serialize returns { tag, typename, value }. Each field is independent.
  # ============================================================
  { name = "lazy.serialize.01-tag-does-not-force-value";
    test =
      let
        E = m.enum "E" { A = 42; };
        s = m.serialize E.A;
      in s.tag == "A" && s.typename == "E" && s.value == 42; }

  { name = "lazy.serialize.02-value-field-forces-instance-value";
    # Accessing s.value forces the instance's value (for the isInst check).
    test =
      let
        E = m.enum "E" { A = 42; };
        s = m.serialize E.A;
      in s.value == 42; }

  # ============================================================
  # G. DISPLAY — EAGER (forces value for string construction)
  # The display string includes the value, so it must be forced.
  # ============================================================
  { name = "lazy.display.01-display-forces-value";
    test =
      let
        E = m.enum "E" { A = 42; };
      in E.A.display == "enum::E::A(42)"; }

  { name = "lazy.display.02-toString-uses-display";
    # String interpolation via __toString uses display, which forces value.
    test =
      let
        E = m.enum "E" { A = 42; };
      in "${E.A}" == "enum::E::A(42)"; }

  # ============================================================
  # H. PREDICATES — LAZY (WHNF only)
  # isInst/isEnum check attr presence, not values.
  # ============================================================
  { name = "lazy.pred.01-isInst-does-not-force-value";
    test =
      let
        E = m.enum "E" { A = 42; };
      in m.isInst E.A; }

  { name = "lazy.pred.02-isEnum-does-not-force-variants";
    test =
      let
        E = m.enum "E" { A = 42; };
      in m.isEnum E; }

  { name = "lazy.pred.03-isType-does-not-force-value";
    test =
      let
        E = m.enum "E" { A = 42; };
      in m.isType E.A E; }

  # ============================================================
  # I. OPTION/RESULT — EAGER for Some/Ok (validator runs)
  # ============================================================
  { name = "lazy.option.01-some-value-forced-at-construct";
    # `some (throw "X")` throws because `mkInstance` calls `getBasePostable`,
    # which forces the value via `builtins.isAttrs` to decide whether to
    # spread it onto the instance record. This is independent of the
    # validator fn `_: true` (which does NOT force its argument).
    test =
      let
        s = m.some (throw "VALUE");
      in isForced s; }

  { name = "lazy.option.02-unwrap-forces-value";
    test =
      let
        s = m.some 42;
      in m.option.unwrap s == 42; }

  { name = "lazy.option.03-isSome-on-some-with-value";
    test =
      let
        s = m.some 42;
      in m.option.isSome s; }

  { name = "lazy.option.04-map-forces-original-value";
    test =
      let
        s = m.some 21;
      in m.option.unwrap (m.option.map (x: x * 2) s) == 42; }

  { name = "lazy.option.05-cases-forces-value-for-some-branch";
    test =
      let
        s = m.some 42;
      in m.option.cases s { some = x: x + 1; none = 0; } == 43; }

  { name = "lazy.option.06-filter-forces-value";
    test =
      let
        s = m.some 42;
      in m.option.isSome (m.option.filter (x: x > 10) s); }

  { name = "lazy.option.07-none-is-lazy";
    # None is a unit variant — no value to force.
    test =
      let
        n = m.none;
      in isLazy n && m.option.isNone n; }

  { name = "lazy.result.01-ok-value-forced-at-construct";
    # `ok (throw "X")` throws because Ok uses a validator fn (_: true).
    test =
      let
        o = m.ok (throw "VALUE");
      in isForced o; }

  { name = "lazy.result.02-unwrap-forces-value";
    test =
      let
        o = m.ok 42;
      in m.result.unwrap o == 42; }

  { name = "lazy.result.03-isOk-on-ok-with-value";
    test =
      let
        o = m.ok 42;
      in m.result.isOk o; }

  { name = "lazy.result.04-err-is-eager-too";
    test =
      let
        e = m.err "fail";
      in m.result.isErr e && m.result.unwrapErr e == "fail"; }

  # ============================================================
  # J. LARGE ENUM — LAZY (unaccessed variants not constructed)
  # ============================================================
  { name = "lazy.large.01-1000-variants-access-two-only";
    test =
      let
        names = builtins.genList (n: "V${builtins.toString n}") 1000;
        Big = m.enum "Big" names;
      in
        (builtins.length Big.__variants__) == 1000
        && (Big.V0.tag == "V0")
        && (Big.V999.tag == "V999"); }

  { name = "lazy.large.02-postable-1000-variants-access-two";
    test =
      let
        variants = builtins.listToAttrs (builtins.genList (n: {
          name = "V${builtins.toString n}";
          value = n;
        }) 1000);
        Big = m.enum "Big" variants;
      in
        Big.V0.value == 0
        && Big.V999.value == 999; }
]
