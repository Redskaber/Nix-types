# @path: test/cases/predicates.nix
# @description: Type predicate & descriptor tests.

let
  fw = import ../framework.nix { };
  shared = import ./shared.nix;
  inherit (shared) Color Position types;
in
fw.runAll [
  # === isEnum ===
  { name = "pred.isEnum.01-true-on-enum";
    test = types.isEnum Color; }
  { name = "pred.isEnum.02-false-on-instance";
    test = !(types.isEnum Color.Red); }
  { name = "pred.isEnum.03-false-on-plain-attrset";
    test = !(types.isEnum { x = 1; }); }
  { name = "pred.isEnum.04-false-on-literal";
    test = !(types.isEnum 42); }
  { name = "pred.isEnum.05-false-on-null";
    test = !(types.isEnum null); }
  { name = "pred.isEnum.06-false-on-list";
    test = !(types.isEnum [ 1 2 3 ]); }
  { name = "pred.isEnum.07-false-on-function";
    test = !(types.isEnum (x: x)); }
  { name = "pred.isEnum.08-false-on-string";
    test = !(types.isEnum "string"); }

  # === isInst ===
  { name = "pred.isInst.01-true-on-instance";
    test = types.isInst Color.Red; }
  { name = "pred.isInst.02-false-on-enum";
    test = !(types.isInst Color); }
  { name = "pred.isInst.03-false-on-plain-attrset";
    test = !(types.isInst { x = 1; }); }
  { name = "pred.isInst.04-false-on-literal";
    test = !(types.isInst 42); }

  # === isType ===
  { name = "pred.isType.01-instance-vs-own-enum";
    test = types.isType Color.Red Color; }
  { name = "pred.isType.02-instance-vs-other-enum";
    test = !(types.isType Color.Red Position); }
  { name = "pred.isType.03-self-enum";
    test = types.isType Color Color; }
  { name = "pred.isType.04-instance-vs-wrong-enum";
    test = !(types.isType Position.local Color); }
  { name = "pred.isType.05-non-attrs-return-false";
    test = !(types.isType 42 Color) && !(types.isType Color.Red 42); }

  # === descTp ===
  { name = "pred.descTp.01-enum";
    test = types.descTp Color == "enum::Color"; }
  { name = "pred.descTp.02-instance-unit";
    test = types.descTp Color.Red == "enum::Color::Red"; }
  { name = "pred.descTp.03-instance-literal";
    test = types.descTp shared.Drive.intel == "enum::Drive::intel(\"intel\")"; }
  { name = "pred.descTp.04-builtin-int";
    test = types.descTp 42 == "int"; }
  { name = "pred.descTp.05-builtin-string";
    test = types.descTp "x" == "string"; }
  { name = "pred.descTp.06-builtin-list";
    test = types.descTp [ 1 ] == "list"; }
  { name = "pred.descTp.07-builtin-null";
    test = types.descTp null == "null"; }
  { name = "pred.descTp.08-builtin-lambda";
    test = types.descTp (x: x) == "lambda"; }

  # === isLiteral / isDeepLiteral / isContainer ===
  { name = "pred.isLiteral.01-int-true";
    test = types.isLiteral 42; }
  { name = "pred.isLiteral.02-float-true";
    test = types.isLiteral 1.5; }
  { name = "pred.isLiteral.03-bool-true";
    test = types.isLiteral true; }
  { name = "pred.isLiteral.04-null-true";
    test = types.isLiteral null; }
  { name = "pred.isLiteral.05-string-true";
    test = types.isLiteral "hello"; }
  { name = "pred.isLiteral.06-path-true";
    test = types.isLiteral ./.; }
  { name = "pred.isLiteral.07-list-false";
    test = !(types.isLiteral [ 1 ]); }
  { name = "pred.isLiteral.08-attrset-false";
    test = !(types.isLiteral { x = 1; }); }

  { name = "pred.isDeepLiteral.01-literal-true";
    test = types.isDeepLiteral 42; }
  { name = "pred.isDeepLiteral.02-list-of-literals-true";
    test = types.isDeepLiteral [ "a" "b" ]; }
  { name = "pred.isDeepLiteral.03-nested-list-of-literals-true";
    test = types.isDeepLiteral [ [ "a" ] [ "b" "c" ] ]; }
  { name = "pred.isDeepLiteral.04-list-with-attrset-false";
    test = !(types.isDeepLiteral [ { x = 1; } ]); }
  { name = "pred.isDeepLiteral.05-attrset-false";
    test = !(types.isDeepLiteral { x = 1; }); }
  { name = "pred.isDeepLiteral.06-empty-list-true";
    test = types.isDeepLiteral [ ]; }
  { name = "pred.isDeepLiteral.07-null-true";
    test = types.isDeepLiteral null; }

  { name = "pred.isContainer.01-list-true";
    test = types.isContainer [ 1 2 ]; }
  { name = "pred.isContainer.02-attrset-true";
    test = types.isContainer { x = 1; }; }
  { name = "pred.isContainer.03-int-false";
    test = !(types.isContainer 42); }

  # === parseTypeName ===
  { name = "pred.parseTypeName.01-valid-simple";
    test = (types.parseTypeName "Color").typename == "Color"; }
  { name = "pred.parseTypeName.02-valid-with-underscore";
    test = (types.parseTypeName "Shape_2D").typename == "Shape_2D"; }
  { name = "pred.parseTypeName.03-valid-leading-underscore";
    test = (types.parseTypeName "_internal").typename == "_internal"; }
  { name = "pred.parseTypeName.04-valid-with-digits";
    test = (types.parseTypeName "Http2").typename == "Http2"; }
  { name = "pred.parseTypeName.05-hyphen-rejected";
    test = fw.assertThrows "pred.parseTypeName.05"
      (types.parseTypeName "Foo-Bar"); }
  { name = "pred.parseTypeName.06-generic-syntax-rejected";
    test = fw.assertThrows "pred.parseTypeName.06"
      (types.parseTypeName "Foo<T>"); }
  { name = "pred.parseTypeName.07-leading-digit-rejected";
    test = fw.assertThrows "pred.parseTypeName.07"
      (types.parseTypeName "1st"); }
  { name = "pred.parseTypeName.08-empty-string-rejected";
    test = fw.assertThrows "pred.parseTypeName.08"
      (types.parseTypeName ""); }
  { name = "pred.parseTypeName.09-space-rejected";
    test = fw.assertThrows "pred.parseTypeName.09"
      (types.parseTypeName "With Space"); }
]
