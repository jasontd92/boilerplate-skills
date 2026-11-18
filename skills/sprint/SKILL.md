---
name: sprint
description: Large scope, multi-PR coding project orchestration — CEO/PM/EM/Verifier/Designer pattern. Use for refactors, schema migrations, or multi-surface features spanning N parallel workstreams. Two shapes: workstreams converging into one CEO-gated cutover PR (when the work must land atomically), or independent PRs straight to main (when each chunk ships alone). Not for single-PR features (use ship instead).
argument-hint: [sprint name / one-line scope]
allowed-tools: Bash, Read, Edit, Write, Grep, Glob, Agent, Task, WebFetch
---

# Sprint

`/sprint` is the orchestration pattern for projects that `/ship` is too small for. Where ship is **one feature → one PR → done**, sprint is a refactor or feature that spans:

- Multiple sub-PRs — either into a long-lived integration branch, or straight to `main` (see `## Choose the shape` below)
- Multiple agent sessions, often across human time off
- Coordination across **five** distinct roles: CEO, PM, EM, Verifier, Designer

This skill is the durable encoding of a pattern proven on real multi-PR work. The rules in `## Critical gotchas` and `## Multi-agent orchestration hazards` are battle-tested — each one cost wall-clock time when learned, so don't relax them without a reason.

> **When to invoke**: scope can't be one PR. First signal is "this needs to be broken into workstreams".
> **When NOT to invoke**: one-PR features → `/ship`. A batch of small *unrelated* TODOs → `/todo-batch` (that batches N trivia into ONE PR; this splits N coupled workstreams across many). Single-bug investigations → `/investigate`. Plan-mode review of an existing plan → `/plan-eng-review` / `/plan-ceo-review`.

---

## Choose the shape FIRST

**Before Stage 0, answer one question. It changes Stages 1, 5 and 6.**

> **Can any single chunk land on `main` alone and leave the system coherent?**

| | **Independent** (yes) | **Cutover** (no) |
|---|---|---|
| Delivery | N independent PRs → `main` | N sub-PRs → integration branch → 1 cutover PR |
| Typical work | additive columns w/ defaults, new event properties, a new page, new endpoints | rename across producer+consumer, schema swap where old and new can't coexist, a contract change with N call sites |
| Risk arrives | spread across N merges | **all at once**, at the cutover gate |
| CEO gate | delegated per-PR merge criteria | the cutover click |
| Stage 1 | no integration branch | create integration branch |
| Stages 5–6 | skip (no cutover) | full |

**Default to Independent unless atomicity is genuinely required.** When the work is additive, a cutover is pure cost: an integration branch that rots behind `main`, a serialized queue, and one gate where N chunks' worth of risk arrives simultaneously. A half-shipped *additive* state is survivable; a half-shipped *rename* is not.

**Sanity check before committing to Independent**: for each chunk, ask "if only this one merged and the rest were abandoned, is `main` still correct?" If every answer is yes, take Independent. One "no" means either the cutover shape, or a dependency edge you must encode in dispatch order.

🔴 **Independent shape does not mean unordered.** Dependencies still serialize (a schema chunk gates the chunks that read the schema). Record the edges in tracker §3 dispatch order and enforce them.

🔴 **Whichever shape: verify `main` (or the integration tip) is green between merges.** If backend tests run only post-merge in your repo, a break surfaces one merge late — stacking N PRs on a broken base is the failure this prevents. If it goes red, HALT the queue.

---

## The five roles

| Role | One-line responsibility |
|---|---|
| **CEO** | The claude code user. Strategic direction, scope decisions, merge approval on cutover, dismissal authority on review findings. Async. |
| **PM** | Tracker custody, EM orchestration, regular check-in cadence, decision surfacing, cleanup. Does NOT commit code. **Never reads code, never debugs.** |
| **EM** | ONE chunk end-to-end (investigate → implement → review-loop → cubic-clean → merge → handoff). Fresh context per chunk. **Marks no acceptance criteria.** |
| **Verifier** | Fresh, read-only, per-chunk. The ONLY actor that ticks acceptance criteria. Dispatched after the EM exits. |
| **Designer** | Up-front per-workstream spec creation BEFORE EMs are dispatched. Optional but high-leverage. |

A single person/agent can play multiple roles across a sprint, but at any one moment the role being played should be unambiguous — the rules differ.

### CEO
- Sets sprint scope. Approves the workstream list at Stage 0 sign-off.
- Decides scope expansion/contraction when EM/PM surface "we found X, do we fix it now?"
- Owns the morning click on the cutover PR. Branch protection on `main` is the gate.
- Authorizes ad-hoc cubic dismissals; PM/EMs can dismiss only when rationale is unambiguous AND they post a visible thread comment.
- Works async: gives a directive, signs off, returns later. Reads the tracker first.

### PM
- **Tracker custody.** Only writer to the tracker file outside EM handoff commits. Appends §1 updates and transcribes CEO directives verbatim into §2.
- **Dispatch.** Reads §1 + §3 → picks the right EM type → writes a self-contained brief → dispatches via the `Agent` tool with `subagent_type: general-purpose` and a `name:` so it's addressable via `SendMessage`.
- **Cadence.** `ScheduleWakeup` at a cadence proportional to the work — tighter for review-loops where cubic can stall, looser for long-running tests. Cache-window math (Anthropic prompt cache TTL is 5 min): 270s stays warm; 1200s+ amortizes one cache miss; avoid 300s (worst-of-both).
- **Decision surfacing.** When EM returns "found X", PM either decides (preferred, if scope is clear) or escalates to CEO via a morning report.
- **Cleanup.** After each chunk merges: stop the worktree's container, remove worktree from main checkout, prune, fast-forward main checkout, update §1.
- **Boundary**: PM does NOT take git/PR actions unless explicitly directed. PM commits tracker docs; EMs commit code; CEO merges cutover.

