# nix-riscv-toolchains

A centralized Nix Flake repository providing reproducible, pre-configured bare-metal RISC-V cross-compilation toolchains.

This repository acts as a single source of truth for both **standard** RISC-V architectures and **Control-Flow Integrity (CFI)** hardened targets (`Zicfilp` + `Zicfiss`), optimized for bare-metal processors (like `eSC-V`), RTOS development (Zephyr), and test suites (`riscv-arch-tests`).

---

## Features

- **Pre-configured Target Matrix**: Instant access to bare-metal (32-bit `ilp32`) and 64-bit (`lp64d`) cross-compilers.
- **Hardware-Enforced CFI Support**: CFI targets build **Newlib (`libc.a`, `crt0.o`)** directly with `-fcf-protection=full`, ensuring standard library functions include landing pads (`lpad`).
- **Programmable Builder API (`lib.mkToolchain`)**: Instantiate custom toolchains on the fly in downstream projects without duplicating flake logic.
- **Cachix-Friendly**: Shared `/nix/store` closure per toolchain across local projects and CI runners.

---

## Pre-configured Target Matrix

| Target Name             | Architecture (`-march`)          | ABI (`-mabi`) | Cross Config       | Primary Use Case                       |
| :---------------------- | :------------------------------- | :------------ | :----------------- | :------------------------------------- |
| **`rv32i-zicsr`**       | `rv32i_zicsr`                    | `ilp32`       | `riscv32-none-elf` | `eSC-V` baseline bare-metal            |
| **`rv32i-cfi`**         | `rv32i_zicsr_zicfilp_zicfiss`    | `ilp32`       | `riscv32-none-elf` | `eSC-V` bare-metal with CFI            |
| **`rv32imac-standard`** | `rv32imac_zicsr`                 | `ilp32`       | `riscv32-none-elf` | Zephyr RTOS / soft-float 32-bit cores  |
| **`rv32imac-cfi`**      | `rv32imac_zicsr_zicfilp_zicfiss` | `ilp32`       | `riscv32-none-elf` | Zephyr RTOS with CFI (soft-float)      |
| **`rv64g-standard`**    | `rv64g`                          | `lp64d`       | `riscv64-none-elf` | 64-bit application processors          |
| **`rv64g-cfi`**         | `rv64g_zicfilp_zicfiss`          | `lp64d`       | `riscv64-none-elf` | 64-bit application processors with CFI |

---

## Quick Start & Local Testing

### 1. Enter a Target Environment

```bash
# Enter shell for 32-bit RTOS target with CFI
nix develop .#rv32imac-cfi

# Or for 32-bit eSC-V standard I + Zicsr
nix develop .#rv32i-zicsr
```

---

## Downstream Usage (`lib.mkToolchain`)

You can import `nix-riscv-toolchains` as a flake input and generate custom targets dynamically:

```nix
{
  inputs = {
    nix-riscv-toolchains.url = "github:ethycS0/nix-riscv-toolchains";
    nixpkgs.follows = "nix-riscv-toolchains/nixpkgs";
  };

  outputs = { self, nixpkgs, nix-riscv-toolchains }:
    let
      system = "x86_64-linux";
      tc = nix-riscv-toolchains.lib.mkToolchain {
        inherit nixpkgs system;
        arch = "rv32im_zicsr";
        abi = "ilp32";
        cfi = true; # Automatically builds Newlib with -fcf-protection=full and adds zicfilp/zicfiss
      };
    in {
      devShells.${system}.default = nixpkgs.legacyPackages.${system}.mkShell {
        packages = [ tc.bundle ];
        env = tc.envVars;
      };
    };
}
```
