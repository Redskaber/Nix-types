# @path: test/cases/version.nix
# @description: Version identity — `lib.version` is a machine contract,
#               not a README string. Locked here so a release that
#               forgets to bump it goes red before any downstream
#               truthfulness assertion fires.
#
# Laws:
#   V1. exists     — `version` is a top-level string export.
#   V2. semver     — exactly major.minor.patch, all digits, no suffix
#                    (downstream `==` assertions stay simple).
#   V3. pinned     — the value matches this suite's expectation; a
#                    bump that leaves the suite stale is caught by V3,
#                    a suite bumped without a release by the same token
#                    (the truthfulness discipline nix-config applies to
#                    pinned revs, applied at home).
#   V4. boundary   — the identity string never leaks into enum types
#                    or instances (the v3.0 `__meta__` cleanup line:
#                    metadata travels in `__meta__`, version travels
#                    only at the top level).

let
  fw = import ../framework.nix { };
  libMod = import ../../lib/default.nix;

  parts = builtins.splitVersion libMod.version;

  Color = libMod.enum "Color" [
    "Red"
    "Green"
    "Blue"
  ];
in
fw.runAll [
  {
    name = "version.01-exists-as-top-level-string";
    test = builtins.isString libMod.version;
  }

  {
    name = "version.02-semver-shape-major-minor-patch-digits";
    test =
      builtins.length parts == 3 && builtins.all (p: p != "" && builtins.match "[0-9]+" p != null) parts;
  }

  {
    name = "version.03-pinned-value-truthfulness";
    test = libMod.version == "3.6.0";
  }

  {
    name = "version.04-no-leak-into-enum-type-namespace";
    test = !(builtins.hasAttr "version" Color);
  }

  {
    name = "version.05-no-leak-into-instance-record";
    test = !(builtins.hasAttr "version" Color.Red);
  }

  {
    name = "version.06-instance-meta-still-carries-only-typename-variants";
    # `__meta__` stays the enum identity record (typename/variantNames) —
    # the version identity lives at the library top level and nowhere else.
    test =
      let
        meta = Color.Red.__meta__;
      in
      builtins.isAttrs meta
      && builtins.hasAttr "typename" meta
      && builtins.hasAttr "variantNames" meta
      && !(builtins.hasAttr "version" meta);
  }
]
