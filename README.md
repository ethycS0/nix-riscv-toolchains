# nix-riscv-toolchains

A centralized Nix Flake repository providing reproducible, pre-configured bare-metal RISC-V cross-compilation toolchains.

I personally have to work a lot with CFI enabled toolchains.

This eliminates per-project GCC/Newlib configuration boilerplate by acting as a single source of truth for both **standard** RISC-V architectures and **Control-Flow Integrity (CFI)** hardened targets (`Zicfilp` + `Zicfiss`).

---

## Features

- **Pre-configured Target Matrix**: Instant access to RV32I, RV32G, and RV64G cross-compilers.
- **Hardware-Enforced CFI Support**: CFI toolchain targets build **Newlib (`libc.a`, `crt0.o`)** directly with `-fcf-protection=full`, ensuring standard library functions include landing pads (`lpad`).
- **Zero-Boilerplate Downstream Integration**: Import as a Flake input in downstream projects (e.g., `riscv-arch-tests`, Zephyr, custom hardware software) to instantly enter pre-configured build environments.
- **Cachix-Friendly**: Shared `/nix/store` closure per toolchain across all your local projects and CI runners.

---

## Targets (For Now)

| Target Name          | Architecture (`-march`)       | ABI (`-mabi`) | Cross Config       | Newlib CFLAGS              |
| :------------------- | :---------------------------- | :------------ | :----------------- | :------------------------- |
| **`rv32i-zicsr`**    | `rv32i_zicsr`                 | `ilp32`       | `riscv32-none-elf` | Default                    |
| **`rv32g-standard`** | `rv32g`                       | `ilp32d`      | `riscv32-none-elf` | Default                    |
| **`rv64g-standard`** | `rv64g`                       | `lp64d`       | `riscv64-none-elf` | Default                    |
| **`rv32i-cfi`**      | `rv32i_zicsr_zicfilp_zicfiss` | `ilp32`       | `riscv32-none-elf` | `-O2 -fcf-protection=full` |
| **`rv32g-cfi`**      | `rv32g_zicfilp_zicfiss`       | `ilp32d`      | `riscv32-none-elf` | `-O2 -fcf-protection=full` |
| **`rv64g-cfi`**      | `rv64g_zicfilp_zicfiss`       | `lp64d`       | `riscv64-none-elf` | `-O2 -fcf-protection=full` |

---

## Quick Start & Local Testing

You can test any toolchain target directly from this repository without installing system-wide cross-compilers.

### 1. Enter a Target Environment

```bash
# Enter shell for 64-bit RISC-V G with CFI
nix develop .#rv64g-cfi

# Or for 32-bit standard I + Zicsr
nix develop .#rv32i-zicsr
```
