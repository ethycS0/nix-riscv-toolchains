# pkgs/universal-toolchain.nix

{ nixpkgs, system }:

let
  targetTriple = "riscv64-none-elf";
  targetArch = "rv64g_zicfilp_zicfiss";
  targetAbi = "lp64d";
  targetCflags = "-O2 -ffunction-sections -fdata-sections -fomit-frame-pointer -fcf-protection=full";

  crossPkgs = import nixpkgs {
    inherit system;
    crossSystem = {
      config = targetTriple;
      libc = "newlib";
      multilib = true;
      gcc = {
        arch = targetArch;
        abi = targetAbi;
      };
    };
  };

  newlibNormal = crossPkgs.newlib.overrideAttrs (old: {
    preConfigure = ''
      ${old.preConfigure or ""}
      export CFLAGS_FOR_TARGET="${targetCflags}"
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

  envVars = {
    CROSS_COMPILE = "${targetTriple}-";
    RISCV_ARCH = targetArch;
    RISCV_ABI = targetAbi;
    TARGET_CFLAGS = targetCflags;
  };
in
{
  cc = toolchainBundle;
  bundle = toolchainBundle;
  gcc = crossPkgs.buildPackages.gcc;
  gdb = crossPkgs.buildPackages.gdb;
  binutils = crossPkgs.buildPackages.binutils;
  newlib = newlibNormal;
  envVars = envVars;
}
