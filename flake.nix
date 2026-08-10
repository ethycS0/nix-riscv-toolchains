{
  description = "nix-cfi-riscv-toolchains";

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

          escvToolchain = import ./pkgs/escv-toolchain.nix { inherit nixpkgs system; };
          universalToolchain = import ./pkgs/universal-toolchain.nix { inherit nixpkgs system; };
        in
        {
          packages = {
            escv = escvToolchain.bundle;
            universal = universalToolchain.bundle;
            default = escvToolchain.bundle;
          };

          devShells = {
            escv = pkgs.mkShell {
              name = "riscv-escv-shell";
              packages = [ escvToolchain.bundle ];
              env = escvToolchain.envVars;
            };

            universal = pkgs.mkShell {
              name = "riscv-universal-shell";
              packages = [ universalToolchain.bundle ];
              env = universalToolchain.envVars;
            };

            default = self.devShells.${system}.escv;
          };
        }
      );
}
