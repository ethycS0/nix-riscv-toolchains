{
  nixpkgs,
  system,
  targetSpec,
}:

let
  hasTargetFlags = (targetSpec.targetCflags or "") != "";

  # Overlay to re-compile Newlib with CFI flags when needed
  cflagsOverlay = final: prev: {
    newlib = prev.newlib.overrideAttrs (oldAttrs: {
      preConfigure = ''
        export CFLAGS_FOR_TARGET="${targetSpec.targetCflags}"
        ${oldAttrs.preConfigure or ""}
      '';
    });
  };

  # Instantiate nixpkgs specifically for this target configuration
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
in
{
  # The cross-compiler wrapper (includes toolchain + built newlib sysroot)
  cc = crossPkgs.stdenv.cc;
  gcc = crossPkgs.buildPackages.gcc;
  gdb = crossPkgs.buildPackages.gdb;
  newlib = crossPkgs.newlib;

  # Standard environment variables exported to consumer shells
  envVars = {
    CROSS_COMPILE = "${targetSpec.config}-";
    RISCV_ARCH = targetSpec.arch;
    RISCV_ABI = targetSpec.abi;
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
