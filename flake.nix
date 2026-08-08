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
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        matrix = import ./lib/target-matrix.nix;

        toolchains = pkgs.lib.mapAttrs (
          name: spec:
          import ./pkgs/mkToolchain.nix {
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
