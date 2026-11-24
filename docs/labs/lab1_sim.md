# Lab 1 · Simulation, regression and the pipeline

**Goal:** run TORV in simulation, read its five-stage pipeline in a waveform, and find bugs
with the regression the way a verification engineer does.
**Time:** about 8–10 hours over two weeks. If you are new to processor design, plan for the upper
end: the first waveform takes the longest, the rest goes faster.
**Before you start:** Lab 0 is merged (your row is in [`members.md`](members.md)), and
`git switch main && git pull` brings you up to date.
**Hand in:** one pull request that adds `docs/labs/lab1/<your-github-username>.md`, filled in
from [`lab1/TEMPLATE.md`](lab1/TEMPLATE.md). Screenshots go in the pull request description,
not in the repository.

Read these first (about one hour). The questions in §3 and §4 assume you have:

- [README](../../README.md) → *Architecture*: the SoC and pipeline figures.
- [spec §5–§9](../../spec/RV32IM_Current_Implementation.md#5-pipeline-registers): pipeline
  registers, execute, memory stage and **hazard handling** (the most important section).
- [sim/SIM_README.md](../../sim/SIM_README.md): how a test runs, PASS/FAIL, `[PERF]` counters
  and the PC trace.

```text
tests/core/asm/<case>.S ──gcc──► <case>.elf ──objcopy──► <case>.hex
                                                            │ +imem= (loaded before reset)
                                         Verilator: tb_torv_soc ─► torv_soc ─► torv_cpu ─► torv_core
                                                            │
                                   the test stores 1 (PASS) or 2 (FAIL) to tohost 0xF000_0000
```

## 1. One test, three ways to look at it

From the repository root, in every new terminal:

```bash
cd ~/project/torv
source scripts/env.sh
```

1. **Run it.**

   ```bash
   ./scripts/run_case.sh tests/core/asm/hazard.S
   ```

   It prints the paths of its outputs, and `hazard.sim.log` ends with
   `[PASS] TORV tohost signalled success`. A failing test prints `TORV SoC test failed; see …`
   instead. Everything for this case is in `build/sim/soc/hazard/`:

   | File | What it is |
   |------|------------|
   | `hazard.dump` | Disassembly with the address (PC) of every instruction. Keep it open. |
   | `hazard.sim.log` | Testbench log: `[PERF]` counters and `[PASS]`/`[FAIL]` |
   | `hazard.vcd` | Waveform (only with `--vcd`) |
   | `pc_trace.tsv` | PC and write-back per cycle (only with `--pc-trace`) |

2. **PC trace**: what the pipeline fetched and wrote back, cycle by cycle, without a waveform:

   ```bash
   ./scripts/run_case.sh --pc-trace --pc-trace-each-cycle tests/core/asm/hazard.S
   column -t build/sim/soc/hazard/pc_trace.tsv | head -40
   ```

   The columns are explained in [SIM_README → PC trace](../../sim/SIM_README.md#pc-trace).
   A `wb_we=1` row means a register was written that cycle: `wb_rd` is the register,
   `wb_wdata_hex` the value.

3. **Waveform:**

   ```bash
   ./scripts/run_case.sh --vcd tests/core/asm/hazard.S
   ./scripts/open_gtkwave.sh --save docs/labs/lab1/pipeline.gtkw hazard
   ```

   The save file [`lab1/pipeline.gtkw`](lab1/pipeline.gtkw) opens GTKWave with the signals below
   already added, grouped by pipeline stage and in hex. Press *Zoom Fit* (the magnifier with the
   square) to see the whole run, then zoom in on the PCs you are looking for.
   The signals live under `TOP → tb_torv_soc → dut → u_cpu → u_core` (left panel), if you want
   to add more: select them, then *Append*.

   | Signal | Meaning |
   |--------|---------|
   | `clk` | Clock (10 ns) |
   | `pc` | Address being fetched (IF) |
   | `if_id_pc`, `if_id_inst` | Instruction in ID |
   | `id_ex_pc` | Instruction in EX |
   | `forward_a`, `forward_b` | Operand source in EX: `0` register file, `1` MEM/WB, `2` EX/MEM |
   | `stall_pc_h`, `stall_if_id`, `bubble_id_ex` | Hazard unit outputs (`stall_pc_h` is the hazard unit's `stall_pc` output inside `torv_core`) |
   | `flush` | Taken branch or jump in EX |
   | `mem_wb_rd`, `mem_wb_result` | What is written back |

   GTKWave runs on Windows through WSLg; if no window opens, run `wsl --update` in PowerShell.

## 2. The full regression

```bash
./scripts/regress.sh
```

It runs the 33 cases of `regress/cases/soc.list` (5–10 minutes: every case builds its own
Verilator model) and every line of `summary.rpt` must say `PASS`. Results are in
`regress/results/<date_time>/`:

```bash
r=$(ls -dt regress/results/*/ | head -1)
cat $r/summary.rpt
cut -d, -f1,3- $r/perf_summary.csv | column -s, -t | less -S     # q to quit
```

`perf_summary.csv` has one row per case: `cycles`, `instr`, `ipc`, the instruction mix, and the
cycles with a stall or flush (`stall_if`, `stall_id`, `stall_ex`, `flush`). These counters are
explained in [SIM_README → Performance counters](../../sim/SIM_README.md#performance-counters).

The same regression runs in CI on every pull request (the `regress` check).

## 3. Read the pipeline

Answer in your hand-in file. Short answers are fine: one or two sentences, a number, a
screenshot. What matters is that the reasoning comes from what *you* saw in the waveform,
trace or counters. Questions marked **(idea is enough)** are graded on your reasoning, not on
getting the exact answer: write what you think and why, and we discuss it in the review.

**Q1. Load-use.** In `hazard.S`, the first pair is:

```asm
lw   x2, 0(x3)
add  x4, x2, x2
```

Find it in the waveform (look up its PC in `hazard.dump`).
How many cycles does `add` wait in ID? Which hazard-unit outputs are high while it waits?
When `add` is finally in EX, what are `forward_a` and `forward_b`, and why not `2` (EX/MEM)?
Put one screenshot in the PR description, with the cursor on the bubble.

**Q2. Forwarding without a stall.** In `perf_alu_chain.S` every instruction uses the result of
the one before it, yet there is no stall. Run it with `--vcd` and find one instruction whose
operand comes from EX/MEM (`2`) and one from MEM/WB (`1`). Give their PCs.

**Q3. The cost of a taken branch.** `perf_branch_loop.S` is a three-instruction loop that runs
128 times. From its `[PERF]` lines (`cycles`, `instr`, `flush`), how many cycles does one
iteration take? Where do the extra cycles go? Confirm it in the waveform: what happens to the
two instructions fetched after `bne`? Careful: compare the `flush` count with the number of
cycles a taken branch really costs.

**Q4. Multiply and divide.** From `perf_mul_loop` and `muldiv` in `perf_summary.csv`, how many
cycles does a `MUL` take, and roughly how many does a `DIV`? Which hazard-unit output holds
the front end while they run?

**Q5. Bus wait states (idea is enough).** `hazard_branch_mem_stall` makes the SBUS hold `HREADY` low during a
store (see its `.plusargs`). Read spec §9: why must a taken branch **not** flush while
`bus_stall` is high? One or two sentences.

**Q6. IPC.** List the IPC of the four `perf_*` cases. Which one is lowest, and what would you
change in the microarchitecture to raise it? (No code, one idea; [TODO_LIST](../TODO_LIST.md)
has hints.)

## 4. Bug hunt

`scripts/lab1_bug.sh` puts one known bug into the RTL. Your job is to find it using only the
regression, the dump, the PC trace and the waveform, the way you would on a real design.

```bash
./scripts/lab1_bug.sh list        # the bugs and a one-line hint each
./scripts/lab1_bug.sh apply 1     # put bug 1 into rtl/
./scripts/regress.sh              # which cases fail now?
./scripts/lab1_bug.sh reset       # put the RTL back (always do this before the next bug)
```

Don't read the script to get the answer. `git diff rtl/` would show you the bug as well, so
don't run it until you have written down your guess.

For each bug, write in your hand-in:

1. which cases fail (from `summary.rpt`);
2. the **first wrong instruction**: rerun one failing case with `--pc-trace` (or `--vcd`), compare
   with the same case on the correct RTL, and give the PC where they first differ;
3. the root cause: file, signal, and what is wrong in one sentence;
4. the fix (one line), then check it with `git diff rtl/` and `./scripts/lab1_bug.sh reset`.

A good way to find the first difference is to run the case on both RTLs and compare the traces:

```bash
./scripts/run_case.sh --pc-trace --pc-trace-each-cycle --build-dir build/good tests/core/asm/<case>.S   # after reset
./scripts/lab1_bug.sh apply 1
./scripts/run_case.sh --pc-trace --pc-trace-each-cycle --build-dir build/bad  tests/core/asm/<case>.S
diff build/good/pc_trace.tsv build/bad/pc_trace.tsv | head
```

Do bugs 1–3. Bug 1 is a warm-up.

**Bug 4 (bonus, idea is enough)** is different: run the regression with it first and look at the
result. Then explain why the regression says what it says, and, if you can, write a short
assembly test (10–20 lines, in the style of `tests/core/asm/`) that fails with bug 4 and passes
without it. An explanation of what such a test must do already counts; a working test is the
full bonus. Put the test in your report as a code block, together with the output of both runs:

```bash
./scripts/run_case.sh --build-dir build/bonus /tmp/my_test.S
```

## 5. Hand in

```bash
git switch main && git pull
./scripts/lab1_bug.sh reset                    # rtl/ must be clean
git switch -c docs/lab1-<your-github-username>
cp docs/labs/lab1/TEMPLATE.md docs/labs/lab1/<your-github-username>.md
# fill it in
git add docs/labs/lab1/<your-github-username>.md
git commit -m "docs(labs): add Lab 1 report for <your name>"
git push -u origin HEAD
gh pr create --fill
```

In the PR description, add your Q1 screenshot (drag it into the text box) and confirm that your
clean regression passed all 33 cases. Only your file must change: if `git status` shows
anything under `rtl/`, run `./scripts/lab1_bug.sh reset` first.

You are done with Lab 1 when your pull request is merged. Next is Lab 2: synthesis and timing.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `TIMEOUT waiting for TORV tohost` | The program never reached PASS or FAIL: the pipeline is stuck or jumped somewhere wrong. Use `--pc-trace` and look at the last PCs |
| `registered forwarding select mismatch` | The simulation-only check in `torv_core` stopped the run. Read spec §9: what does `u_fwd_chk` compare? |
| GTKWave shows no signals under `dut` | You ran without `--vcd`, or opened an old VCD. Rerun with `--vcd` |
| The regression fails with the bug reset | `git status`: something under `rtl/` is still modified. `./scripts/lab1_bug.sh reset` |
| Anything else | Post the command and the error in the ASIC Task Force Telegram topic |
