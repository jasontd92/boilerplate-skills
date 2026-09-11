---
name: ship
description: End-to-end autonomous workflow — analyze, implement, lint/fix, commit, open a PR, and resolve review findings. No interruptions. Use for a single feature that should land as one PR. Not for multi-PR programs (use sprint instead).
argument-hint: [feature/task description]
---

# Ship: Autonomous End-to-End Implementation

Execute the full lifecycle for **$ARGUMENTS** — from analysis through PR review — without pausing for user approval between phases.

> **CRITICAL**: Do NOT use plan-mode enter/exit. Do NOT stop to ask the user for approval between phases. Proceed autonomously through every phase below. If you encounter ambiguity, make a reasonable decision, document it, and keep moving.

> **When NOT to invoke**: scope that needs multiple PRs or an integration branch → `/sprint`. A batch of small *unrelated* TODOs → `/todo-batch` if that skill is installed.

---

## Phase 0: Worktree Setup (parallelize with Phase 1)

**Always use a git worktree** unless the user explicitly says otherwise (e.g., "implement in this branch", "no worktree").

Discover the project's worktree convention (a `/worktree` skill, `just wt-*` recipes, or README). If none exists:

```bash
REPO=$(basename "$(git rev-parse --show-toplevel)")
FEATURE="<feature-name>"
git worktree add "../${REPO}-${FEATURE}" -b "feat/${FEATURE}" main
cd "../${REPO}-${FEATURE}"
# Copy gitignored files the app needs (.env, secrets) from the main checkout
```

> **DB MODE**: Prefer a **shared** database when the task is code-only. Use an **isolated** database when the task mentions migration, schema change, or a new table.

> **IMPORTANT**: After worktree creation, **all commands for the rest of this workflow** must run inside the worktree directory. The shell may reset cwd between commands — always `cd` to the absolute worktree path. Verify with `pwd && git branch --show-current` before any destructive operation.

Boot the local stack using the project's documented command (`just up`, `docker compose up`, etc.). If boot is slow, launch it in a background subagent and proceed to Phase 1 in parallel.

---

## Phase 1: Analyze

Perform a focused analysis. Follow the `/analyze` skill if it is installed.

### Steps
1. **Clarify scope** — identify key functionality to add or modify, note constraints
2. **Explore existing code** — Glob, Grep, Read; map data flow; identify patterns to follow
3. **Architecture review** — discover backend and frontend layouts from the repo (do not assume a stack). Check services, APIs, schemas, UI routes, and tests as relevant
4. **Identify affected areas** — files to modify, schema changes, API changes, test impacts
5. **Create implementation plan** — write `docs/<feature-name>-plan.md`:
   - Sequence of changes, file-by-file breakdown, key details, edge cases
   - **Browser test scenarios** (if UI changes) — navigation paths, preconditions, actions, expected results (see `/analyze` step 6). These are the initial test blueprint.

### Output
Briefly summarize the plan in conversation, then **immediately proceed to Phase 2**.

---

## Phase 2: Implement

Execute the implementation plan inside the worktree.

### Guidelines
- **Read before editing** — always read existing files first
- **Follow existing patterns** — match surrounding code style
- **Minimal changes** — only change what's necessary
- **No over-engineering** — don't add unrequested features
- **Use in-container helpers** when the project has them — do not run host language tooling that corrupts container caches

After implementation is complete, **immediately proceed to Phase 3**.

---

## Phase 3: PR-Ready (Lint, Fix, Clean)

### Pre-flight
- Run `pwd && git branch --show-current` to confirm location and branch
- Run the project's environment-ready command if one exists (self-healing local stack). If it fails, abort — the environment is unrecoverable from this context.

