{
  description = "Centralized RISC-V Cross-Compilation Toolchains";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      ...
    }:
    let
      matrix = import ./lib/target-matrix.nix;
      mkToolchain = args: import ./pkgs/mkToolchain.nix args;
    in
    {
      lib = {
        inherit mkToolchain;
        targetMatrix = matrix;
      };
    }
    //
      flake-utils.lib.eachSystem
        [
          "x86_64-linux"
          "aarch64-linux"
          "aarch64-darwin"
        ]
        (
          system:
          let
            pkgs = nixpkgs.legacyPackages.${system};

            toolchains = pkgs.lib.mapAttrs (
              name: spec:
              mkToolchain {
                inherit nixpkgs system;
                targetSpec = spec;
              }
            ) matrix.targets;
          in
          {
            packages = pkgs.lib.mapAttrs' (name: tc: pkgs.lib.nameValuePair name tc.bundle) toolchains;

            devShells = pkgs.lib.mapAttrs (
              name: tc:
              pkgs.mkShell {
                name = "riscv-env-${name}";
                packages = [
                  tc.bundle
                ];
                env = tc.envVars;
                shellHook = "";
              }
            ) toolchains;
          }
        );
}