### EM (Engineering Manager — one chunk)
- Fresh general-purpose subagent. Short-lived; exits when chunk merges.
- **Reads tracker §2 (durable CEO directives) and §3 (prior decisions) first.** §2 overrides anything else.
- **Investigates first if scope is ambiguous.** Reads the workstream design doc, greps callsites. Doesn't trust line numbers in briefs — they drift.
- **Owns the review loop.** When cubic and codex post findings, the EM addresses them followign the directions in the pr-review-loop skill file. PM does NOT step in unless the EM has truly exited with findings remaining.
- **Resolves threads via GraphQL.** Cubic auto-resolution is UNRELIABLE; codex NEVER auto-resolves. Always verify the unresolved-thread count after a fix push.
- **Merges the sub-PR** with `gh pr merge <N> --merge --delete-branch` when cubic-clean + 0 unresolved + tests/lint green.
- **Writes a §3 handoff entry** before exit, naming: integration tip after merge, what shipped, gotchas surfaced, drift vs §1 at start.
- **Tears down its worktree** (see `## Critical gotchas` for the order).

EM types:
- **Impl EM** — fresh chunk, full toolkit, own worktree
- **Review-loop EM** — sub-PR open with findings, impl EM exited; uses `/pr-review-loop` semantics; often main checkout, no worktree
- **Investigation EM** — read-only scope discovery; produces a gap doc to `/tmp`; no commits, no edits
- **Coverage-investigator EM** — pre-cutover audit; reads tests + production code; produces coverage matrix
- **Runner EM** — executes the browser/integration suite; tees output to a CEO-tailable logfile

### Verifier (one per chunk — NOT optional)

**The implementing EM never marks its own acceptance criteria.** Self-certification is where "reaching" happens: the agent that wants the chunk closed is the worst judge of whether it is. After an EM exits, PM dispatches a **fresh, read-only** verifier that reads the PR diff plus the EM's artifacts and is the **only** actor permitted to tick boxes. Fresh context is the point — no sunk cost in the implementation it's judging.

This applies to **both shapes**. Under a cutover it matters more, not less: the cutover is a single moment where you most want to know each chunk is real.

- **Read-only toward code.** No edits, pushes, merges, or re-running the work. Permitted writes: ticking criteria boxes in the acceptance-criteria doc, and any issue-tracker mirror. Mutations for verification are allowed **only** in its own disposable worktree, reverted with a clean tree confirmed afterward.
- **Reproduces, doesn't trust.** Re-runs the command and compares output; queries the live system rather than reading the doc that describes it. "The EM said X" is not evidence.
- **Classifies every criterion before judging it:**

| Type | Evidence | Who marks it |
|---|---|---|
| **Mechanical** — lint EXIT 0, CI green, a string in zero files, a percentage | a command **and its output** | verifier re-runs it |
| **Empirical** — payload correct, event delivered, migration applied | test output / live query result | verifier compares artifact to criterion |
| **Judgment** — is this mapping *right*? is the page usable? | none | **human**, via morning report |

- 🔴 **A criterion that cannot be mechanically or empirically checked is not a checkbox — it is a question for the morning report.** Otherwise agents tick boxes on vibes.
- 🔴 **Untick-with-reason beats tick-on-vibes.** If a criterion is blocked, say `FAILED` or `UNVERIFIABLE` with why. Blocked is not met, however reasonable the workaround sounds.
- 🔴 **Report claims that did NOT hold, including unflattering ones.** A verdict is trustworthy because of what it refuses to confirm.
- **Beware fused criteria.** A single tracker/issue checkbox often bundles two criteria — one met, one not. Tick only when a box's text is **fully** covered. A partially-true tick reads as "delivered" and nobody re-checks it.

**Verifier verdict format** (PM reads only this):
```
VERIFIER: <chunk> — <PASS | FAIL | PASS WITH GAPS>
criteria met:   <n>/<total>
  - <criterion> → <evidence checked; reproduced or not>
criteria FAILED:      <list, or none>
criteria DESCOPED:    <with the decision reference>
criteria HUMAN:       <judgment calls for the CEO>
UNVERIFIABLE:         <with why>
claims that did NOT hold: <list, or none>
```

**Why it earns its cost**: on the run this pattern was hardened, per-chunk verifiers caught an EM's "zero exceptions" claim being false (it was 198 of 8,154), a `main` that was reported green but whose integration suite had been concurrency-cancelled, a merge gate that was post-merge detection rather than pre-merge prevention, and a live production exposure sitting **entirely outside every acceptance criterion**. All four would have shipped labelled "verified."

### Designer
The sometimes-skipped upfront role. Validates per-workstream specs from a UX perspective BEFORE EMs are dispatched. This is the high-leverage layer — a well-written workstream doc is the difference between an EM that ships cleanly and one that wastes time grepping.

Designer can chain with gstack-family skills:
- `/office-hours` — pre-design brainstorming (forcing questions)
- `/plan-ceo-review` — scope expansion / hold / reduction
- `/plan-design-review` — designer's-eye review for UI surfaces

Designer is **optional for small sprints**. If scope is unambiguous and EMs won't make scope decisions, skip and have PM write thin workstream stubs in Stage 1.

| | Designer | EM |
|---|---|---|
| When | Stage 0 (before tracker exists) | Stage 3 (after tracker bootstrap) |
| Output | `docs/<feature>/workstream-NN-*.md` | Code + sub-PR + tracker §3 handoff |
| Edits code? | No | Yes |
| Talks to CEO | Yes (scope) | No (PM intermediates) |

---

## The staged workflow

```
Stage 0 — Sprint definition        (Designer + CEO)
Stage 1 — Tracker bootstrap        (PM)                    ← shape-dependent
Stage 2 — Workstream decomposition (PM)
Stage 3 — EM dispatch + verify loop (PM driving, EMs, Verifiers)   bulk of the sprint
Stage 4 — Final audit              (PM + specialized EMs)
Stage 5 — Integration cleanup      (PM)                    ← CUTOVER SHAPE ONLY
Stage 6 — CEO-gated cutover merge  (CEO)                   ← CUTOVER SHAPE ONLY
```

