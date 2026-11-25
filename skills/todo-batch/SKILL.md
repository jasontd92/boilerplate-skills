---
name: todo-batch
description: Process a batch of small, unrelated TODOs in parallel — one worktree, one branch, one PR. Use when the user pastes a list of small independent items. Not for coupled multi-PR work (use sprint) or a single feature (use task-to-pr).
argument-hint: [paste your list of TODOs]
---

# TODO Batch: Parallel Small Changes

Process a batch of small, unrelated TODOs for **$ARGUMENTS** — maximizing parallelism while sharing a single worktree and PR.

> **CRITICAL**: Do NOT use plan-mode enter/exit. Do NOT stop to ask the user for approval between phases. Proceed autonomously. If you encounter ambiguity, make a reasonable decision and keep moving.

> **When NOT to invoke**: one feature that should be its own PR → `/task-to-pr`. Coupled workstreams that cannot land independently → `/sprint`.

---

## Phase 0: Setup

### Parse the TODO list
Split the user's input into discrete, numbered items. For each item, note:
- **ID** — preserve the external identifier if present (e.g., `STANDUP-42`, `BUG-117`). If none, use sequential `todo-1`, `todo-2`, etc.
- **Summary** — one-line description
- **Type** — fix / feat / refactor / chore (best guess from description)
- **Likely area** — backend / frontend / both / unknown (best guess from description)

### Create changelog file
Write a `batch-changelog.md` in the **worktree root** to track progress across all items. This file survives session compaction and keeps the orchestrating agent oriented.

```markdown
# Batch Changelog

| ID | Summary | Type | Status | Notes |
|----|---------|------|--------|-------|
| STANDUP-42 | Fix tooltip clipping on narrow screens | fix | pending | |
| STANDUP-58 | Add loading skeleton to dashboard | feat | pending | |
| todo-3 | Remove deprecated `useLegacyAuth` hook | refactor | pending | |
```

**Update this file as work progresses** — set status to `investigating`, `in-progress`, `done`, or `blocked`, and add concise notes (files changed, blockers). This is the single source of truth for batch state.

### Worktree
Create a **single shared worktree** for all items. Discover the project's worktree convention if one exists. Otherwise:

```bash
REPO=$(basename "$(git rev-parse --show-toplevel)")
git worktree add "../${REPO}-todos" -b chore/batch-<short-description> main
cd "../${REPO}-todos"
# Copy gitignored files the app needs (.env, secrets) from the main checkout
```

Prefer a **shared** database when none of the items involve migrations. Use an **isolated** database if any item mentions schema/migration/new table.

Boot the local stack with the project's documented command. If boot is slow, launch it in a background subagent and proceed to Phase 1 in parallel.

> **IMPORTANT**: All commands must run inside the worktree. The shell may reset cwd — always `cd` to the absolute worktree path. Verify with `pwd && git branch --show-current`.

---

## Phase 1: Parallel Investigation

Spawn **read-only subagents** (Task tool, `subagent_type: "Explore"`) to investigate all items concurrently. Each subagent should:

1. Find the relevant files (Glob, Grep, Read)
2. Understand the current behavior and the expected change
3. Identify the exact file(s) and line(s) to change
4. Report back: files to modify, proposed change, and any risks

Launch all investigation subagents in a **single message** to maximize parallelism.

### Conflict check
When all investigations complete, review the results for **file overlap**:
- If two items touch the **same file**, note the dependency — these must be implemented sequentially
- If items are in **separate files**, they can be implemented in parallel

---

## Phase 2: Parallel Implementation

Implement items using background subagents (`subagent_type: "general-purpose"`, `run_in_background: true`).

### Rules
- **Non-overlapping items** → launch in parallel as background subagents
- **Overlapping items** (same file) → implement sequentially, or handle yourself while subagents work on non-overlapping ones
- Each subagent receives: the investigation findings, the worktree absolute path, and instructions to **read the file before editing**
- Subagents should **not** run lint — that's batched in Phase 3
- Follow existing code patterns, minimal changes only
- Use in-container helpers when the project has them

### Tracking
Update `batch-changelog.md` as each subagent completes — set status to `done` and note the files changed. If a subagent fails or the item needs rework, set status to `blocked` with a reason.

---

## Phase 3: Batch Lint & Review

Run lint and review **once** across all fixes, not per-fix.

1. `pwd && git branch --show-current` — confirm location
2. Run the project's environment-ready command if one exists. If it fails, abort.
3. Run the project's **full-lint** command (not piecewise sub-commands)
4. Fix all issues, re-run until clean
5. **Independent code review** if the project uses cubic (or equivalent):
   - Uncommitted changes: `cubic review -j`
   - Clean tree: `cubic review -b -j`
   - Address legitimate P0/P1/P2. Skip false positives with a brief justification.
   - Repeat steps 2–5 until clean.
6. **Tightening pass**, once for the whole batch (`~/.claude/skills/pr-review-loop/reviewer-ready.md` section 2). Cut code the items do not need, and reject added code for marginal stability.

---

## Phase 4: Browser Testing (if UI changes exist)

**Skip this phase** if all items are backend-only. Proceed directly to Phase 5.

Follow `/browser-tests` when UI-facing items exist.

1. Point tests at the worktree's own URL — do not switch the main checkout
2. Build a test checklist — one scenario per UI-facing item, reflecting the **final code state**

> **AUTH**: If a shared session exists, assume logged in. If you hit an auth wall, **skip the scenario**, note "blocked by auth", and continue.

> **Evidence preservation:** Playwright **wipes `test-results/` at the start of every run**. Run all POW specs in one `workers:1` invocation, or copy evidence out between runs.

### Test loop
For each scenario: navigate → verify → on failure, delegate a fix to a background subagent (include lint), continue other scenarios, then re-test. After any fixes, re-run full lint once.

---

## Phase 5: Commit & PR

### Pre-commit
1. **Read `batch-changelog.md`** — use it to build the commit message and PR description
2. **Delete `batch-changelog.md`** — it has served its purpose; the PR description replaces it

### Steps
1. **Stage changes** — `git add` specific files (not `git add -A`). Do NOT stage `batch-changelog.md`.
2. **Commit** with conventional commit message:
   ```
   chore: batch TODOs — STANDUP-42, STANDUP-58, todo-3
   ```
   - Preserve external identifiers in the commit message
   - Do NOT include "Co-authored by Claude"
   - If items are diverse enough, consider grouping into 2–3 logical commits by type — each commit should reference the IDs it covers
   - Never leave a change followed by its revert. Fold each fix into the commit it belongs to.
3. **Push** — `git push -u origin chore/batch-<short-description>`
4. **Create PR** — `gh pr create --base main` with:
   - Title: `chore: [concise batch description]`
   - Body: a **single-line bullet per item** with its ID and resolution
   - Verification as a completed `- [x]` checklist, including browser test results (if applicable)
5. **Return the PR URL**

---

## Phase 6: Worktree Cleanup

1. Stop the worktree stack (project's compose/down command)
2. Remove containers + volumes if the project documents it
3. Remove the worktree from the parent directory:
   ```bash
   git worktree remove <worktree-path>
   ```

This only removes the worktree directory and its containers. The feature branch and remote PR remain intact.
