# @path: test/cases/match.nix
# @description: Pattern matching test cases — single, list, attrset, errors.

let
  fw = import ../framework.nix { };
  shared = import ./shared.nix;
  inherit (shared) Color Position lib;

  Shape = shared.enum "Shape" {
    Circle   = Color;
    Square   = [ Color Color Color ];
    Triangle = { pos1, pos2, pos3 }@instance:
      if pos1.tag == pos2.tag then { inherit pos1 pos2 pos3; }
      else { __throw__ = "Triangle requires pos1 == pos2"; };
  };

  color = Color.Red;
  shape = Shape.Circle Color.Red;
  position = Position.local;
in
fw.runAll [
  # === single match (library-level) ===
  { name = "match.single.01-variant-matches-lib";
    test = lib.match Color.Green {
      Red = v: "r"; Green = v: "g"; Blue = v: "b";
    } == "g"; }
  { name = "match.single.02-variant-matches-alias";
    test = Color.match Color.Green {
      Red = v: "r"; Green = v: "g"; Blue = v: "b";
    } == "g"; }
  { name = "match.single.03-handler-receives-instance";
    test = lib.match Color.Red {
      Red = v: v.tag; Green = v: v.tag; Blue = v: v.tag;
    } == "Red"; }
  { name = "match.single.04-wildcard-fallback";
    test = lib.match Color.Green {
      Red = v: "r"; _ = v: "other";
    } == "other"; }
  { name = "match.single.05-exact-beats-wildcard";
    test = lib.match Color.Red {
      Red = v: "exact"; _ = v: "wild";
    } == "exact"; }
  { name = "match.single.06-non-function-handler";
    test = lib.match Color.Red {
      Red = "literal-handler"; _ = "wild";
    } == "literal-handler"; }
  { name = "match.single.07-handler-can-access-display";
    test = lib.match Color.Red {
      Red = v: v.display; _ = v: v.display;
    } == "enum::Color::Red"; }

  # === list match (library-level) ===
  { name = "match.list.01-exact-2-tag-pattern";
    test = (lib.match [ color shape ] {
      Red.Circle = { _1, _2 }: "${_1.tag},${_2.tag}";
      _._ = { ... }: "other";
    }) == "Red,Circle"; }
  { name = "match.list.02-wildcard-fallback";
    test = (lib.match [ Color.Blue shape ] {
      Red.Circle = { _1, _2 }: "exact";
      _._ = { ... }: "wild";
    }) == "wild"; }
  { name = "match.list.03-specificity-ordering";
    test = (lib.match [ color shape ] {
      _._ = { ... }: "less-specific";
      Red._ = { _1, _2 }: "more-specific";
    }) == "more-specific"; }
  { name = "match.list.04-3-element-pattern";
    test = (lib.match [ Color.Red Color.Green Color.Blue ] {
      Red.Green.Blue = { _1, _2, _3 }: "${_1.tag}-${_2.tag}-${_3.tag}";
      _._._ = { ... }: "other";
    }) == "Red-Green-Blue"; }
  { name = "match.list.05-3-element-wildcard";
    test = (lib.match [ Color.Red Color.Red Color.Red ] {
      Red.Red.Red = { _1, _2, _3 }: "all-red";
      _._._ = { ... }: "other";
    }) == "all-red"; }
  { name = "match.list.06-partial-wildcard-in-middle";
    test = (lib.match [ Color.Red Color.Green Color.Blue ] {
      Red._.Blue = { _1, _2, _3 }: "red-_-blue";
      _._._ = { ... }: "other";
    }) == "red-_-blue"; }
  { name = "match.list.07-enum-carried-alias-works";
    test = (Shape.match [ color shape ] {
      Red.Circle = { _1, _2 }: "${_1.tag},${_2.tag}";
      _._ = { ... }: "other";
    }) == "Red,Circle"; }

  # === attrset match (with __PORDER__) ===
  { name = "match.attrset.01-porder-keys";
    test = (lib.match { inherit color shape; } {
      __PORDER__ = [ "color" "shape" ];
      Red.Circle = { color, shape }: "${color.tag},${shape.tag}";
      _._ = { ... }: 0;
    }) == "Red,Circle"; }
  { name = "match.attrset.02-porder-reordered";
    test = (lib.match { inherit color shape; } {
      __PORDER__ = [ "shape" "color" ];
      Circle.Red = { color, shape }: "${shape.tag},${color.tag}";
      _._ = { ... }: 0;
    }) == "Circle,Red"; }
  { name = "match.attrset.03-porder-3-keys";
    test = (lib.match { inherit color shape position; } {
      __PORDER__ = [ "color" "shape" "position" ];
      Red.Circle.local = { color, shape, position }: "${color.tag}-${shape.tag}-${position.tag}";
      _._._ = { ... }: 0;
    }) == "Red-Circle-local"; }
  { name = "match.attrset.04-no-porder-uses-default-attr-order";
    test = (lib.match { inherit color shape; } {
      Red.Circle = { color, shape }: "ok";
      _._ = { ... }: 0;
    }) == "ok"; }
  { name = "match.attrset.05-porder-missing-key-rejected";
    test = fw.assertThrows "match.attrset.05"
      (lib.match { inherit color shape; } {
        __PORDER__ = [ "color" "shape" "missing" ];
        _._._ = { ... }: 0;
      }); }
  { name = "match.attrset.06-porder-count-mismatch-rejected";
    test = fw.assertThrows "match.attrset.06"
      (lib.match { inherit color shape; } {
        __PORDER__ = [ "color" ];
        _._ = { ... }: 0;
      }); }
  { name = "match.attrset.07-porder-non-list-rejected";
    test = fw.assertThrows "match.attrset.07"
      (lib.match { inherit color shape; } {
        __PORDER__ = "not-a-list";
        _._ = { ... }: 0;
      }); }
  { name = "match.attrset.08-porder-non-string-elem-rejected";
    test = fw.assertThrows "match.attrset.08"
      (lib.match { inherit color shape; } {
        __PORDER__ = [ "color" 42 ];
        _._ = { ... }: 0;
      }); }

  # === non-exhaustive match errors ===
  { name = "match.exhaust.01-single-no-wildcard-missing-variant";
    test = fw.assertThrows "match.exhaust.01"
      (lib.match Color.Green { Red = v: "r"; }); }
  { name = "match.exhaust.02-list-no-wildcard-non-matching";
    test = fw.assertThrows "match.exhaust.02"
      (lib.match [ Color.Red Color.Green ] {
        Red.Blue = { _1, _2 }: "x";
      }); }
  { name = "match.exhaust.03-empty-input-list-rejected";
    test = fw.assertThrows "match.exhaust.03"
      (lib.match [ ] { _ = v: v; }); }
  { name = "match.exhaust.04-empty-input-attrset-rejected";
    test = fw.assertThrows "match.exhaust.04"
      (lib.match { } { _ = v: v; }); }
  { name = "match.exhaust.05-distinct-patterns-accepted";
    test = (lib.match [ Color.Red Color.Green ] {
      Red.Green = { _1, _2 }: "rg";
      Green.Red = { _1, _2 }: "gr";
      _._ = { ... }: "other";
    }) == "rg"; }

  # === input type validation ===
  { name = "match.input.01-int-input-rejected";
    test = fw.assertThrows "match.input.01"
      (lib.match 42 { _ = v: v; }); }
  { name = "match.input.02-string-input-rejected";
    test = fw.assertThrows "match.input.02"
      (lib.match "hello" { _ = v: v; }); }
  { name = "match.input.03-patterns-not-attrset-rejected";
    test = fw.assertThrows "match.input.03"
      (lib.match Color.Red [ "Red" ]); }

  # === match chaining (nested match inside handler) ===
  { name = "match.chain.01-nested-match-in-handler";
    test = (lib.match (Shape.Circle Color.Red) {
      Circle = v: lib.match v.value {
        Red = c: "circle-of-red";
        _ = c: "circle-of-other";
      };
      _ = v: "non-circle";
    }) == "circle-of-red"; }

  # === large pattern list (specificity stress test) ===
  { name = "match.stress.01-large-pattern-list-picks-most-specific";
    test = (lib.match [ Color.Red Color.Green ] {
      _._ = { ... }: "0-wild";
      Red._ = { ... }: "1-red";
      _.Green = { ... }: "1-green";
      Red.Green = { _1, _2 }: "2-exact";
    }) == "2-exact"; }
]
