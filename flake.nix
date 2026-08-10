# @path: flake.nix
# @description: Modern zero-input flake for nix-types.
#
# The library itself is pure Nix (no nixpkgs needed). The flake wrappers
# (packages, checks, apps, devShells) need `nixpkgs` for derivation builders
# like `runCommand` and `writeShellScript`; we use `<nixpkgs>` to keep the
# flake input-free. If you prefer a flake-locked nixpkgs, add it to `inputs`.
#
# Exposes:
#   lib                       — the library (importable: `nix eval .#lib.enum`)
#   packages.<sys>.default    — store-path derivation of the library
#   packages.<sys>.test       — derivation whose build runs the test suite
#   checks.<sys>.testSuite    — same as above, for `nix flake check`
#   apps.<sys>.test           — `nix run .#test` prints a summary
#   apps.<sys>.demo           — `nix run .#demo` prints an API overview
#   devShells.<sys>.default   — `nix develop` shell with nix + jq

{
  description = "Pure-Nix ADT & pattern-matching type library";

  inputs = { };

  outputs = { self, ... }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = f: builtins.listToAttrs (map (sys: { name = sys; value = f sys; }) systems);

      lib = import ./lib;

      pkgsFor = sys: import <nixpkgs> { system = sys; };

      mkLibDerivation = pkgs: pkgs.runCommand "nix-types" { } ''
        mkdir -p $out
        cp -r ${./.}/lib $out/lib
        cp ${./.}/flake.nix $out/flake.nix
        cp ${./.}/README.md $out/README.md
        cp ${./.}/LICENSE $out/LICENSE
      '';

      mkTestDerivation = pkgs:
        let result = (import ./test).allPassed; in
        pkgs.runCommand "nix-types-test"
          { passAsFile = [ "assertion" ];
            assertion = if result then "ALL PASSED" else "SOME FAILED"; }
          ''
            [ "$assertion" = "ALL PASSED" ] || { echo "Tests failed!"; exit 1; }
            touch $out
          '';

      mkTestApp = pkgs: {
        type = "app";
        program = toString (pkgs.writeShellScript "nix-types-test" ''
          ${pkgs.nix}/bin/nix eval --impure --file ${./test/default.nix} summary --json \
            | ${pkgs.jq}/bin/jq -r '"nix-types: \(.passed)/\(.total) tests passed\n" + (if .allPassed then "ALL PASSED" else "\(.failed) FAILED")'
        '');
      };

      mkDemoApp = pkgs: {
        type = "app";
        program = toString (pkgs.writeShellScript "nix-types-demo" ''
          cat <<'EOF'
=== nix-types v3.4 demo ===

1) Unit enum:
   Color = enum "Color" [ "Red" "Green" "Blue" ];
   Color.Red.tag        -> "Red"
   ''${Color.Red}       -> "enum::Color::Red"   (string interpolation works!)

2) Postable enum:
   Shape = enum "Shape" {
     Circle = Color;
     Square = [ Color Color Color ];
   };
   (Shape.Circle Color.Red).display -> "enum::Shape::Circle(enum::Color::Red)"

3) Pattern match:
   match Color.Red { Red = v: "r"; _ = v: "other"; }  -> "r"

4) ADT library:
   some 42; none; ok 42; err "fail";
   option.unwrap (some 42)         -> 42
   result.map (x: x+1) (ok 41)     -> Ok(42)

Run tests:  nix run .#test
Open REPL:  nix repl :l lib/default.nix
EOF
        '');
      };

      mkDevShell = pkgs: pkgs.mkShell {
        packages = with pkgs; [ nix jq ];
        shellHook = ''
          echo "nix-types dev shell"
          echo "  ./scripts/run-tests.sh        # run tests"
          echo "  nix eval --impure --file ./lib/default.nix  # inspect library"
        '';
      };
    in
    {
      inherit lib;

      packages = forAllSystems (sys: let pkgs = pkgsFor sys; in {
        default = mkLibDerivation pkgs;
        test = mkTestDerivation pkgs;
      });

      checks = forAllSystems (sys: let pkgs = pkgsFor sys; in {
        testSuite = mkTestDerivation pkgs;
      });

      apps = forAllSystems (sys: let pkgs = pkgsFor sys; in {
        test = mkTestApp pkgs;
        demo = mkDemoApp pkgs;
      });

      devShells = forAllSystems (sys: let pkgs = pkgsFor sys; in {
        default = mkDevShell pkgs;
      });
    };
}
