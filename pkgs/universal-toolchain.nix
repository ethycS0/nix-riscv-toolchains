# pkgs/universal-toolchain.nix

{ nixpkgs, system }:

let
  lib = nixpkgs.lib;
  targetTriple = "riscv64-none-elf";

  multilibs = [
    {
      arch = "rv32i_zicsr_zicfilp_zicfiss";
      abi = "ilp32";
    }
    {
      arch = "rv32imac_zicsr_zifencei_zicfilp_zicfiss";
      abi = "ilp32";
    }
    {
      arch = "rv64imac_zicsr_zifencei_zicfilp_zicfiss";
      abi = "lp64";
    }
    {
      arch = "rv64g_zicfilp_zicfiss";
      abi = "lp64d";
    }
  ];

  multilibGeneratorList = nixpkgs.lib.concatMapStringsSep ";" (m: "${m.arch}-${m.abi}--") multilibs;

  crossPkgs = import nixpkgs {
    inherit system;
    crossSystem = {
      config = targetTriple;
      libc = "newlib";
      multilib = true;
      gcc = {
        arch = "rv64imac_zicfilp_zicfiss";
        abi = "lp64";
      };
    };
    overlays = [
      (self: super: {
        gcc-unwrapped = super.gcc-unwrapped.overrideAttrs (
          old:
          let
            targetConfig = self.stdenv.targetPlatform.config or self.stdenv.hostPlatform.config;
            isRiscvCrossTarget = targetConfig == targetTriple;
          in
          lib.optionalAttrs isRiscvCrossTarget {
            configureFlags = (old.configureFlags or [ ]) ++ [
              "--enable-multilib"
              "--with-multilib-generator=${multilibGeneratorList}"
            ];
          }
        );
      })
    ];
  };

  newlibNormal = crossPkgs.newlib.overrideAttrs (old: {
    configureFlags = (old.configureFlags or [ ]) ++ [ "--enable-multilib" ];
    preConfigure = ''
      ${old.preConfigure or ""}
      export CFLAGS_FOR_TARGET="-O2 -ffunction-sections -fdata-sections -fomit-frame-pointer"
    '';
  });

  cleanCc = crossPkgs.stdenv.cc.overrideAttrs (old: {
    postFixup = (old.postFixup or "") + ''
      find $out/nix-support -type f -exec sed -i "s|${crossPkgs.newlib}|${newlibNormal}|g" {} +
    '';
  });

  toolchainBundle = crossPkgs.symlinkJoin {
    name = "${targetTriple}-universal-multilib-toolchain";
    paths = [
      cleanCc
      crossPkgs.buildPackages.binutils
      crossPkgs.buildPackages.gdb
      newlibNormal
    ];
  };
in
{
  cc = toolchainBundle;
  bundle = toolchainBundle;
  gcc = crossPkgs.buildPackages.gcc;
  gdb = crossPkgs.buildPackages.gdb;
  binutils = crossPkgs.buildPackages.binutils;
  newlib = newlibNormal;
  envVars = {
    CROSS_COMPILE = "${targetTriple}-";
  };
}
