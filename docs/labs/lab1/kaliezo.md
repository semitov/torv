# Lab 1 · Umut Angi (@kaliezo)

Guide: [../lab1_sim.md](../lab1_sim.md).

## Regression

- Date and commit (`git log -1 --oneline`): 2026-11-26, `3951e6d docs(labs): add Lab 1 (simulation, regression and bug hunt) (#7)`
- Result (number of PASS lines in `summary.rpt`): 33/33 PASS

| Case | Cycles | Instr | IPC | Flush | Stall ID |
|------|--------|-------|-----|-------|----------|
| perf_alu_chain | 777 | 649 | 0.835 | 63 | 0 |
| perf_branch_loop | 648 | 392 | 0.605 | 127 | 0 |
| perf_loadstore_loop | 330 | 234 | 0.709 | 31 | 0 |
| perf_mul_loop | 122 | 74 | 0.607 | 15 | 16 |

## Pipeline

**Q1. Load-use** (screenshot in the PR description)

- Cycles `add` waits in ID: 1 (`hazard`, `lw x2` at 0x0c, `add x4, x2, x2` at 0x10; at 105 ns and 115 ns `if_id_pc` = 0x10, then the `add` enters EX).
- Hazard-unit outputs high while it waits: `load_use`, `stall_pc`, `stall_if_id`, `bubble_id_ex` (PC and IF/ID hold, a bubble goes into ID/EX: `id_ex_pc` = 0 at 115 ns).
- `forward_a` / `forward_b` when `add` is in EX, and why: both 1 (MEM/WB). The `lw` is now in MEM/WB with its loaded data, and EX/MEM holds the bubble. EX/MEM forwarding could not help without the stall: a load's data only arrives at the end of MEM, so the forwarding unit skips EX/MEM for loads.

**Q2. Forwarding without a stall**

- PC of an instruction with an operand from EX/MEM: `perf_alu_chain`, PC 0x10 `add x1, x1, x3`, rs1 = x1 from the `add` at 0x0c (`forward_a` = 2). The following `add x1, x1, ...` (0x14-0x28) do the same.
- PC of an instruction with an operand from MEM/WB: same PC 0x10, rs2 = x3 from the `li` at 0x08, two instructions back (`forward_b` = 1).

**Q3. Taken branch**

- Cycles per iteration, and how you got it: 5 (3 instructions plus 2 lost cycles). In the PC trace the loop start 0x08 enters ID every 50 ns (95, 145, 195 ns...), and one cycle is 10 ns. PERF agrees: 648 cycles for 128 iterations, about 5 each.
- What happens to the two instructions after `bne`: they are fetched (fall-through) and then flushed. At 165 ns `bne` is in EX with `ex_branch_taken` = `flush` = 1, ID holds 0x14 and IF holds 0x18; the next cycle `pc` = 0x08 and both `if_id_pc` and `id_ex_pc` are 0 (bubbles). That is the 2-cycle taken-branch penalty (spec: no branch prediction).

**Q4. Multiply and divide**

- `MUL` cycles: 2 in EX (1 extra). `perf_mul_loop`: `div_busy` is high for one cycle per `mul`, 16 `mul` give 16 `stall_id`. The MULH variants in `muldiv` also take 1 extra cycle.
- `DIV` cycles (about): 34 in EX (`div_busy` high for 33 cycles, a bit-serial divider). `div`/`rem` by zero finish in 1 extra cycle. Check: `muldiv` has 6 normal divides x 33 + 9 short ops x 1 = 207, the same as `stall_if` = 207.
- Signal that holds the front end: `div_busy` in the hazard unit (it covers MUL too). It drives `stall_pc`, `stall_if_id` and `stall_id_ex`, and puts a bubble into EX/MEM (`bubble_ex_mem`) while the result is not ready.

**Q5. Bus wait state and flush** (idea is enough)

While `bus_stall` is high (HREADY low), the whole pipeline is frozen, MEM/WB included, and an older load/store is still waiting for its data phase. If the taken branch in EX flushed now, it would clear IF/ID and ID/EX, but `pc` would not move to the target and the branch itself would stay in EX. When the stall ends, the branch would flush again and the redirect could be lost or applied twice, and the frozen IF fetch would no longer match the cleared stages. So `flush = ex_branch_taken && !bus_stall`: the branch waits in EX and flushes in the first cycle the pipeline moves again (spec priority: `bus_stall` first, no flush while active).

**Q6. IPC and one idea to raise it**

Lowest IPC: `perf_branch_loop`, 0.605 (`perf_mul_loop` 0.607 is close; it is also a taken-branch loop, plus the MUL stall). 127 taken branches x 2 lost cycles = 254 of 648 cycles. Idea: static branch prediction, predict backward branches as taken (loops) and fetch the target early, for example with a small BTB in IF. A right guess costs 0 cycles instead of 2. Another option is to resolve branches in ID, which cuts the penalty to 1 cycle but makes the ID path longer (`docs/TODO_LIST.md`: "Branch prediction or early resolution").