Stages are sequential, but 3 and 4 often interleave (audit chunks dispatched mid-sprint to keep coverage moving).

**In the Independent shape**, Stages 5–6 collapse: there is no integration branch to clean up and no cutover to gate. Replace them with a single **Stage 5′ — Program close**: confirm `main` green on the final tip, run whatever suite gets concurrency-cancelled by a busy merge queue (integration/e2e) once against that tip, restore any borrowed checkout state, and write the morning report. Merge authority is delegated per-PR against explicit criteria rather than concentrated in one click, so §2 must state those criteria precisely.

### Stage 0 — Sprint definition (Designer + CEO)
1. CEO declares scope. Designer pushes back if vague.
2. Optional: chain `/office-hours`, `/plan-ceo-review`.
3. Designer decomposes scope into as many workdstreams as appropriate workstreams with clear inputs, outputs, dependencies.
4. One markdown file per workstream at `docs/<feature>/workstream-NN-<short-name>.md`: § Scope / § Pre-conditions / § Acceptance criteria / § Callsite map (best-effort) / § Test plan / § Risks & rollback.
5. Cross-cutting docs as needed: README (TOC + resolved-decisions log), integration-test-plan, migration-runbook, post-cutover canary.
6. CEO signs off on the workstream list.

**Exit gate**: `docs/<feature>/` exists with README + per-workstream files. CEO has approved.

### Stage 1 — Tracker bootstrap (PM)
1. Create the tracker file (see `## Tracker shape` below). Suggested location: `scripts/em-loop/tracker.md` or `docs/<feature>/tracker.md`.
2. §1 Active state: **the chosen shape**, integration tip or `origin/main` SHA, empty open-PRs/worktrees/subagents, next chunk = first WS.
3. §2 CEO directives: transcribe verbatim from CEO sign-off in Stage 0 + the binding rules from `## Critical gotchas` that apply to this repo. **Include the verification posture and the who-ticks-boxes table** (see Tracker shape).
4. §3 Per-chunk handoff log: pre-populate one stub per workstream, **in dependency order**.
5. **Cutover shape only**: create the integration branch from `main` and push.
6. Commit the tracker + design docs.

**Determine your binding physical constraint now, and derive concurrency from it** — don't inherit a number. Ask: what actually caps parallelism here? RAM (how many devcontainers/test VMs co-exist)? A shared database? A single seeded fixture set? Browser/Playwright runs that thrash the host? Write the resulting lane model into §2 as a rule, e.g. *"N code-only chunks may run concurrently in worktrees sharing one container; chunks needing the seeded runtime are serial in MAIN; browser runs are serialized program-wide and must claim the slot from PM."* The specific numbers are machine-specific and belong in §2, not in this skill.

**Make CI's test environment reproducible locally before Stage 3.** Every EM should be able to run the CI suite on their own machine with one command and get CI's result. That means the same browser or runtime image, the same fonts and locale, and the same service versions, typically by running inside CI's container image. Write the command into §2. Each class of failure that only shows up in CI (a layout that overflows under CI's fonts, a missing browser engine) costs a full push → wait → read-log round per occurrence, multiplied by every concurrent EM. It also burns deploy previews. If full parity isn't possible (e.g. one browser engine can't run locally), say in §2 which projects are CI-only, so EMs batch their changes to those projects rather than discovering them one push at a time.

**Exit gate**: tracker committed. Shape recorded. Concurrency model and the local CI-parity command written into §2. PM knows the first chunk to dispatch.

