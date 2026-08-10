# @path: test/cases/option.nix
# @description: Option ADT test cases — Some, None, unwrap, map, etc.

let
  fw = import ../framework.nix { };
  m = import ../../lib/default.nix;
  O = m.option;  # namespaced Option helpers
  inherit (m) some none Option;
in
fw.runAll [
  # === Construction ===
  { name = "option.construct.01-some-tag";
    test = (some 42).tag == "Some"; }
  { name = "option.construct.02-some-value";
    test = (some 42).value == 42; }
  { name = "option.construct.03-some-display";
    test = (some 42).display == "enum::Option::Some(42)"; }
  { name = "option.construct.04-none-tag";
    test = none.tag == "None"; }
  { name = "option.construct.05-none-value-null";
    test = none.value == null; }
  { name = "option.construct.06-some-with-string";
    test = (some "hello").value == "hello"; }
  { name = "option.construct.07-some-with-attrset";
    test = (some { a = 1; }).value.a == 1; }
  { name = "option.construct.08-some-with-list";
    test = (some [ 1 2 3 ]).value == [ 1 2 3 ]; }
  { name = "option.construct.09-some-string-interpolation";
    test = "${some 42}" == "enum::Option::Some(42)"; }

  # === Predicates ===
  { name = "option.pred.01-isSome-on-some";
    test = O.isSome (some 42); }
  { name = "option.pred.02-isSome-on-none";
    test = !O.isSome none; }
  { name = "option.pred.03-isNone-on-none";
    test = O.isNone none; }
  { name = "option.pred.04-isNone-on-some";
    test = !O.isNone (some 42); }

  # === Extractors ===
  { name = "option.extract.01-unwrap-some";
    test = O.unwrap (some 42) == 42; }
  { name = "option.extract.02-unwrap-none-throws";
    test = fw.assertThrows "option.extract.02"
      (O.unwrap none); }
  { name = "option.extract.03-unwrapOr-some";
    test = O.unwrapOr 0 (some 42) == 42; }
  { name = "option.extract.04-unwrapOr-none";
    test = O.unwrapOr 0 none == 0; }
  { name = "option.extract.05-unwrapOrElse-some";
    test = O.unwrapOrElse (_: 0) (some 42) == 42; }
  { name = "option.extract.06-unwrapOrElse-none";
    test = O.unwrapOrElse (_: 99) none == 99; }
  { name = "option.extract.07-expect-some";
    test = O.expect "should have value" (some 42) == 42; }
  { name = "option.extract.08-expect-none-throws";
    test = fw.assertThrows "option.extract.08"
      (O.expect "custom message" none); }

  # === Transformers ===
  { name = "option.transform.01-map-some";
    test = O.unwrap (O.map (x: x * 2) (some 21)) == 42; }
  { name = "option.transform.02-map-none";
    test = O.isNone (O.map (x: x * 2) none); }
  { name = "option.transform.03-mapOr-some";
    test = O.mapOr 0 (x: x + 1) (some 41) == 42; }
  { name = "option.transform.04-mapOr-none";
    test = O.mapOr 42 (x: x + 1) none == 42; }
  { name = "option.transform.05-andThen-some";
    test = O.unwrap (O.andThen (x: some (x + 1)) (some 41)) == 42; }
  { name = "option.transform.06-andThen-none";
    test = O.isNone (O.andThen (x: some (x + 1)) none); }
  { name = "option.transform.07-andThen-returns-none";
    test = O.isNone (O.andThen (_: none) (some 42)); }
  { name = "option.transform.08-filter-keeps-matching";
    test = O.unwrap (O.filter (x: x > 10) (some 42)) == 42; }
  { name = "option.transform.09-filter-drops-non-matching";
    test = O.isNone (O.filter (x: x > 100) (some 42)); }
  { name = "option.transform.10-filter-none";
    test = O.isNone (O.filter (x: true) none); }

  # === Pattern matching (cases) ===
  { name = "option.match.01-cases-some";
    test = O.cases (some 42) { some = x: x + 1; none = 0; } == 43; }
  { name = "option.match.02-cases-none";
    test = O.cases none { some = x: x + 1; none = 99; } == 99; }

  # === Type identity ===
  { name = "option.type.01-isInst-on-some";
    test = m.isInst (some 42); }
  { name = "option.type.02-isInst-on-none";
    test = m.isInst none; }
  { name = "option.type.03-isType-some-option";
    test = m.isType (some 42) Option; }
  { name = "option.type.04-isType-none-option";
    test = m.isType none Option; }
  { name = "option.type.05-descTp-some";
    test = m.descTp (some 42) == "enum::Option::Some(42)"; }
]
