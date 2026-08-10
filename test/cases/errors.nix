# @path: test/cases/errors.nix
# @description: Error path & invalid-input tests.

let
  fw = import ../framework.nix { };
  shared = import ./shared.nix;
  inherit (shared) enum types Color Position;
in
fw.runAll [
  # === invalid type names ===
  { name = "error.typeName.01-hyphen-rejected";
    test = fw.assertThrows "error.typeName.01"
      (enum "Foo-Bar" [ "X" ]); }
  { name = "error.typeName.02-generic-syntax-rejected";
    test = fw.assertThrows "error.typeName.02"
      (enum "Foo<T>" [ "X" ]); }
  { name = "error.typeName.03-leading-digit-rejected";
    test = fw.assertThrows "error.typeName.03"
      (enum "1st" [ "X" ]); }
  { name = "error.typeName.04-empty-string-rejected";
    test = fw.assertThrows "error.typeName.04"
      (enum "" [ "X" ]); }
  { name = "error.typeName.05-with-space-rejected";
    test = fw.assertThrows "error.typeName.05"
      (enum "With Space" [ "X" ]); }
  { name = "error.typeName.06-special-char-rejected";
    test = fw.assertThrows "error.typeName.06"
      (enum "Foo@Bar" [ "X" ]); }

  # === invalid variants type ===
  { name = "error.variants.01-int-rejected";
    test = fw.assertThrows "error.variants.01"
      (enum "Bad" 42); }
  { name = "error.variants.02-string-rejected";
    test = fw.assertThrows "error.variants.02"
      (enum "Bad" "nope"); }
  { name = "error.variants.03-bool-rejected";
    test = fw.assertThrows "error.variants.03"
      (enum "Bad" true); }
  { name = "error.variants.04-null-rejected";
    test = fw.assertThrows "error.variants.04"
      (enum "Bad" null); }
  { name = "error.variants.05-lambda-rejected";
    test = fw.assertThrows "error.variants.05"
      (enum "Bad" (x: x)); }

  # === empty variants ===
  { name = "error.variants.06-empty-list-unit-enum";
    test = (enum "Empty" [ ]) ? __meta__; }

  # === type mismatch on enum-typed variant ===
  { name = "error.mismatch.01-passing-wrong-enum-inst";
    test = fw.assertThrows "error.mismatch.01"
      (let S = shared.enum "S" { C = Color; }; in S.C Position.local); }

  # === validator-fn failure paths ===
  { name = "error.validator.01-returning-false-throws";
    test = fw.assertThrows "error.validator.01"
      (let E = shared.enum "V" { Bad = _: false; }; in E.Bad { x = 1; }); }
  { name = "error.validator.02-returning-enum-type-throws";
    test = fw.assertThrows "error.validator.02"
      (let E = shared.enum "V" { Bad = _: Color; }; in E.Bad { x = 1; }); }
  { name = "error.validator.03-returning-instance-throws";
    test = fw.assertThrows "error.validator.03"
      (let E = shared.enum "V" { Bad = _: Color.Red; }; in E.Bad { x = 1; }); }
  { name = "error.validator.04-returning-int-throws";
    test = fw.assertThrows "error.validator.04"
      (let E = shared.enum "V" { Bad = _: 42; }; in E.Bad { x = 1; }); }
  { name = "error.validator.05-throw-attr-passes-message";
    test = fw.assertThrows "error.validator.05"
      (let E = shared.enum "V" { Bad = _: { __throw__ = "custom error"; }; }; in E.Bad { x = 1; }); }

  # === unsupported variant descriptor ===
  { name = "error.descriptor.01-unsupported-attrset-descriptor-stores-as-literal";
    test =
      let
        E = shared.enum "E" { V = { a = 1; }; };
      in E.V.value.a == 1; }
]
