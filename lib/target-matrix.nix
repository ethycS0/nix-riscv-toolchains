{
  targets = {
    # Standard Targets
    "rv32i-zicsr" = {
      arch = "rv32i_zicsr";
      abi = "ilp32";
      config = "riscv32-none-elf";
      targetCflags = "";
    };

    "rv32imac-standard" = {
      arch = "rv32imac_zicsr";
      abi = "ilp32";
      config = "riscv32-none-elf";
      targetCflags = "";
    };

    "rv64imac-standard" = {
      arch = "rv64imac_zicsr";
      abi = "lp64";
      config = "riscv64-none-elf";
      targetCflags = "";
    };

    # CFI Hardened Targets
    "rv32i-cfi" = {
      arch = "rv32i_zicsr_zicfilp_zicfiss";
      abi = "ilp32";
      config = "riscv32-none-elf";
      targetCflags = "-O2 -fcf-protection=full";
    };

    "rv32imac-cfi" = {
      arch = "rv32imac_zicsr_zicfilp_zicfiss";
      abi = "ilp32";
      config = "riscv32-none-elf";
      targetCflags = "-O2 -fcf-protection=full";
    };

    "rv64imac-cfi" = {
      arch = "rv64imac_zicsr_zicfilp_zicfiss";
      abi = "lp64";
      config = "riscv64-none-elf";
      targetCflags = "-O2 -fcf-protection=full";
    };
  };
}
