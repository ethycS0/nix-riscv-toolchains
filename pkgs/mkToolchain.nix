# pkgs/mkToolchain.nix
{
  nixpkgs,
  system,
  targetSpec,
}:

let
  hasCfiFlags = (targetSpec.targetCflags or "") != "";

  cfiOverlay = final: prev: {
    newlib = prev.newlib.overrideAttrs (old: {
      preConfigure = ''
        ${old.preConfigure or ""}
        export CFLAGS_FOR_TARGET="${targetSpec.targetCflags}"
      '';
    });
  };

  crossPkgs = import nixpkgs {
    inherit system;
    overlays = if hasCfiFlags then [ cfiOverlay ] else [ ];
    crossSystem = {
      config = targetSpec.config;
      libc = "newlib";
      gcc = {
        arch = targetSpec.arch;
        abi = targetSpec.abi;
      };
    };
  };

  targetTriple = targetSpec.config;

  newlibNormal = crossPkgs.newlib;
  newlibNanoRaw = crossPkgs.newlib.override { nanoizeNewlib = true; };

  newlibNano = crossPkgs.stdenvNoCC.mkDerivation {
    pname = "${targetTriple}-newlib-nano-renamed";
    version = "1";
    dontUnpack = true;

    installPhase = ''
      mkdir -p $out
      cp -r ${newlibNanoRaw}/. $out/
      chmod -R u+w $out

      find $out -name "*.a" | while read -r lib; do
        dir=$(dirname "$lib")
        base=$(basename "$lib" .a)
        if [[ "$base" != *"_nano" ]]; then
          mv "$lib" "$dir/''${base}_nano.a"
        fi
      done

      find $out -type d -name "lib" | while read -r libdir; do
        for stub in libgloss_nano.a libnosys_nano.a; do
          if [ ! -f "$libdir/$stub" ]; then
            ${crossPkgs.buildPackages.binutils}/bin/${targetTriple}-ar rcs "$libdir/$stub"
          fi
        done
      done
    '';
  };

  nanoSpecs = crossPkgs.writeTextDir "${targetTriple}/lib/nano.specs" ''
    %rename link                nano_link
    %rename cpp                 nano_cpp

    *cpp:
    %(nano_cpp) -D_REENT_SMALL

    *link:
    %(nano_link) -lc_nano -lm_nano -lgloss_nano -lnosys_nano
  '';

  toolchainBundle = crossPkgs.symlinkJoin {
    name = "${targetTriple}-${targetSpec.arch}-toolchain-bundle";
    paths = [
      crossPkgs.stdenv.cc
      crossPkgs.buildPackages.binutils
      crossPkgs.buildPackages.gdb
      newlibNormal
      newlibNano
      nanoSpecs
    ];
  };

  envVars = {
    CROSS_COMPILE = "${targetSpec.config}-";
    RISCV_ARCH = targetSpec.arch;
    RISCV_ABI = targetSpec.abi;
    NIX_CFLAGS_COMPILE = "-B${toolchainBundle}/${targetTriple}/lib";
    NIX_LDFLAGS = "-L${toolchainBundle}/${targetTriple}/lib";
  }
  // (if hasCfiFlags then { CFLAGS = targetSpec.targetCflags; } else { });

  toolchainBundleWithEnv = toolchainBundle.overrideAttrs (old: {
    passthru = (old.passthru or { }) // {
      inherit envVars;
    };
  });
in
{
  cc = toolchainBundleWithEnv;
  bundle = toolchainBundleWithEnv;
  gcc = crossPkgs.buildPackages.gcc;
  gdb = crossPkgs.buildPackages.gdb;
  binutils = crossPkgs.buildPackages.binutils;
  newlib = newlibNormal;
  newlibNano = newlibNano;
  envVars = envVars;
}
