# nix-cfi-riscv-toolchains

A centralized Nix Flake repository providing reproducible RISC-V cross-compilation toolchains with **Hardware Control-Flow Integrity (CFI)** (`Zicfilp` + `Zicfiss`).

This repository provides two dedicated toolchains to cover all bare-metal and open-source contribution needs without unnecessary build matrix bloat:

1. **`escv`**: A dedicated single-target (`riscv32-none-elf`) bare-metal toolchain for the `eSC-V` core. Uses Nano Newlib exclusively, ensuring zero `M`, `A`, or `C` instructions contaminate `eSC-V` binaries.
2. **`universal`**: A universal 64-bit multilib toolchain (`riscv64-none-elf` with `--enable-multilib`). Builds standard Newlib with CFI for 32-bit and 64-bit soft-float and hard-float ABIs (`ilp32`, `ilp32d`, `lp64`, `lp64d`). Ideal for Zephyr RTOS, `riscv-arch-tests`, and open-source contributions.

---

## Toolchains

| Toolchain Name  | Architecture (`-march`)       | ABI (`-mabi`) | Multilib    | Newlib Variant         | Primary Target                                             |
| :-------------- | :---------------------------- | :------------ | :---------- | :--------------------- | :--------------------------------------------------------- |
| **`escv`**      | `rv32i_zicsr_zicfilp_zicfiss` | `ilp32`       | Disabled    | Nano (`nanoizeNewlib`) | `eSC-V` 5-Stage Core (Pure Base Integer + CFI)             |
| **`universal`** | `rv64g_zicfilp_zicfiss`       | `lp64d`       | **Enabled** | Standard               | Zephyr RTOS, `riscv-arch-tests`, Newlib, 32/64-bit targets |

---

## Quick Start & Usage

### 1. Enter a Development Shell

```bash
# Enter shell for eSC-V bare-metal development
nix develop .#escv

# Enter shell for Zephyr RTOS / Universal Multilib development
nix develop .#universal
```

---

## Downstream Flake Integration

### Using `escv` for eSC-V Bare-metal Projects

```nix
{
  inputs = {
    nix-cfi-riscv-toolchains.url = "github:ethycS0/nix-riscv-toolchains";
  };

  outputs = { self, nixpkgs, nix-cfi-riscv-toolchains }:
    let
      system = "x86_64-linux";
      escv = nix-cfi-riscv-toolchains.packages.${system}.escv;
    in {
      devShells.${system}.default = nixpkgs.legacyPackages.${system}.mkShell {
        packages = [ escv ];
        env = escv.envVars;
      };
    };
}
```

### Using `universal` for Zephyr RTOS

```nix
{
  inputs = {
    nix-cfi-riscv-toolchains.url = "github:ethycS0/nix-riscv-toolchains";
  };

  outputs = { self, nixpkgs, nix-cfi-riscv-toolchains }:
    let
      system = "x86_64-linux";
      tc = nix-cfi-riscv-toolchains.packages.${system}.universal;
    in {
      devShells.${system}.default = nixpkgs.legacyPackages.${system}.mkShell {
        packages = [
          tc
          nixpkgs.legacyPackages.${system}.python3Packages.west
          nixpkgs.legacyPackages.${system}.cmake
          nixpkgs.legacyPackages.${system}.ninja
          nixpkgs.legacyPackages.${system}.dtc
        ];
        env = tc.envVars // {
          ZEPHYR_TOOLCHAIN_VARIANT = "cross-compile";
        };
      };
    };
}
```