### Checklist
1. **Identify changed areas** — `git diff`, file patterns
2. **Run the project's full-lint command** and fix all issues (preserve intended functionality). Do not substitute partial sub-commands that skip CI gates.
3. **Iterate until clean** — fix lint/type errors, re-run until exit zero
4. **Audit changes** — remove redundancies, minimize footprint
5. **Independent code review** if the project uses cubic (or equivalent):
   - Uncommitted changes: `cubic review -j`
   - Clean tree: `cubic review -b -j`
   - Address legitimate P0/P1/P2. Skip false positives with a brief justification.
   - REPEAT steps 2–5 until legitimate feedback is addressed.
6. **Generate PR metadata** — title, description, testing notes (target `main` unless the repo uses another default). The test plan should reflect the **final** code, not only the Phase 1 plan.

After all checks pass, **immediately proceed to Phase 4**.

---

## Phase 4: Browser Testing (if applicable)

**Skip this phase** if the changes are backend-only, infrastructure-only, or have no user-facing UI impact. Proceed directly to Phase 5.

> **Where to test — in the worktree, not by switching the main checkout.** Do not clobber WIP on MAIN. Point tests at the worktree's own URL. If the worktree lacks fixtures, share MAIN's DB (code-only) or seed the worktree DB.

Use the `/browser-tests` skill for Playwright proof-of-work (screenshots/video/trace, DOM assertions, self-contained specs). Interactive Chrome/Playwright MCP is fine for visual checks you want to watch live.

### Production vs dev UI
For substantial, multi-spec proof-of-work, prefer a production build when the app is Next.js (or similar) with expensive on-demand compile. Playwright **wipes `test-results/` at the start of every run** — run all POW specs in one invocation, or copy evidence out between runs.

### Auth
Assume the user is already logged in when a shared session exists. If you hit an auth wall, **do not attempt to fix auth** — skip the blocked scenario, note it, and continue.

### Test loop
For each scenario: navigate → act → verify → on failure, delegate a fix to a background subagent, continue other scenarios, then re-test. After fixes, re-run full lint.

After browser testing, **immediately proceed to Phase 5**.

---

## Phase 5: Commit & PR

### Pre-flight
- Confirm you're on the feature branch (not `main` or `dev`)

### Steps
1. **Stage changes** — `git add` specific files (not `git add -A`)
2. **Commit** with conventional commit message:
   - Format: `<type>[optional scope]: <description>`
   - Types: feat, fix, refactor, docs, test, chore, build, ci, perf, style
   - Do NOT include "Co-authored by Claude"
3. **Push** — `git push -u origin feat/<feature-name>`
4. **Create PR** — `gh pr create --base main` with:
   - Concise title (under 70 chars)
   - Summary section with 1–3 bullet points
   - Test plan section
   - **Browser proof-of-work as artifacts** when Phase 4 captured screenshots/video — embed key frames or `gh pr comment` them. Copy out of `test-results/` first.
5. **Return the PR URL**

After the PR is created, **immediately proceed to Phase 6**.

---

## Phase 6: PR Review Loop

Reach this phase only once **local validation (Phases 3–4) completed and the PR was pushed (Phase 5)**.

Invoke the **`/pr-review-loop`** skill: it watches cubic/codex (or equivalent bot reviewers), addresses legitimate feedback, pushes fixes, and loops until bots pass clean.

> **Run from inside the worktree.** Do **not** run Phase 7 cleanup until the loop reports a clean pass.

> **Autonomy override — a stuck bot never blocks the ship.** If the loop reaches its bot-wait timeout because reviewers are delayed or stuck pending, do **not** pause to ask whether to keep waiting. Record still-pending reviewers and proceed to Phase 7. Findings that do land are still addressed and re-pushed.

After the review loop passes clean, **immediately proceed to Phase 7**.

---

## Phase 7: Worktree Cleanup

Run from **inside the worktree directory**:

1. **Stop the worktree stack** — project's compose/down command
2. **Remove containers + volumes** if the project documents it
3. **Remove the worktree** from the parent directory:
   ```bash
   git worktree remove <worktree-path>
   ```

This only removes the worktree directory and its containers. The feature branch and remote PR remain intact.