### Stage 2 — Workstream decomposition (PM)
Most decomposition was done by Designer. PM's job here is fast:
1. Verify dependency order. Reorder §3 stubs into dispatch order.
2. Flag investigation-first vs straight-to-impl chunks. A WS is investigation-first if the callsite map is suspect, the data shape isn't fully understood, or there's a flagged production-bug-shaped concern.
3. Add audit chunks at the end: `integration-audit`, `browser-tests` (Runner EM, primary local env (MAIN) — see Gotcha #11b), `coverage-fill`, `cutover-finalize`.

**Exit gate**: §3 stubs are in dispatch order, each tagged with EM type.

### Stage 3 — EM dispatch + verify loop (PM)
The bulk of the sprint. Per-chunk PM cycle:

```
1. PM reads §1 — verify against reality:
     gh pr list [--base <integration-branch>]   ← matches §1 open PRs?
     git worktree list                          ← matches §1 worktrees?
     git rev-parse origin/<base>                ← matches §1 tip?
     gh run list --branch <base>                ← is the base actually green?

2. If DRIFT: append a one-line note to §3 and pivot to reality as authoritative.

3. Determine state for next chunk via §3 stub:
     (a) Not started        → fresh impl EM (preceded by investigation EM if ambiguous)
     (b) PR open, cubic cycling → review-loop EM
     (c) PR open, cubic-clean, threads unresolved → EM resolves + merges
     (d) PR open, ready to merge → EM merges
     (e) EM exited MERGED    → dispatch the VERIFIER for that chunk

4. Write a self-contained EM brief (see ## EM brief shape).
5. Dispatch via Agent tool: subagent_type general-purpose, name=<chunk>-<type>, run_in_background=true.
6. Arm a Monitor / ScheduleWakeup appropriate to what you're waiting on. Exit this iteration.

7. On wake or task-notification: re-read §3. If EM handed off: verify the merge, VERIFY THE BASE IS
   STILL GREEN, dispatch the verifier, move to the next chunk. If still working: gh pr view + git log;
   re-wake or SendMessage if stalled.

8. Read only the verifier's verdict. Never re-verify it yourself.
```

🔴 **A chunk is not done when it merges. It is done when its verifier reports.** Merging and verifying pipeline naturally — dispatch chunk N+1's EM while chunk N's verifier runs; they don't contend.

🔴 **The PM never reads code and never debugs.** Detect-stuck → dispatch a *fresh* diagnostic agent with the failure surface (job name, failing step, log excerpt). Inline debugging is unbounded context spend on exactly the path where reserve matters most, and it is what makes one PM able to supervise a dozen chunks across many hours. Escalation is a dispatch, not an investigation.

🔴 **A hand-back is not an exit.** An EM often hands back mid-gate: its report says `NOT MERGED`, with CI still running and a list of remaining steps. The harness may also mark the task "completed" while the agent's own background watcher (Monitor, CI poll) is still alive. Read the exit line, not the notification status:
- `MERGED` → verify the merge and dispatch the verifier.
- `NOT MERGED` with remaining steps → if the notification says the agent has live background work, it will resume on its own; wait for the next notification. Otherwise `SendMessage` it with "resume: finish steps N–M" plus any ruling it asked for.
- **Never dispatch a duplicate EM for a chunk whose agent can still be resumed.** Two agents on one PR race each other's pushes and merges.
- Require EMs to end every hand-back, final or not, with the exact remaining steps. Then a resumed agent, or a fresh one if it can't be resumed, needs nothing else.
- Usage-limit or rate-limit terminations are the same case. Resume each agent once the limit resets; its work so far is saved.

When EMs stall (no movement >20 min after cubic completes, or task-notification "completed" but branch tip unchanged):
1. Wait a bit longer — cubic may not be done.
2. SendMessage to the EM's `agentId` with a specific next-step prompt. **This revives a completed agent — feature, not bug.**
3. Dispatch a fresh review-loop EM if the impl EM truly cannot continue. Use `general-purpose` (NOT `claude` — `claude` can trigger the `WorktreeCreate` hook).

**Exit gate**: all non-audit chunks have a `MERGED` entry in §3. Integration tip is at the last sub-PR's merge commit. No live worktrees/subagents.

### Stage 4 — Final audit (PM dispatching specialized EMs)
1. **Coverage-investigator EM** (read-only). Produces `docs/<feature>/coverage-audit-final.md` with: per-WS test coverage matrix, untested code paths, suspected bugs from un-addressed review-loop comments.
2. **Runner EM** (runs in the primary local env, on the integration branch — NOT a worktree). Owns the integration + browser matrix. Seeds fixtures first after a fresh DB, then runs the project's primary-env browser-test command, teeing output to `scripts/em-loop/logs/<sprint>-runner.log` (gitignored, CEO-tailable). Captures evidence under `test-results/`. Pushes evidence to a GitHub release. The browser matrix is a single Stage-4 chunk, not per-WS (see Gotcha #11b).
3. **Surface findings to CEO.** If runner finds production bugs: open as `Bx` blockers in cutover PR body. CEO decides: fix-loop, defer, or accept.
4. **Open cutover PR as DRAFT** with explicit blocker list:
   ```bash
   gh pr create --draft --base main --head <integration-branch> \
     --title "<sprint title>" --body-file <body.md>
   ```
   For subsequent body edits use `gh api -X PATCH repos/<org>/<repo>/pulls/<N> -F body=@<file>` — `gh pr edit --body-file` fails with the Projects-classic GraphQL deprecation.

**Exit gate**: cutover PR opened (DRAFT). All blockers documented. Coverage audit + runner evidence published.

### Stage 5 — Integration cleanup (PM) — **CUTOVER SHAPE ONLY**
*(Independent shape: do Stage 5′ — Program close instead. See the stage list above.)*
1. Tear down lingering worktrees (see `## Critical gotchas` for the exact order).
2. Confirm `docker ps` shows only the main devcontainer.
3. Fast-forward main checkout: `git checkout <integration-branch> && git pull --ff-only`.
4. Sanity checks (not gates): deps re-sync + the project's full-lint command (or equivalent), focused-scope tests.
5. Verify cutover PR state. Update §1 + commit tracker.

**Exit gate**: 0 live worktrees/subagents/unmerged sub-PRs. Cutover PR in terminal state (see Stage 6).

### Stage 6 — CEO-gated cutover merge — **CUTOVER SHAPE ONLY**
Target terminal state on the cutover PR BEFORE handing off:
- `mergeStateStatus = BLOCKED` ← **expected**, not a failure
- `reviewDecision = REVIEW_REQUIRED` ← **expected**, this is the CEO gate
- `isDraft = false` ← flipped via `gh pr ready <N>` (often done by CEO directly)
- All CI checks SUCCESS (or `cubic: SKIPPED` on a merge-commit tip — see gotcha)
- 0 unresolved review threads
- 0 outstanding blockers in PR body

This combination is the **CEO-gated terminal-clean state**. Branch protection on `main` requires human approval — that's the CEO's morning click.

PM writes a morning report (see `## Morning report shape`), exits, does not loop waiting. CEO will approve + merge, or send back with concerns (→ new sub-PR, new chunk, normal Stage 3 cycle).

---

## Tracker shape

The tracker is the single durable artifact of the sprint. Append-mostly. Lives at e.g. `scripts/em-loop/tracker.md`.

```markdown
# <Feature> Refactor — Execution Tracker

> Single source of truth for the multi-session EM rotation. Append-only.
> Each EM iteration verifies §1 claims against reality before acting.

## §1 Active state

- **Shape**: <INDEPENDENT PRs to `main` | CUTOVER via integration branch> — and the one-line reason
- **Ground truth**: GitHub PR state (`gh pr view --json state,mergeStateStatus,statusCheckRollup`). Any issue tracker is a projection, never the control plane.
- **Base branch + tip**: `<origin/main | feat/<name>>` @ `<SHA>`
- **Base health**: <green/red + the run you checked>
- **Open PRs**: <list, or "none">
- **Open cutover PR**: <#NNNN state | N/A — independent shape>
- **Live worktrees**: <list, or "none">
- **Live subagents**: <name+role+state, or "none">
- **Merged + verified**: <chunk → sha → verdict>
- **Next chunk**: <WS or NEXT-STAGE>

## §2 CEO directives (durable — read every iteration)

### Workflow
- One EM owns ONE chunk end-to-end (dispatch → cubic-clean → merge → handoff → exit).
- Each impl EM owns its /pr-review-loop until cubic-clean.
- Sub-PRs merge into <integration-branch> via `gh pr merge <N> --merge --delete-branch`.
- Cutover PR is its own chunk. CEO-gated.

### Pre-merge gates
- Unit tests pass on the chunk scope.
- Cubic re-review on the latest commit is clean AND all review threads are resolved on GitHub.
- Lint passes — **and the EM names which tree it linted, and attaches the log to the PR before cleanup.** "EXIT 0" without naming the tree is not evidence, and a worktree's log evaporates when the worktree is removed.
- The base is green **at the moment of merge** — re-queried, not inherited from a status report.
- (Optional) Integration test suite runs at the audit chunk, not per-WS.

### Verification posture (write this explicitly — it prevents both over- and under-testing)
State the **blast radius** in one line, then name the **short list of things that are actually gates**. Everything else is ship-and-observe. Example: *"Blast radius is a wrong dashboard — no customer impact, no data corruption, and events are re-derivable. Default is ship-and-observe. Hold the line on exactly three things: <A>, <B>, <C>."*
- Where a workstream doc demands heavier validation than this section, **this section supersedes it.**
- Also list what was **explicitly cut**, so a later agent doesn't helpfully reintroduce it.
- 🔴 Anything on the "hold the line" list must be **proven, not asserted** — see the mutation-testing rule in `## Multi-agent orchestration hazards`.

### Who ticks acceptance criteria
- **The implementing EM never marks its own boxes.** It produces evidence and lists `criterion → artifact` in its exit summary.
- **A fresh read-only Verifier** is the only actor that ticks boxes.
- **PM** reads only the verdict; never verifies, never reads code.
- **CEO/human** owns judgment-type criteria and anything the verifier reports UNVERIFIABLE.
- **Merge gate is GitHub state + verifier verdict, never the issue tracker.**

### Commits & PRs
- Conventional Commits (feat/fix/refactor/docs/test/chore/perf/style/build/ci) with optional scope.
- NEVER include "Co-authored by Claude" trailer.
- `git add <specific files>` — NEVER `-A`.

### Devcontainer & worktrees
- 2-devcontainer cap on this machine. One impl worktree at a time.
- Use the project's in-container helpers (or equivalent) for in-container build/test/lint.
- Worktree teardown order: stop container FIRST from inside the worktree, THEN remove from main checkout.

### Sub-agent lifecycle
- SendMessage to a "completed" subagent REVIVES it.
- Cubic auto-resolution is UNRELIABLE; codex NEVER auto-resolves. Always GraphQL-resolve threads.
- Dismissed cubic warnings MUST have a visible thread comment.

## §3 Per-chunk handoff log

### WS1 — <short name> — <NOT STARTED | IN PROGRESS | MERGED | VERIFIED>
- PR: #NNNN → merge commit `<sha>`
- Cubic: clean on `<sha>` (N threads resolved, count re-queried via GraphQL at merge)
- Tests at merge: <N/M> · CI step confirmed RAN by name: <step>
- Lint at merge: EXIT 0 **on tree `<path>`** (log attached to PR)
- Base green after merge: <run id + conclusion>
- **VERIFIER VERDICT**: <PASS | PASS WITH GAPS n/m | FAIL> — <failed/unverifiable items>
- DRIFT vs §1 at iteration start: <note or "none">
- Notable decisions: <2-5 bullets>
- Gotchas surfaced: <bullets>

### WS2 — ...
```

---

## Shared brief files (write once, reference from every brief)

Most of a brief repeats across chunks: hard rules, process, gates, exit format. Write those **once** per role, as a file in the PM's scratch directory:
- `em-common.md`: repo facts, what's already on main, the hard rules, the process steps and the exit-summary format.
- `verifier-common.md`: read-only rules, the disposable-clone procedure, "reproduce, don't trust", criterion classification, the one-push verdict write and the verdict format.

Each per-chunk brief then says "read `<common file>` first and follow it exactly", and adds only what this chunk needs: scope, criteria and claims. Briefs shrink to a fraction of their size, rule changes reach every later dispatch at once (update the file, then tell live agents), and nobody re-derives the gate. When the PM changes a common file mid-sprint (e.g. a new merge-race rule, or a deploy-quota rule), it also `SendMessage`s the agents already running, because they read it once at start.

🔴 **The two files are separate on purpose, and the verifier's file must not erode independence.** The failure mode is a reviewer who shares the implementer's framing: briefed by the same text, the verifier inherits the same assumptions and stops looking where the EM stopped. So:
- A verifier never receives the EM common brief, the EM's chunk brief, the EM's transcript or scratch notes, or the PM's opinion of how the chunk went.
- The verifier common file holds only *method*: how to verify, what counts as evidence, the verdict format. It never holds facts about the code or how it's expected to behave. Every fact a verifier needs about the chunk reaches it as a **claim to test** in its chunk brief (see `## Verifier brief shape`).
- The verifier reads the tracker's §3 handoff because that is the list of claims under test, not context to adopt. Say so in its brief.
- Don't let a common file grow into a shared design doc. If a rule says what the code *should* do, it belongs in the workstream's acceptance criteria, where the verifier can test it, not in a brief both roles read.

## EM brief shape

Self-contained. EM has fresh context — assume they know nothing about prior chunks except what they read from the tracker. Put everything reusable in `em-common.md` (see `## Shared brief files`), and keep the per-chunk brief to scope, criteria and chunk-specific traps.

```markdown
You are the **<chunk>-<type>** EM. Your job: <one-sentence scope>.

# Context
<What the sprint is. What this chunk does. What prior chunks shipped that this builds on.>

# Worktree (if needed)
<Path. Branch. Tip SHA. Setup steps already done. Devcontainer state.>
<OR: "Work in main checkout — no worktree needed (review-loop closeout / audit / runner).">

# Read first (in this order)
1. `scripts/em-loop/tracker.md` §1, §2 (durable CEO directives — non-negotiable), last few §3 entries for context.
2. Workstream design doc: `docs/<feature>/workstream-NN-*.md`.
3. <Any other domain-specific docs.>

# Hard rules (from tracker §2)
- 🔴 **VERIFY THIS BRIEF — do not trust it.** Line numbers drift; the PM can be wrong about shas, file paths, prior decisions and mechanisms. Where this brief asserts a fact you're about to depend on, check it against the code, the tests, or the live system, and tell me if it's wrong. **This instruction is load-bearing: it is the main defence against a PM error propagating into N chunks.**
- 🔴 **You never mark your own acceptance criteria.** Produce evidence and pair it to each criterion; a fresh verifier ticks the boxes.
- NEVER merge the cutover PR (cutover shape).
- `git add <specific files>`, never `-A`. **Never `git stash`** — it is shared across worktrees and the user may have a deep stash stack.
- Conventional commits, never "Co-authored by Claude" trailer.
- Use the project's in-container helpers, never host language tooling.
- Cubic auto-resolution unreliable, codex never auto-resolves — always GraphQL-resolve threads.
- Dismissed cubic warnings MUST have a visible thread comment.
- **Escalate rather than decide** anything in the tracker's HALT column. "It seemed obviously right" is not authority.

# Process
1. Pre-flight: `git fetch && git rev-parse origin/<integration-branch>` — matches tracker §1?
2. Implement the chunk per workstream doc.
3. Open sub-PR: `gh pr create --base <integration-branch> --head <chunk-branch> --title "..." --body-file ...`.
4. Own the review loop. Address findings. GraphQL-resolve threads.
5. Pre-merge gate: cubic SUCCESS + 0 unresolved + lint EXIT 0 + tests green.
6. Merge: `gh pr merge <N> --merge --delete-branch`.
7. Append a tracker §3 handoff entry. Commit + push.
8. Tear down worktree (see gotchas for order).
9. Exit with: `EM-EXIT: <chunk> MERGED at <SHA>`.

# Exit summary format
EM-EXIT: <chunk> MERGED at <sha>
TESTS: N/M
LINT: EXIT 0 on tree <path>            ← name the tree; attach the log to the PR
CI STEP RAN: <step name, pulled from the run trace>   ← that it ran, not that the file exists
DECISIONS: <bullets>
GOTCHAS SURFACED: <bullets>
CRITERION → EVIDENCE:
  - <criterion> → <command + its output, or artifact path>
NEXT CHUNK READY: <WS or NEXT-STAGE>
```

For investigation EMs, swap the Process with: read-only, produce a structured gap doc to `/tmp/<feature>-coverage-audit-<ts>.md`, report path back, no commits.

---

## Verifier brief shape

Fresh context is the whole point — assume it knows nothing and give it everything it must test. Method goes in `verifier-common.md`. Chunk facts go here, phrased as claims to test. Never pass along the EM's brief or reasoning (see `## Shared brief files`).

```markdown
You are a **fresh, read-only verifier** for <chunk>. You did not implement this and have no stake in it.

# Authority and limits
- You are the ONLY actor permitted to tick acceptance criteria.
- Strictly read-only toward code. Permitted writes: criteria boxes in <doc>, and <issue tracker> if used.
- Mutations for verification ONLY inside your own disposable worktree; revert and confirm a clean tree.

# What to verify
PR #NNNN, MERGED at <sha>. Criteria: <path to acceptance-criteria doc>.

# Classify, then judge
Mechanical → command + output, re-run where cheap. Empirical → artifact vs criterion.
Judgment → DO NOT TICK; mark HUMAN. A criterion that can't be mechanically or empirically
checked is not a checkbox — it is a question for the morning report.

# Claims to test, not trust
<Every substantive claim the EM made, listed individually. Include the numbers so the verifier
can compare. Say plainly: "the EM claims X — verify it.">

# Scope rulings you must apply, not relitigate
<Anything the CEO descoped, cut, or already decided — with the decision reference. Mark descoped
criteria DESCOPED, not FAILED, and state honestly that they are undelivered.>

# NOT gaps — do not penalize
<Explicitly cut verification, pre-existing failures, out-of-scope items.>

# Traps
<Known false-reds, env vars that flip local behaviour, anything that will look like a defect.>

# Report — the PM reads only this
<the verdict block from ## The five roles → Verifier>
Be blunt in both directions. Send the verdict block when done; do not go idle without it.
```

---

## Morning report shape

PM-to-CEO async handoff. Lead with the decision/answer.

```markdown
## Morning report — <feature>

**TL;DR: <Merge | Hold for X | Decision needed on Y | Shipped, N decisions for you>**

### What landed
| chunk | PR | merge sha | verifier verdict |
|---|---|---|---|
| <WS> | #NNNN | `<sha>` | PASS / PASS WITH GAPS n/m / FAIL |

Base health: <green on every merge commit? name the runs>

### CUTOVER SHAPE — cutover PR state
- Tip `<sha>` · mergeStateStatus BLOCKED + reviewDecision REVIEW_REQUIRED ← CEO-gated terminal state
- isDraft false · CI checks <list> · Unresolved threads 0
### Morning click sequence
1. (Optional) `gh pr view <N>` — confirm checks.  2. Approve → merge to `main`.

### INDEPENDENT SHAPE — deploy / sequencing items
- <anything that must happen in a particular order at deploy, with the consequence of getting it wrong>

### Decisions for CEO
| # | Question (plain words) | What was shipped by default | Options and what each gains/loses | Recommendation |
|---|---|---|---|---|
| 1 | <the question, with enough context to answer cold> | <current behaviour> | <A: gains / loses · B: gains / loses> | <one line, and why> |

### Flagged UNVERIFIABLE by verifiers
- <criteria no agent could check, and why — these are yours>

### Caveats worth knowing
- <known non-blockers, deferred items, anything to see before acting>

### Recommended follow-up chunks
- <found-but-out-of-scope work, sized>

### Cleanup state
- Worktrees torn down. Containers as expected. Borrowed checkout state restored.
- Parked branches: <list, with disposition notes>
```

🔴 **Every decision item must stand alone.** The CEO answers async and cold, often from a phone, without the tracker. Before sending, test each item: could it be answered with no follow-up question? If the CEO would have to ask "what does that mean?", "what's the open question?" or "what do I gain or lose?", the item isn't finished. Rules:
- State the question in the CEO's words, not the system's. Write "logging the same session twice in one day", not "multiple session records per date".
- When the answer lives in a doc, say what the choice actually is. "See open-questions.md" is not a decision item.
- Give each option's concrete gain and loss, and name the default already shipped, so "no reply" has a known meaning.
- Size the stakes honestly. Check a scary number before you lead with it (e.g. on-disk size vs. bytes over the wire).
- Number the items, so the CEO can reply "2: yes, 6: replace".

**Report what the verifiers refused to confirm, not just what passed.** The UNVERIFIABLE and judgment rows are the highest-value part of the report — they are the only things that reach the human by design rather than by accident.

---

## Multi-agent orchestration hazards

These are properties of running many agents concurrently, not of any one repo. Each one bit on a real run.

### The PM is a single point of failure for *facts*
**A1. Brief agents to verify rather than trust.** Prefer *"verify X yourself, don't trust this brief"* over asserting X. On the run that hardened this pattern, the PM made four factual errors in dispatch briefs — a wrong issue id, a wrong PR number, a rule stated unconditionally that was conditional, and a recommended fix that would have made a compliance gate see *less*. **All four died because the brief told the agent to check.** In a wide fan-out, an unchecked PM assertion propagates into every chunk.

**A2. A PM status report is a snapshot, never a clearance.** Never phrase status as permission. Say *"checks were green at <time>; re-verify checks, threads and base yourself."* Twice on one run, a "you're green, merge now" was followed by a genuine P1 landing in the gap between the PM's read and the EM's merge.

### Message delivery is not interrupt delivery
**A3. Mid-flight "stop" is unreliable.** Teammate messages arrive at turn boundaries and can batch, so a constraint sent during a long tool sequence lands *after* the action. **Put every hard constraint in the INITIAL dispatch.** When a stop must be sent mid-flight, say "stop if you are mid-write," treat it as best-effort, and **never read silence as compliance.**

**A4. Design briefs so the agent's own checks catch what a late message would have.** This is the durable form of A3 — see A1.

**A5. A record is not an authorization.** An agent must not infer approval from a tracker line, a doc it watched the PM edit, or from being last in a queue. Only a direct message grants permission. State this explicitly; it was violated once by an otherwise excellent EM.

### Agents idle; the PM is also a scheduler
**A6. An idle agent does not wake itself.** Agents waiting on CI go idle and stay idle. Arm a Monitor on the things you're waiting for — and **include the states that mean failure**, not just success, or a crashloop looks identical to "still running."

**A7. Monitor the chunks that haven't produced a PR yet.** The classic blind spot: a queue monitor watches open PRs, so a chunk stuck *before* opening one is invisible. One run lost ~8 hours this way. Watch branch commits too.

**A8. Merging does not release a serialized slot; the EM's exit does.** If a lane is "one at a time," define release as the `EM-EXIT:` block. A merged EM that keeps working in a shared checkout will collide with the next one — and check `git reflog` before any branch operation in a shared checkout, never `checkout -f`.

### Evidence hygiene
**A9. "The test file is listed" ≠ "the test ran."** Pull the step **and the individual test names** out of the CI run trace. On one run, four separate test files existed without ever executing — every one found by accident, none by a check.

**A10. A mutation harness that silently fails to mutate reports every mutant as killed.** Assert a changed-line count per mutant, and predict the blast radius before running — if reverting a load-bearing guard doesn't take down roughly the number of tests you expected, distrust the harness before the tests. One run's first mutation pass reported 8 vacuous passes because the harness ran where its patch tool didn't exist.

**A11. Prove a "no-call" assertion is not vacuous.** A refute that can never fire looks identical to a passing gate. Require **both**: a mutation showing the named refutes *fail* when the guard is reverted, **and** a paired positive control on the same path showing the interceptor is alive.

**A12. Never fix a flaky safety test by weakening its assertion.** Flushing, scoping, or adding a settle window all make the gate see less. Remove the nondeterministic *source* instead. A quiet gate is worse than a flaky one.

**A13. Same-SHA re-run passing = flake, not regression.** Before diagnosing a red base, check whether a re-run of the identical commit passes. It is the cheapest decisive test available and it prevents reverting innocent work.

### Review state
**A14. A review bot's green *check* is not a finished *review*.** Bots post findings after their own check goes green — five times on one run, yielding real P1s and P2s. **The unresolved-thread count is the gate.** Re-query it immediately before merging, and note that `gh pr view --json reviewThreads` is not a valid field — GraphQL is the only way, which is exactly why this gets missed.

---

## Critical gotchas (verbatim — these are non-negotiable)

Each one cost wall-clock time when learned. Don't relax without reason.

### Git / repo hygiene
1. **Never `git add -A`.** Repos typically have noisy modifications (gitignored-but-modified configs, submodule pointers, dev-server-touched assets, secrets candidates). Always `git add <specific paths>`.
2. **Never "Co-authored by Claude" trailer.** Project- or user-level CLAUDE.md may make this explicit.
3. **`.env.secrets` smudge filter fails on host.** For host-side git ops on worktree creation, pass `-c filter.<project-secrets>.smudge=cat -c filter.<project-secrets>.clean=cat` (or the project's equivalent).
4. **Auto-mutated files** (e.g. dev-server-touched `version.json`) — `git update-index --skip-worktree` in the main checkout to keep them out of the diff.

### Devcontainer + worktree
5. **Never run language-native build tools on the host** (e.g. `mix`, `pnpm install`) — they corrupt the devcontainer's caches. Always use the project's in-container helpers.
6. **2-devcontainer cap on a typical dev machine.** One impl worktree at a time.
7. **Worktree teardown order**: stop the devcontainer FIRST from inside the worktree (`docker compose -p <project-name> down`), THEN `git worktree remove --force <path>` from the main checkout (NEVER from inside the worktree — self-cwd-kill).
8. **`docker compose down` without `-p`** silently no-ops when the cwd has shifted. Always pass `-p <project-name>`.
9. **`gh pr merge --delete-branch` local-branch delete fails** when a worktree holds the branch. Order: stop container → `git worktree remove --force` from main → `git worktree prune` → `git branch -D <branch>` from main.
10. **Lockfile/deps re-sync needed** after cross-worktree teardown if a worktree touched a lockfile.
11. **Shared-DB worktrees can exhaust Postgres `max_connections`.** Each app holds a connection pool; two shared-DB worktrees can saturate the primary Postgres (even a `psql` probe is then refused). For worktree *unit* tests, run via `docker exec` into the primary app container (bypasses the worktree dev-server boot) or keep the worktree on its own isolated DB.
11b. **Browser/Playwright tests run in the primary local env, NOT in worktrees** unless that worktree has fixtures, auth, and an uncontended DB. The Stage-4 Runner EM runs the matrix from the main checkout on the integration branch (seed fixtures first after a fresh DB). Do not boot a worktree to run the browser matrix if fixtures + auth + flag overrides live only in MAIN.
11a. **Use the project's single full-lint command as the pre-merge gate, not piecewise sub-commands.** The full-lint helper (`just lint` or equivalent) runs every check that gates CI on `main`. Partial commands each cover only a slice and silently miss type/format/contract checks. EM briefs MUST require the full-lint command as the pre-merge gate.

### GitHub / PR workflow
12. **`gh pr edit --body-file` fails** with the Projects-classic GraphQL deprecation (exit 1, body NOT updated). Use `gh api -X PATCH repos/<org>/<repo>/pulls/<N> -F body=@<file>` instead.
13. **Cubic auto-resolution is UNRELIABLE.** Sometimes cubic auto-resolves when a finding is fixed on re-review; sometimes it doesn't (especially if the fix moved the finding's line). Always verify the unresolved-thread count via GraphQL after a re-review.
14. **Codex NEVER auto-resolves.** Always manually `addPullRequestReviewThreadReply` (closure note citing fix SHA) + `resolveReviewThread`.
15. **Cubic SKIPS merge commits whose constituents were cubic-clean.** Conclusion `SKIPPED` with title "AI review skipped for merge commit" coexists with terminal-clean state. Not a failure.
16. **`BLOCKED + REVIEW_REQUIRED` on the cutover PR = terminal-clean.** Branch protection on `main` requires reviewer approval; that's the CEO's morning click. EMs and PM should NOT treat BLOCKED-due-to-REVIEW_REQUIRED as a check failure.
17. **Cubic re-trigger can hang indefinitely.** If cubic stays at the same percentage >15 min after a successful prior re-review on the same SHA, treat the prior re-review's thread-resolution state as authoritative and proceed.

### Subagent lifecycle
18. **SendMessage to a "completed" subagent REVIVES it.** Task-notification "completed" means "current iteration ended" (monitor armed), NOT permanently terminated. Confirm idleness before re-dispatching for the same scope; revive with SendMessage if you want to continue the same agent.
19. **Use `subagent_type: general-purpose` + `name:` for EMs.** `claude` subagent type with `name:` can trigger an unintended `WorktreeCreate` hook.
20. **EMs can hit turn-budget ceilings on big chunks.** Pass a tighter scope, dispatch a review-loop EM after the impl EM exits, or break the chunk into two.

### State management
21. **DRIFT vs tracker §1 at iteration start is THE NORM.** Always verify §1's claims (integration tip, open PRs, worktrees) against reality. Pivot to reality as authoritative; append a one-line DRIFT note to §3.
22. **CEO can manually merge mid-iteration.** Detect via post-action `git fetch` + `git rev-parse origin/<branch>` divergence. Pivot from "I will merge" to "merged — do post-merge cleanup".
23. **Cutover PR head IS the integration branch.** Fixes for cutover-PR review findings commit DIRECTLY to the integration branch in the main checkout. No worktree, no sub-branch — a worktree can't check out the same branch the main checkout holds.

### Tooling cadence
24. **`ScheduleWakeup` cache-window math.** Anthropic prompt cache TTL is 5 min. Under 5 min (60–270s): cache stays warm — right for active work. 5 min – 1 hr (300–3600s): pay one cache miss; right when no point checking sooner. **AVOID 300s** — worst-of-both; either drop to 270s or commit to 1200s+.
25. **Cubic review fires in 2–15 min.** Bounded poll ~20 min after a push; if stalled, treat prior review as authoritative.

### CEO directive compliance
26. **Dismissed cubic warnings must have a visible thread comment** explaining why. Three closure paths: code-fix-and-resolve, cite-and-resolve (already-fixed elsewhere), dismiss-with-comment. All three end in `resolveReviewThread`. Dismissals without visible comment are not acceptable.
27. **Honor tracker §2 on extra gates.** Do not invent soak/staging holds unless the CEO directives require them. Default: production-readiness is the bar; soak is post-merge unless §2 says otherwise.

---

## GraphQL snippets for review-thread management

```bash
# List unresolved threads on a PR:
gh api graphql -f query='query{repository(owner:"<org>",name:"<repo>"){pullRequest(number:<N>){reviewThreads(first:100){nodes{id isResolved path line comments(first:3){nodes{author{login} body}}}}}}}' \
  --jq '.data.repository.pullRequest.reviewThreads.nodes | map(select(.isResolved==false))'

# Reply with closure note (citing fix SHA OR dismissal rationale):
gh api graphql -f query='mutation($t:ID!,$b:String!){addPullRequestReviewThreadReply(input:{pullRequestReviewThreadId:$t,body:$b}){comment{id}}}' \
  -F t='PRRT_xxx' -F b='✅ Fixed in <sha>: <one-line>'

# Resolve thread:
gh api graphql -f query='mutation($t:ID!){resolveReviewThread(input:{threadId:$t}){thread{isResolved}}}' \
  -F t='PRRT_xxx'
```
