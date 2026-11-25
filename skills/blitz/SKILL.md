---
name: blitz
description: Work through a queue of unrelated tickets in one session (code, spikes, experiments, messages and release steps) with parallel workers, a live board, and tracker statuses kept in sync. Use when the user says "blitz", "work through my tickets", "clear my Linear queue", or hands over a list of mixed tickets. Not for one feature (use task-to-pr), one multi-PR project (use sprint), or small code fixes that fit one PR (use todo-batch).
argument-hint: [ticket filter, e.g. "my unblocked tickets in team KOC"] [--verifier=full|light|off]
---

# Blitz

A blitz finishes a queue of unrelated tickets, often in one day. Each ticket type has its own finish line, its own tracker statuses and its own human steps. You are the orchestrator. You triage, brief workers, keep the tracker and the board true, and bring the user only the decisions and clicks that are theirs.

> **Not a blitz:** one feature → `/task-to-pr`. One project cut into coupled chunks → `/sprint`. Small code fixes that fit one PR → `/todo-batch`.

## 1. Triage, before any worker starts

Pull the queue (for example, the user's open tickets, minus blocked ones). Give each ticket one type:

| Type | Finish line | Worker uses | Tracker status at each event | Usual human step |
|---|---|---|---|---|
| **Code** | PR open, checks pass, threads resolved, verifier says ready | `/task-to-pr` Phases 0–6, no merge | start → In Progress; PR opened → In Review; merged → Merged; in prod → Done | review and merge; prod promotion |
| **Spike** (a question) | Answer posted on the ticket or its doc, with evidence | brief only | start → In Progress; write-up posted → Done | access to a sandbox, portal or account |
| **Experiment** (compare options) | One call (keep or drop) against gates set before run 1 | brief only | start → In Progress; call posted → Done | spend limit; judgment gates |
| **Message** | Draft ready where the user sends from | you or a brief | draft ready → In Review; sent → comment with the date, then Done (or In Review until a reply) | the user sends |
| **Release step** | Done and checked in the target environment, or handed over as one exact click | you or a worker | start → In Progress; checked in prod → Done | approvals, prod access, prod merge |

Use the team's status names. If the team has no Merged status, keep In Review until prod.

Then group the tickets. One worker takes the tickets that touch the same code or system, one after another, so its context carries over. Run unrelated groups in parallel.

## 2. Ask for every human step in one message

Before workers start, list each ticket's human steps and ask for all of them at once: approvals, access (prod read, SSO, sandbox), clicks (workflow approvals, admin uploads), decisions, and messages the user sends. Name the exact action for each. Write the answers into the board's `limits.txt` and into every worker brief as standing rules, so nobody asks twice.

- If one command needs approval each time and will run many times (for example, read-only `kubectl` on prod), propose a narrow allow rule in settings (`/update-config`).
- Before you send the user to a portal or console, check in the repo how the resource was made (infrastructure code, app manifest). The fix is often a file, not a click.

## 3. Board and workers

Use the sprint board: the "Herdr leaderboard" section of `~/.claude/skills/sprint/SKILL.md` and `~/.claude/skills/sprint/scripts/leaderboard.sh <board dir>`. Its default `MET` covers every blitz finish line. In a blitz:

- One row per ticket, with the ticket number as the key: `1074|Retention script|retention worker|<absolute path to status file>`.
- A worker writes `<worktree>/.blitz-status.txt`. You write `<board>/status/<key>.txt` for the tickets you own (messages, release steps, user decisions).
- Arm one Monitor on `~/.claude/skills/blitz/scripts/watch.sh <board dir>`. It reads `rows.txt` on each loop, so a new row is watched without a change to the script.
- The board and the watcher re-read rows and status files on each refresh. If you change a script, restart its pane: a running process keeps the old code.

Without Herdr, run workers with the Agent tool and print `leaderboard.sh <board dir> --once` at each check-in.

## 4. Sync at each event

This is the rule that fails most. When a ticket's state changes, update three things **in the same step**: the tracker status, the status file, and a short tracker comment (link and one-line result). Do not leave it for the end of the day. Each watcher line with a new stage is an event.

Before sign-off, sweep: for each row, compare the tracker status with the PR state (`gh pr view <n> --json state`) and the status file. Fix each mismatch.

## 5. Rules by type

**Code.** Every code ticket gets a verifier: follow `~/.claude/skills/verify/SKILL.md`. Default mode is `full` for a PR that can reach prod and `light` for one that cannot. A `--verifier=` argument or a `Verifier:` line in CLAUDE.md overrides both. You own the verifier, not the worker:
- Start the planner (`verify` Step 1) when the worker starts, from the ticket and `main` only. Put the plan's path in the worker brief.
- The worker runs `/task-to-pr` with that plan and stops after Phase 6, before its own check step.
- When the worker reports the PR open, run the check step from a fresh agent. Give it the plan, the PR and the worker's claims, never the worker's brief or transcript.
- Report a PR as ready only with its verdict and after the reviewer-ready pass.

**Spike.** In a sandbox or test environment, when the spike hits a missing permission or setting, add it and test. Do not stop at "needs a permission we lack." Report what the same change costs in prod in its own section.

**Experiment.** Before run 1, write down the gates, the drop rule and the runs per arm (3 or more: one run misleads). Post one call when the runs finish. Then give the user one paragraph: what went well, what did not, and gaps in communication.

**Release step.** Rehearse in nonprod with the same artifact before prod. Each problem the rehearsal finds becomes a ticket and a board row.

**Message.** Draft in the user's voice, in the place they send from. Never send.

## 6. Worker brief

Keep it under one page:

```
Ticket <KEY>: <title> (<type>). Finish line: <from the triage table>.
Read first: <ticket, its comments, linked docs>.
Worktree: <path>, branch <name>. Skill: <task-to-pr | none>.
Verification plan (code tickets): <path>. It is your target. Do not edit it. Stop after task-to-pr Phase 6: the orchestrator runs the check.
Limits: <limits.txt, verbatim>.
Status file: each time your stage changes, overwrite <path> with one line "<stage> | <detail>".
  Working stages: building, testing, review loop. At the finish line: PR open, write-up posted,
  results posted, dropped. Write "PR open" only when the code finish line is met.
  Need the user: "needs you | <exact action>". Need the orchestrator: "blocked | <question>".
PR description and finish: the reviewer-ready shape and pass in `~/.claude/skills/pr-review-loop/reviewer-ready.md`.
Settled decisions (do not reopen): <list, or none>.
Report in 10 lines or fewer: result, evidence, what is left. Details go on the ticket.
```

## 7. Reports

- Chat updates fit on one screen. Details go to the tracker or the doc.
- Keep a handoff file in the scratch folder: goal, limits, state of each ticket, next steps. Update it at each event, because a long day compacts the context.
- End of day: what is done, what waits on the user (exact actions), and what is next. Give each code ticket's verifier mode and verdict, and list what had no independent check under `light` or `off`. This goes in the report to the user only, never on tickets or PRs. Run the step 4 sweep first.
