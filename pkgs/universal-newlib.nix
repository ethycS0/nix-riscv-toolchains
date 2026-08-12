# pkgs/universal-newlib.nix
{ nixpkgs, system }:

let
  targetTriple = "riscv64-none-elf";

  crossPkgs = import nixpkgs {
    inherit system;
    crossSystem = {
      config = targetTriple;
      libc = "newlib";
    };
  };

  lib = crossPkgs.lib;

  multilibs = [
    {
      arch = "rv32imac_zicfilp_zicfiss";
      abi = "ilp32";
    }
    {
      arch = "rv64imac_zicfilp_zicfiss";
      abi = "lp64";
    }
  ];

  multilibGeneratorList = lib.concatMapStringsSep ";" (m: "${m.arch}-${m.abi}--") multilibs;

  newlibNormal = crossPkgs.newlib.overrideAttrs (old: {
    configureFlags = (old.configureFlags or [ ]) ++ [ "--enable-multilib" ];
    preConfigure = ''
      ${old.preConfigure or ""}
      export CFLAGS_FOR_TARGET="-O2 -ffunction-sections -fdata-sections -fomit-frame-pointer"
    '';
  });

  patchMultilib =
    drv:
    drv.overrideAttrs (old: {
      configureFlags =
        (lib.filter (
          f:
          f != "--disable-multilib"
          && !(lib.hasPrefix "--with-arch=" f)
          && !(lib.hasPrefix "--with-abi=" f)
          && !(lib.hasPrefix "--with-headers=" f)
          && !(lib.hasPrefix "--with-native-system-header-dir=" f)
        ) (old.configureFlags or [ ]))
        ++ [
          "--enable-multilib"
          "--with-multilib-generator=${multilibGeneratorList}"
          "--with-headers=${newlibNormal}/riscv64-none-elf/include"
          "--with-native-system-header-dir=${newlibNormal}/riscv64-none-elf/include"
        ];
      nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ crossPkgs.buildPackages.python3 ];
      postPatch = ''
        ${old.postPatch or ""}
        echo ">>> multilib-generator patch: searching from $(pwd)"
        find . -name multilib-generator -print
        patchShebangs gcc/config/riscv/multilib-generator
        head -1 gcc/config/riscv/multilib-generator
      '';
    });

  candidateCc = crossPkgs.stdenv.cc.cc;

  looksRight =
    (lib.hasSuffix "-gcc" (candidateCc.pname or "") || (candidateCc.pname or "") == "gcc")
    && (lib.any (f: lib.hasPrefix "--target=${targetTriple}" f) (candidateCc.configureFlags or [ ]));

  verifiedCc =
    if looksRight then
      candidateCc
    else
      throw ''
        universal-toolchain.nix: crossPkgs.stdenv.cc.cc does not look like the
        ${targetTriple} cross-gcc stage (pname=${candidateCc.pname or "?"}).
      '';

  patchedGccUnwrapped = patchMultilib verifiedCc;

  patchedCc = crossPkgs.stdenv.cc.override {
    cc = patchedGccUnwrapped;
  };

  cleanCc = patchedCc.overrideAttrs (old: {
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

  debug = {
    inherit candidateCc patchedGccUnwrapped;
  };
}
