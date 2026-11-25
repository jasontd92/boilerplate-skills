---
name: verify
description: Independent verification of a change by a fresh, read-only agent that writes its checks before it sees the work, then re-runs them against the result. The shared method behind task-to-pr, todo-batch, blitz and sprint. Use it on its own when the user asks to verify a task, PR or branch independently.
argument-hint: [task or PR to verify] [--verifier=full|light|off]
---

# Verify: Independent Checks on Someone Else's Work

The agent that implements a change is the worst judge of whether it is done. It tests what it assumed, with fixtures that encode those assumptions. A verifier is a separate agent with no stake in the work. It decides what proves the change **before** it sees the change, then checks the result itself.

This file is the method. Each skill that uses it says only **when** the verifier runs, **what** it is handed, and **what its verdict gates**.

## Modes

| Mode | Plan step | Check step | Model | Use for |
|---|---|---|---|---|
| **full** (default) | Fresh agent writes the plan from the task and `main` only | Fresh, read-only agent re-runs every check, including browser and live-system checks | Session default | Anything that can reach users or prod |
| **light** | Same, but the plan holds only checks a command can run: tests, lint, greps, API calls, queries | Re-runs the plan's commands. No browser runs | Cheaper (e.g. `model: "sonnet"` or `"haiku"`) | Small or low-risk work, cost-sensitive setups |
| **off** | No separate agent. The implementer writes the plan **before** it writes code, and does not change it after | The implementer runs the plan | — | Trivial work where a second agent costs more than it can find |

### Choosing the mode
Use the first one that is set:
1. `--verifier=<mode>` in the skill's arguments.
2. A `Verifier: <mode>` line in the repo's `CLAUDE.md`.
3. A `Verifier: <mode>` line in `~/.claude/CLAUDE.md`.
4. The calling skill's default.

A skill may set a **minimum** (sprint's is `light`). If the chosen mode is below it, use the minimum and say so in the final report.

## Step 1: Plan (before the work exists)

Start the planner as early as the task is known, in parallel with the implementer's analysis. It receives **only** the task text (ticket, TODO, acceptance criteria) and the repo at `main`.

The plan lists, for each thing the task must make true:
- **The claim**, in plain words.
- **Its type** (see Classify below).
- **The check**: real inputs, the exact command or steps, and the expected output. Prefer real data (real records, real screenshots, real traffic) over hand-made fixtures.
- **Red on base** where it applies: the check should fail on `main` and pass after the change. A check that passes on both proves nothing.

It also lists the **regressions to rule out**: callers of any interface the task touches, and nearby behaviour that must not change.

Write the plan to a file **outside the worktree** (scratch directory or `/tmp`), so it is never committed. The implementer may read the plan: it is the target. The implementer may not edit it, and its own tests do not count as evidence for the verdict.

## Step 2: Check (after the work is final)

Run it once the code has stopped moving (after the review loop). In full and light modes, use a **fresh** agent, or the planner resumed. The planner has not seen the work, so it brings no framing from the implementer.

### What the verifier never receives
The implementer's brief, transcript, scratch notes or reasoning, or anyone's opinion of how the work went. Facts about the work reach it only as **claims to test**: "the implementer says X. Check it."

### Rules
- **Read-only toward the code.** No edits, pushes or merges. Changes needed to run a check happen only in its own disposable worktree or clone, reverted afterwards, with a clean tree confirmed.
- **Reproduce, don't trust.** Re-run the command and compare the output. Query the live system, not the doc that describes it. "The implementer said X" is not evidence.
- **Classify every criterion before judging it:**

| Type | Evidence | Who marks it |
|---|---|---|
| **Mechanical**: lint exits 0, CI green, a string in zero files, a percentage | A command **and its output** | The verifier re-runs it |
| **Empirical**: payload correct, event delivered, migration applied, page renders the data | Test output or a live query result | The verifier compares the artifact to the criterion |
| **Judgment**: is this mapping right? is the page usable? | None | **A human**, via the final report |

- 🔴 **A criterion nobody can check mechanically or empirically is a question for the human, not a checkbox.**
- 🔴 **Untick with a reason rather than tick on a feeling.** Blocked is `FAILED` or `UNVERIFIABLE`, with why, however reasonable the workaround sounds.
- 🔴 **Report claims that did not hold, including unflattering ones.** A verdict is trustworthy because of what it refuses to confirm.
- **Beware fused criteria.** One checkbox often bundles two claims, one met and one not. Tick only when its whole text holds.
- **Look past the plan.** Anything wrong that no criterion covers (an exposure, a broken caller, a cancelled test suite reported green) goes in the verdict too.

### Verdict format
```
VERIFIER (<mode>): <work> — <PASS | FAIL | PASS WITH GAPS>
criteria met:   <n>/<total>
  - <criterion> → <evidence checked; reproduced or not>
criteria FAILED:      <list, or none>
criteria DESCOPED:    <with the decision reference>
criteria HUMAN:       <judgment calls for the user>
UNVERIFIABLE:         <with why>
claims that did NOT hold: <list, or none>
outside the plan:     <problems no criterion covered, or none>
```

On `FAIL`, the calling skill fixes the failures and runs the check step again. After a second `FAIL`, stop and report.

## Reporting

- 🔴 **The mode and verdict go in the final report to the user only:** the session's closing summary, an exit summary, or a morning report. Never in the PR description, commits, PR comments or tickets. Other developers don't know what a verifier mode is. The PR's Verification checklist lists the checks and their results in plain words.
- When the mode was `light` or `off`, the final report says so in one line and lists what had no independent check, for example: "Verifier off: self-checked. Browser flow and migration not independently checked."
