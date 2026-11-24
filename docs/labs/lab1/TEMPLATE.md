# Lab 1 · <your name> (@<your-github-username>)

Copy this file to `docs/labs/lab1/<your-github-username>.md` and fill it in.
Guide: [../lab1_sim.md](../lab1_sim.md).

## Regression

- Date and commit (`git log -1 --oneline`):
- Result (number of PASS lines in `summary.rpt`):

| Case | Cycles | Instr | IPC | Flush | Stall ID |
|------|--------|-------|-----|-------|----------|
| perf_alu_chain | | | | | |
| perf_branch_loop | | | | | |
| perf_loadstore_loop | | | | | |
| perf_mul_loop | | | | | |

## Pipeline

**Q1. Load-use** (screenshot in the PR description)

- Cycles `add` waits in ID:
- Hazard-unit outputs high while it waits:
- `forward_a` / `forward_b` when `add` is in EX, and why:

**Q2. Forwarding without a stall**

- PC of an instruction with an operand from EX/MEM:
- PC of an instruction with an operand from MEM/WB:

**Q3. Taken branch**

- Cycles per iteration, and how you got it:
- What happens to the two instructions after `bne`:

**Q4. Multiply and divide**

- `MUL` cycles:
- `DIV` cycles (about):
- Signal that holds the front end:

**Q5. Bus wait state and flush**

**Q6. IPC and one idea to raise it**

## Bug hunt

### Bug 1

- Failing cases:
- First wrong instruction (case, PC, what differs):
- Root cause (file, signal):
- Fix:

### Bug 2

- Failing cases:
- First wrong instruction (case, PC, what differs):
- Root cause (file, signal):
- Fix:

### Bug 3

- Failing cases:
- First wrong instruction (case, PC, what differs):
- Root cause (file, signal):
- Fix:

### Bug 4 (bonus)

- What the regression says, and why:
- Root cause (file, signal):
- Your test, and its result with and without the bug:

```asm
```

## Notes

Anything that was unclear in the guide, took you long, or that you would change.
