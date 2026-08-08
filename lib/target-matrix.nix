{
  targets = {
    # Standard Targets
    "rv32i-zicsr" = {
      arch = "rv32i_zicsr";
      abi = "ilp32";
      config = "riscv32-none-elf";
      targetCflags = "";
    };

    "rv32g-standard" = {
      arch = "rv32g";
      abi = "ilp32d";
      config = "riscv32-none-elf";
      targetCflags = "";
    };

    "rv64g-standard" = {
      arch = "rv64g";
      abi = "lp64d";
      config = "riscv64-none-elf";
      targetCflags = "";
    };

    # CFI Targets
    "rv32i-cfi" = {
      arch = "rv32i_zicsr_zicfilp_zicfiss";
      abi = "ilp32";
      config = "riscv32-none-elf";
      targetCflags = "-O2 -fcf-protection=full";
    };

    "rv32g-cfi" = {
      arch = "rv32g_zicfilp_zicfiss";
      abi = "ilp32d";
      config = "riscv32-none-elf";
      targetCflags = "-O2 -fcf-protection=full";
    };

    "rv64g-cfi" = {
      arch = "rv64g_zicfilp_zicfiss";
      abi = "lp64d";
      config = "riscv64-none-elf";
      targetCflags = "-O2 -fcf-protection=full";
    };
  };
}
