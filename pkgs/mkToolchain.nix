# pkgs/mkToolchain.nix
{
  nixpkgs,
  system,
  targetSpec ? null,
  arch ? null,
  abi ? null,
  config ? null,
  cfi ? false,
  targetCflags ? "",
}:

let
  resolvedSpec =
    if targetSpec != null then
      targetSpec
    else
      let
        safeArch = if arch != null then arch else "";
        is64 = (builtins.match ".*64.*" safeArch) != null;
        defaultConfig = if is64 then "riscv64-none-elf" else "riscv32-none-elf";
        defaultAbi = if is64 then "lp64d" else "ilp32";
        cfiArch =
          if cfi && (builtins.match ".*zicfilp.*" safeArch == null) then
            "${safeArch}_zicfilp_zicfiss"
          else
            safeArch;
        cfiFlags = if cfi then "-O2 -fcf-protection=full ${targetCflags}" else targetCflags;
      in

      {
        arch = cfiArch;
        abi = if abi != null then abi else defaultAbi;
        config = if config != null then config else defaultConfig;
        targetCflags = cfiFlags;
      };

  targetTriple = resolvedSpec.config;
  hasCfiFlags = (resolvedSpec.targetCflags or "") != "";

  standardCflags = "-O2 -ffunction-sections -fdata-sections -fomit-frame-pointer ${
    resolvedSpec.targetCflags or ""
  }";
  nanoCflags = "-Os -ffunction-sections -fdata-sections -fomit-frame-pointer ${
    resolvedSpec.targetCflags or ""
  }";

  crossPkgs = import nixpkgs {
    inherit system;
    crossSystem = {
      config = resolvedSpec.config;
      libc = "newlib";
      gcc = {
        arch = resolvedSpec.arch;
        abi = resolvedSpec.abi;
      };
    };
  };

  gccCc = crossPkgs.stdenv.cc.cc;
  gccVersion = gccCc.version;

  # Standard Newlib (-O2)
  newlibNormal = crossPkgs.newlib.overrideAttrs (old: {
    preConfigure = ''
      ${old.preConfigure or ""}
      export CFLAGS_FOR_TARGET="${standardCflags}"
    '';
    postInstall = ''
      ${old.postInstall or ""}
      rm -f $out/${targetTriple}/lib/nano.specs
    '';
  });

  # Nano Newlib build (-Os)
  newlibNanoRaw = (crossPkgs.newlib.override { nanoizeNewlib = true; }).overrideAttrs (old: {
    preConfigure = ''
      ${old.preConfigure or ""}
      export CFLAGS_FOR_TARGET="${nanoCflags}"
    '';
    postInstall = ''
      ${old.postInstall or ""}
      rm -f $out/${targetTriple}/lib/nano.specs
    '';
  });

  # Processed Newlib Nano derivation
  newlibNano = crossPkgs.stdenvNoCC.mkDerivation {
    pname = "${targetTriple}-newlib-nano-processed";
    version = "1";
    dontUnpack = true;

    installPhase = ''
      mkdir -p $out/${targetTriple}/lib/newlib-nano
      mkdir -p $out/${targetTriple}/lib
      mkdir -p $out/${targetTriple}/include/newlib-nano

      # Copy all headers from newlibNanoRaw
      find ${newlibNanoRaw} -type f -name "*.h" | while read -r header; do
        rel=$(echo "$header" | sed -n 's|.*/include/||p')
        if [ -n "$rel" ]; then
          mkdir -p "$out/${targetTriple}/include/newlib-nano/$(dirname "$rel")"
          cp "$header" "$out/${targetTriple}/include/newlib-nano/$rel"
        else
          cp "$header" "$out/${targetTriple}/include/newlib-nano/"
        fi
      done

      # Copy all static libraries from newlibNanoRaw
      find ${newlibNanoRaw} -type f -name "*.a" | while read -r libfile; do
        cp -L "$libfile" $out/${targetTriple}/lib/newlib-nano/
      done

      chmod -R u+w $out

      # Create _nano.a aliases inside newlib-nano directory
      cd $out/${targetTriple}/lib/newlib-nano
      for lib in *.a; do
        [ -f "$lib" ] || continue
        base=$(basename "$lib" .a)
        if [[ "$base" != *"_nano" ]]; then
          cp "$lib" "''${base}_nano.a"
        fi
      done

      # Mirror libraries to main lib directory for path compatibility
      cp -r * $out/${targetTriple}/lib/

      # Provide stubs for gloss and nosys if omitted
      for stub in libgloss.a libgloss_nano.a libnosys.a libnosys_nano.a; do
        if [ ! -f "$out/${targetTriple}/lib/newlib-nano/$stub" ]; then
          ${crossPkgs.buildPackages.binutils}/bin/${targetTriple}-ar rcs "$out/${targetTriple}/lib/newlib-nano/$stub"
          cp "$out/${targetTriple}/lib/newlib-nano/$stub" "$out/${targetTriple}/lib/$stub"
        fi
      done
    '';
  };

  # Clean GCC wrapper (strips frame-pointer flags, directs libc flags to newlibNormal)
  cleanCc = crossPkgs.stdenv.cc.overrideAttrs (old: {
    postFixup = (old.postFixup or "") + ''
      find $out/nix-support -type f -exec sed -i "s|${crossPkgs.newlib}|${newlibNormal}|g" {} +
      if [ -f $out/nix-support/libc-crt1-cflags ]; then
        echo "-B${nanoSpecs}/${targetTriple}/lib" >> $out/nix-support/libc-crt1-cflags
      fi
      if [ -f $out/nix-support/cc-cflags-before ]; then
        sed -i 's/-fno-omit-frame-pointer//g; s/-mno-omit-leaf-frame-pointer//g' $out/nix-support/cc-cflags-before
      fi
    '';
  });

  # nano.specs using -nostdinc to neutralize Nix wrapper header pollution
  nanoSpecs = crossPkgs.writeTextDir "${targetTriple}/lib/nano.specs" ''
    %rename cpp                 nano_cpp
    %rename link                nano_link
    %rename lib                 nano_lib

    *cpp:
    -nostdinc -isystem ${newlibNano}/${targetTriple}/include/newlib-nano -isystem ${newlibNormal}/${targetTriple}/include -isystem ${gccCc}/lib/gcc/${targetTriple}/${gccVersion}/include -isystem ${gccCc}/lib/gcc/${targetTriple}/${gccVersion}/include-fixed %(nano_cpp) -D_REENT_SMALL -D_LITE_EXIT

    *link:
    %(nano_link) -L${newlibNano}/${targetTriple}/lib/newlib-nano -L${newlibNormal}/${targetTriple}/lib %:replace-outfile(-lc -lc_nano) %:replace-outfile(-lg -lg_nano) %:replace-outfile(-lm -lm_nano) --gc-sections

    *lib:
    %{!shared:%{g*:-lg_nano} %{!g*:-lc_nano}}
  '';

  toolchainBundle = crossPkgs.symlinkJoin {
    name = "${targetTriple}-${resolvedSpec.arch}-toolchain-bundle";
    paths = [
      cleanCc
      crossPkgs.buildPackages.binutils
      crossPkgs.buildPackages.gdb
      nanoSpecs
      newlibNano
      newlibNormal
    ];
  };

  envVars = {
    CROSS_COMPILE = "${resolvedSpec.config}-";
    RISCV_ARCH = resolvedSpec.arch;
    RISCV_ABI = resolvedSpec.abi;
    TARGET_CFLAGS = resolvedSpec.targetCflags or "";
    NIX_CFLAGS_COMPILE = "-B${toolchainBundle}/${targetTriple}/lib";
    NIX_LDFLAGS = "-L${toolchainBundle}/${targetTriple}/lib";
    NIX_HARDENING_ENABLE = "0";
  };

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
