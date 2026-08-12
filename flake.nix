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
          newlibToolchain = import ./pkgs/universal-newlib.nix { inherit nixpkgs system; };
        in
        {
          packages = {
            escv = escvToolchain.bundle;
            universal-newlib = newlibToolchain.bundle;
            default = escvToolchain.bundle;
          };

          devShells = {
            escv = pkgs.mkShell {
              name = "riscv-escv-shell";
              packages = [ escvToolchain.bundle ];
              env = escvToolchain.envVars;
            };

            universal-newlib = pkgs.mkShell {
              name = "riscv-universal-shell";
              packages = [ newlibToolchain.bundle ];
              env = newlibToolchain.envVars;
            };

            default = self.devShells.${system}.escv;
          };
        }
      );
}
