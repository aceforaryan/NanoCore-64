# NanoCore-64 Synthesis Report

Results from Yosys open-source synthesis targeting generic gate-level cells (no specific technology library).

## Tool

- **Synthesizer:** Yosys (open-source)
- **Target:** Generic gate-level cells (`$_AND_`, `$_NAND_`, `$_OR_`, `$_XOR_`, `$_MUX_`, `$_DFF_*`, etc.)
- **Technology Library:** None (technology-independent)

## Cell Count Summary

| Module   | Cells (local) | Cells (hierarchical) |
|----------|--------------|---------------------|
| cpu      | 2,730        | 18,347              |
| regfile  | 10,084       | 10,084              |
| alu      | 2,296        | 2,296               |
| csr      | 1,457        | 1,457               |
| mmu (×2) | 632 each     | 1,264 total         |
| timer    | 516          | 516                 |

**Total design: 18,347 cells**

## Cell Type Breakdown (full design)

| Cell Type      | Count | Description |
|---------------|-------|-------------|
| `$_AND_`       | 6,155 | 2-input AND |
| `$_NAND_`      | 6,742 | 2-input NAND |
| `$_OR_`        | 644   | 2-input OR |
| `$_NOR_`       | 239   | 2-input NOR |
| `$_XOR_`       | 332   | 2-input XOR |
| `$_XNOR_`      | 380   | 2-input XNOR |
| `$_NOT_`       | 32    | Inverter |
| `$_ANDNOT_`    | 164   | AND-NOT |
| `$_ORNOT_`     | 350   | OR-NOT |
| `$_MUX_`       | 813   | 2:1 MUX |
| `$_DFFE_PP0P_` | 2,367 | D flip-flop with enable and async reset-to-0 |
| `$_DFFE_PP1P_` | 65    | D flip-flop with enable and async reset-to-1 |
| `$_DFF_PP0_`   | 64    | D flip-flop with async reset-to-0 |

## Area Analysis

The register file dominates at 55% of total cell count (10,084 / 18,347). This is expected for a 32×64-bit register file synthesized to discrete flip-flops without SRAM macros.

| Component | % of Total |
|-----------|-----------|
| regfile   | 55.0%     |
| cpu (local) | 14.9%  |
| alu       | 12.5%     |
| csr       | 7.9%      |
| mmu (×2)  | 6.9%      |
| timer     | 2.8%      |

## Timing

Static timing analysis (STA) was run but produced no timing paths due to the absence of a technology-specific cell library. The Yosys `sta` pass requires characterized cells with delay information to produce meaningful timing results.

Timing analysis would require mapping to a specific technology (e.g., ASIC standard cell library or FPGA primitives).

## Notes

- The register file would typically be replaced with SRAM macros in an ASIC implementation, significantly reducing area.
- The `$_DFFE_PP1P_` cells (65 total) are in the CSR module — these are the STATUS/TIMECMP bits that reset to 1.
- Synthesis was performed without optimization constraints; actual area will vary with target technology and optimization settings.
