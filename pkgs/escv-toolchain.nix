# pkgs/escv-toolchain.nix
# Dedicated bare-metal toolchain for eSC-V core (RV32I + Zicsr + Zicfilp + Zicfiss)
# Single-target (non-multilib), built exclusively with Newlib Nano.

{ nixpkgs, system }:

let
  targetTriple = "riscv32-none-elf";
  targetArch = "rv32i_zicsr_zicfilp_zicfiss";
  targetAbi = "ilp32";
  targetCflags = "-Os -ffunction-sections -fdata-sections -fomit-frame-pointer -fcf-protection=full";

  crossPkgs = import nixpkgs {
    inherit system;
    crossSystem = {
      config = targetTriple;
      libc = "newlib";
      gcc = {
        arch = targetArch;
        abi = targetAbi;
      };
    };
  };

  newlibNano = (crossPkgs.newlib.override { nanoizeNewlib = true; }).overrideAttrs (old: {
    preConfigure = ''
      ${old.preConfigure or ""}
      export CFLAGS_FOR_TARGET="${targetCflags}"
    '';
  });

  cleanCc = crossPkgs.stdenv.cc.overrideAttrs (old: {
    postFixup = (old.postFixup or "") + ''
      find $out/nix-support -type f -exec sed -i "s|${crossPkgs.newlib}|${newlibNano}|g" {} +
    '';
  });

  toolchainBundle = crossPkgs.symlinkJoin {
    name = "${targetTriple}-escv-toolchain";
    paths = [
      cleanCc
      crossPkgs.buildPackages.binutils
      crossPkgs.buildPackages.gdb
      newlibNano
    ];
  };

  envVars = {
    CROSS_COMPILE = "${targetTriple}-";
    RISCV_ARCH = targetArch;
    RISCV_ABI = targetAbi;
    TARGET_CFLAGS = targetCflags;
    NIX_CFLAGS_COMPILE = "-B${toolchainBundle}/${targetTriple}/lib";
    NIX_LDFLAGS = "-L${toolchainBundle}/${targetTriple}/lib";
    NIX_HARDENING_ENABLE = "0";
  };
in
{
  cc = toolchainBundle;
  bundle = toolchainBundle;
  gcc = crossPkgs.buildPackages.gcc;
  gdb = crossPkgs.buildPackages.gdb;
  binutils = crossPkgs.buildPackages.binutils;
  newlib = newlibNano;
  envVars = envVars;
}
