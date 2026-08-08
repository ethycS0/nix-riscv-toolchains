{
  nixpkgs,
  system,
  targetSpec,
}:

let
  hasTargetFlags = (targetSpec.targetCflags or "") != "";

  cflagsOverlay = final: prev: {
    newlib = prev.newlib.overrideAttrs (oldAttrs: {
      preConfigure = ''
        ${oldAttrs.preConfigure or ""}
        export CFLAGS_FOR_TARGET="${targetSpec.targetCflags}"
      '';
    });
  };

  crossPkgs = import nixpkgs {
    inherit system;
    overlays = if hasTargetFlags then [ cflagsOverlay ] else [ ];
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

  newlibNano = crossPkgs.newlib.overrideAttrs (old: {
    pname = (old.pname or "newlib") + "-nano";

    configureFlags = (old.configureFlags or [ ]) ++ [
      "--enable-newlib-reent-small"
      "--enable-newlib-nano-malloc"
      "--enable-newlib-nano-formatted-io"
      "--enable-lite-exit"
      "--enable-newlib-global-atexit"
      "--disable-newlib-fseek-optimization"
      "--disable-newlib-supplied-syscalls"
      "--disable-nls"
    ];

    preConfigure = ''
      ${old.preConfigure or ""}
      export CFLAGS_FOR_TARGET="-Os -ffunction-sections -fdata-sections ${targetSpec.targetCflags}"
    '';

    postInstall = ''
      ${old.postInstall or ""}

      # 1. Recursively find every .a library and create a _nano.a variant alongside it
      find $out -name "*.a" | while read -r lib; do
        dir=$(dirname "$lib")
        base=$(basename "$lib" .a)
        if [[ "$base" != *"_nano" ]]; then
          cp "$lib" "$dir/''${base}_nano.a"
        fi
      done

      # 2. Create empty stub archives for libgloss / libnosys if omitted by --disable-newlib-supplied-syscalls
      find $out -type d -name "lib" | while read -r libdir; do
        for stub in libgloss_nano.a libnosys_nano.a libgloss.a libnosys.a; do
          if [ ! -f "$libdir/$stub" ]; then
            ${crossPkgs.buildPackages.binutils}/bin/${targetTriple}-ar rcs "$libdir/$stub"
          fi
        done
      done
    '';
  });

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
      crossPkgs.newlib
      newlibNano
      nanoSpecs
    ];
  };
in
{
  cc = toolchainBundle;
  bundle = toolchainBundle;
  gcc = crossPkgs.buildPackages.gcc;
  gdb = crossPkgs.buildPackages.gdb;
  binutils = crossPkgs.buildPackages.binutils;
  newlib = crossPkgs.newlib;
  newlibNano = newlibNano;

  envVars = {
    CROSS_COMPILE = "${targetSpec.config}-";
    RISCV_ARCH = targetSpec.arch;
    RISCV_ABI = targetSpec.abi;
    NIX_CFLAGS_COMPILE = "-B${toolchainBundle}/${targetTriple}/lib";
    NIX_LDFLAGS = "-L${toolchainBundle}/${targetTriple}/lib";
  }
  // (
    if hasTargetFlags then
      {
        CFLAGS = targetSpec.targetCflags;
      }
    else
      { }
  );
}