## Bug hunt

### Bug 1

- Failing cases: 32/33, every case except `replay_ibus_store` (it only checks the replay count, never the stored value). Most end with `tohost` 0x00 instead of the test's own fail code.
- First wrong instruction: `smoke`, PC 0x0c `bne x2, x3, fail` is taken although x2 = x3 = 8, so the PC goes to 0x50 instead of 0x10. In EX, `id_ex_rs2` = `ex_mem_rd` = 3 but `forward_b` stays 0, so the branch reads the stale x3 = 0. The fail path then stores 0 to `tohost` (`sw x21` right after `addi x21`, same rs2 problem).
- Root cause (file, signal): `rtl/torv_forwarding_unit.sv`, `forward_b`. The EX/MEM check compares `ex_mem_rd` with `id_ex_rs1` instead of `id_ex_rs2`, so rs2 forwarding from EX/MEM fires when rs1 matches and misses when rs2 matches. A probe test (rs1/rs2 at distance 1 and 2) gave `tohost` 0x1a with the bug: the rs2 EX/MEM case fails, the rs1 EX/MEM cases fail through a polluted rs2, and rs2 MEM/WB passes. The clean RTL passes.
- Fix: in the `forward_b` EX/MEM condition, use `(ex_mem_rd == id_ex_rs2)`.

### Bug 2

- Failing cases: 2/33, `hazard` and `bus_mix_dbus_sbus` (both `tohost` 0x02, the test's own fail). They are the only cases with a load followed directly by a store of the loaded register.
- First wrong instruction (case, PC, what differs): `hazard`, PC 0x74 `sw x18, 12(x3)` right after `lw x18, 0(x3)`. On clean RTL the `sw` waits one cycle in ID (PC 0x78 shows twice); with the bug there is no stall, so the `sw` stores the stale x18 = 0. The next `lw x19` then reads 0 instead of 0x2a and `bne x19, x1, fail` is taken.
- Root cause (file, signal): `rtl/torv_hazard_unit.sv`, `uses_rs2`. `OP_STORE` is missing from the opcodes that use rs2, so `load_use` ignores the store data register (waveform at the `sw`: `id_ex_mem_read` = 1, `id_ex_rd` = `rs2_f` = 18, but `uses_rs2` = 0, `load_use` = 0). Forwarding cannot cover it, because EX/MEM forwarding skips loads (data not ready yet).
- Fix: put `OP_STORE` back in the `uses_rs2` case: `OP_REG, OP_STORE, OP_BR: uses_rs2 = 1'b1;`.

### Bug 3

- Failing cases: 5/33, `branch`, `compare_edges`, `flush`, `hazard`, `hazard_branch_mem_stall` (all end with the test's own fail code). All of them have a taken conditional branch followed by an instruction whose result is checked.
- First wrong instruction (case, PC, what differs): `flush`, PC 0x08 `addi x1, x0, 99`, the wrong-path instruction after the taken `beq x0, x0` at 0x04. On clean RTL it is flushed; with the bug it writes back x1 = 0x63 (trace at 125000 ps), so `bne x1, x0, fail` at 0x10 is taken. The `jal` at 0x14 still flushes its slot (x1 = 88 never appears).
- Root cause (file, signal): `rtl/torv_core.sv`, ID/EX flush (`flush` with the `id_ex_*` registers and `id_ex_rs1_a_d`/`id_ex_rs2_a_d`). The ID/EX clear was made conditional on `flush && id_ex_jump`, and `jump` is set only for JAL/JALR. On a taken branch, `flush` = 1 clears IF/ID but the instruction already in ID moves into EX and executes.
- Fix: clear ID/EX on every taken control-flow instruction: `else if (flush && !stall_id_ex)` and `if ((flush || bubble_id_ex) && !stall_id_ex)` (drop `&& id_ex_jump`).

### Bug 4 (bonus, idea is enough)

- What the regression says, and why:
- Root cause (file, signal):
- Your test, and its result with and without the bug:

```asm
```

## Notes

Anything that was unclear in the guide, took you long, or that you would change.

- `docs/labs/lab1/pipeline.gtkw` shows only the group headings and no waves with a VCD from `scripts/run_case.sh --vcd`: the save file names signals `TOP.tb_torv_soc...`, but the VCD's top scope is `tb_torv_soc`. Removing `TOP.` from the save file fixes it. Adding `u_hz.load_use` to the "Hazard unit" group would help Q1.
- `run_case.sh` prints PASS on the console, but a FAIL only shows up in `<build>/<case>.sim.log`, which is easy to miss when running single cases.
