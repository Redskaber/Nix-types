# @path: test/cases/literal.nix
# @description: Literal variant value test cases.

let
  fw = import ../framework.nix { };
  shared = import ./shared.nix;
  inherit (shared) Literals types;
in
fw.runAll [
  { name = "literal.01-int-value";
    test = Literals.Int.value == 1024; }
  { name = "literal.02-int-tag";
    test = Literals.Int.tag == "Int"; }
  { name = "literal.03-float-value";
    test = Literals.Float.value == 10.24; }
  { name = "literal.04-bool-value";
    test = Literals.Bool.value == true; }
  { name = "literal.05-string-value";
    test = Literals.Str.value == "enum-string-variant"; }
  { name = "literal.06-null-value";
    test = Literals.Null.value == null; }
  { name = "literal.07-path-value-is-path";
    test = builtins.isPath Literals.Path.value; }
  { name = "literal.08-deep-list-value";
    test = Literals.DeepList.value == [ "first" "second" ]; }
  { name = "literal.09-deep-nested-list-value";
    test = Literals.DeepNestedList.value == [ [ "a" "b" ] [ "c" ] ]; }
  { name = "literal.10-int-display";
    test = Literals.Int.display == "enum::Literals::Int(1024)"; }
  { name = "literal.11-string-display-quoted";
    test = Literals.Str.display == "enum::Literals::Str(\"enum-string-variant\")"; }
  { name = "literal.12-bool-display";
    test = Literals.Bool.display == "enum::Literals::Bool(true)"; }
  { name = "literal.13-null-display";
    test = Literals.Null.display == "enum::Literals::Null"; }
  { name = "literal.14-list-display";
    test = Literals.DeepList.display == "enum::Literals::DeepList(\"first\",\"second\")"; }
  { name = "literal.15-float-display";
    test = Literals.Float.display == "enum::Literals::Float(10.240000)"; }
  { name = "literal.16-isInst-on-literal-variants";
    test = builtins.all types.isInst [
      Literals.Int Literals.Float Literals.Bool Literals.Str
      Literals.Path Literals.Null Literals.DeepList Literals.DeepNestedList
    ]; }
  { name = "literal.17-zero-int";
    test = (shared.enum "Z" { V = 0; }).V.value == 0; }
  { name = "literal.18-empty-string";
    test = (shared.enum "E" { V = ""; }).V.value == ""; }
  { name = "literal.19-negative-int";
    test = (shared.enum "N" { V = -42; }).V.value == -42; }
  { name = "literal.20-false-bool";
    test = (shared.enum "B" { V = false; }).V.value == false; }
  { name = "literal.21-string-interpolation";
    test = "${Literals.Int}" == "enum::Literals::Int(1024)"; }
]
