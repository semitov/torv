# ASIC Task Force labs

Hands-on labs for new members of the SemiTO-V ASIC Task Force. Every lab runs on TORV with the
open-source flow (LibreLane on IHP SG13G2), and every lab ends with a pull request.

| Lab | Topic | Guide | You hand in (a pull request) |
|-----|-------|-------|------------------------------|
| 0 | Environment setup | [lab0_setup.md](lab0_setup.md) | Your row in [members.md](members.md) + `lab0_check.sh` output |
| 1 | Simulation, regression and bug hunt | [lab1_sim.md](lab1_sim.md) | `lab1/<you>.md`: perf table, pipeline answers, bugs found |
| 2 | Synthesis and pre-PnR timing | coming soon | QoR table at three clock periods |
| 3 | Full RTL-to-GDS flow | coming soon | Signoff summary |
| 4 | Tune one setting in your area | coming soon | A merged change with before/after QoR |
| 5 | Chip level: SRAM macros and pad ring | coming soon | Your piece of the TO1 trial run |

Plan about 6–8 hours per week. Stuck for more than 30 minutes? Post the command and the error
in the ASIC Task Force Telegram topic.

General setup and commands are also in [../open_source_flow.md](../open_source_flow.md), and the
contribution rules in [../../CONTRIBUTING.md](../../CONTRIBUTING.md).
