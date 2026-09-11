---
name: pr-review-loop
description: Monitor PR code review findings from cubic/codex, address relevant feedback, push fixes, and loop until review passes clean.
argument-hint: [PR number or URL (optional — auto-detects current branch PR)]
allowed-tools: Bash, Read, Edit, Write, Grep, Glob, Agent, WebFetch
---

# PR Review Loop

Autonomously monitor and address **automated** code review feedback (cubic and codex) on the current PR until the bot reviewers pass clean.

> **SCOPE — this loop drives the AUTOMATED reviewers (cubic + codex) to green, nothing more.** It is **DONE** the moment every bot reviewer present on the PR has either (a) approved / its check passed, or (b) re-reviewed your most recent push and left **no new findings**. At that point, conclude and report — do not keep looping.
>
> **Human approval is NEVER a completion condition and is NEVER awaited.** If a human has *already* left comments, consider and address them like any other finding (Phase 2b). But their *absence* never blocks completion, and you must not sleep/poll waiting for a human review. Merging is also out of scope — a separate land/deploy step, never this loop.

> **CRITICAL**: Maintain a holistic understanding of the PR's original intent throughout. Do NOT double down on bad solutions or over-engineer fixes that conflict with the original requirements. If a review comment suggests a direction that undermines the PR's purpose, skip it and note why. For loops that run long, this is enforced structurally — see **Phase 2f: Architecture sanity checkpoint**.

---

## Phase 0: Identify the PR

1. If `$ARGUMENTS` contains a PR number or URL, use that. Otherwise, detect the PR for the current branch:
   ```bash
   gh pr list --head "$(git branch --show-current)" --json number,url,title --jq '.[0]'
   ```
2. If no PR exists, abort with a message asking the user to create one first.
3. Store the PR number for use throughout.

## Phase 1: Ensure changes are pushed

1. Check `git status` for uncommitted changes.
2. If there are staged or unstaged changes, warn the user that unpushed local changes exist — they should commit and push first.
3. Verify the local branch is in sync with the remote:
   ```bash
   git fetch origin
   LOCAL_BRANCH=$(git branch --show-current)
   echo "=== Local commits not pushed ==="
   git log "origin/${LOCAL_BRANCH}..HEAD" --oneline
   echo "=== Remote commits not pulled ==="
   git log "HEAD..origin/${LOCAL_BRANCH}" --oneline
   ```
   If the remote is ahead of local, run `git pull --rebase` before proceeding.

## Phase 2: Review Loop

Repeat the following cycle until every bot reviewer (cubic and codex) is green — approved/passed, or re-reviewed your latest push with no new findings. **Bots define "done"; humans do not.**

### 2a. Wait for review

1. Check if a review has completed:
   ```bash
   gh api repos/{owner}/{repo}/pulls/{pr_number}/comments --jq 'length'
   gh api repos/{owner}/{repo}/pulls/{pr_number}/reviews --jq '[.[] | select(.state != "PENDING")] | length'
   ```
2. Also check for inline review comments from cubic and codex:
   ```bash
   gh api repos/{owner}/{repo}/pulls/{pr_number}/comments \
     --jq '[.[] | select(.user.login == "cubic-dev-ai[bot]" or .user.login == "codex[bot]" or .user.login == "openai-codex[bot]")] | sort_by(.created_at) | reverse | .[0:20]'
   ```
3. Check the bot reviewers' check status (this is the signal that defines "done"):
   ```bash
   gh pr checks {pr_number}   # look for the cubic / codex review checks → pass | fail | pending
   ```
   **Completion condition (definitive):** every bot reviewer present on the PR has
   either approved / its check passed, OR re-reviewed your most recent push with no
   new findings — and there are no unaddressed cubic/codex comments from step 2.
   When that holds, the loop is **COMPLETE** — skip to Phase 3. Do **not** condition
   completion on a human review, and do not exit early while bot comments are still
   unprocessed.
4. If the bot reviewers haven't run/completed yet (their checks are pending and they've
   left no comments), **sleep and check back** — you are waiting for the *bots*, never
   for a human:
   - First check: wait 5 minutes
   - Subsequent checks: wait 5 minutes
   - After 20 minutes with no bot-review activity (cubic/codex still haven't completed),
     inform the user and ask whether to keep waiting
   Never sleep solely to wait on a human review — a clean bot pass concludes the loop.
5. Track which comments you've already addressed (by comment ID) to avoid re-processing.

### 2b. Triage findings

For each new review comment:

1. **Read the comment** — understand what the reviewer is flagging.
2. **Read the relevant code** in context (the file and surrounding lines).
3. **Classify the finding**:
   - **Applicable**: The feedback is correct and improves the code. Address it.
   - **Fundamental issue**: The review exposes a real design flaw or correctness bug. A targeted refactor is warranted — do it, but scope it to the problem the reviewer identified.
   - **Already handled**: The concern is addressed elsewhere or by a different part of the change. Reply explaining why.
   - **Not applicable**: The suggestion conflicts with the PR's intent, is cosmetic-only in unchanged code, or is incorrect. Skip it and note why.
   - **Nitpick/style**: Minor style suggestions in code you changed. Address if trivial, skip if subjective.

### 2c. Apply fixes

For applicable findings:

1. Make the code change. If the review exposed a fundamental issue, a broader refactor is fine — but keep it scoped to the identified problem. Don't let a single finding snowball into rewriting unrelated code.
2. Verify the fix doesn't break the surrounding logic.
3. Stage the changed files.

### 2d. Commit and push

After addressing all new findings in a batch:

1. Create a single commit with a clear message summarizing what was addressed:
   ```
   fix: address code review feedback

   - [brief description of each fix]
   ```
2. Push to the remote branch.

### 2e. Check for completion

1. Re-fetch the bot reviewers' checks and inline comments to see whether your push triggered a re-review.
2. If a bot left **new** comments, go back to **2a** and process them.
3. If every bot reviewer is green (passed/approved or re-reviewed with no new findings) and no bot comments are unaddressed, the loop is **complete** — go to Phase 3. Do not loop again merely because no human has weighed in.

### 2f. Architecture sanity checkpoint (every 5 cycles small PRs / 10 cycles large or complex PRs)

Count completed fix cycles (a batch of findings addressed + pushed = one cycle). At **every 5th cycle** for a small PR, or **every 10th** for a large/complex one (many files, new subsystem, cross-cutting design), STOP fixing and spawn one independent subagent (general-purpose, foreground) for a second opinion before continuing. A long-running loop is itself a signal: either the reviewers keep finding material bugs (fine — continue), or each of your fixes is spawning the next round's findings, which means the loop has inverted and is now hardening a flawed design instead of finishing a sound one.

Give the subagent, concretely:
- The PR's purpose and its **stated hard invariants** (the promises the feature makes users).
- A round-by-round summary of the findings so far, grouped by kind, flagging which recent findings were **refinements of your own earlier fixes** — that pattern is the primary inversion signal.
- Paths to the load-bearing files (the subagent must read real code, not your summary).
- The question set: (1) Is the core design sound, or does it have a structurally unclosable failure surface guaranteeing an infinite finding tail? (2) Are the recent findings material risks or asymptotic micro-cases already bounded acceptably — and what does each *miss* degrade to (safe degradation vs. real data/correctness loss)? (3) Has accumulated fix complexity itself become a bigger risk than the residue — did any fix in the loop introduce its own bug? (4) Verdict: continue / stop with an accepted-by-design rationale / targeted redesign (with cost).

Act on the verdict:
- **Continue**: resume 2a; re-check at the next interval.
- **Stop / accepted-by-design**: revert any loop-introduced fixes the subagent flags, reply to the remaining open threads with the documented rationale (state the invariant hierarchy and what misses degrade to), post the close-out position as a PR comment so the record survives, and stop re-triggering re-reviews for findings in the accepted class. Adopt a triage rule for stragglers (e.g., "does the miss degrade safely, or is there a concrete loss trace?") — only the latter reopens work.
- **Redesign**: surface it to the user; a redesign is a scope change the loop must not undertake alone.

Watch for these inversion signals between checkpoints too — any of them justifies running the checkpoint early: a fix you made becomes the subject of the next round's finding; two findings demand contradictory behavior (you revert your own fix); findings shrink toward race windows or edge cases whose prevention costs more machinery than the harm they prevent; the reviewer's suggested remedy would silently weaken the feature's primary user promise.

## Phase 3: Report

Conclude the moment the bot reviewers are green — this is a terminal state, not a pause. Summarize what happened:
- Total review cycles completed
- Per bot reviewer (cubic, codex): final state — passed/approved, or not present on the PR
- Number of findings addressed vs skipped
- Any findings you intentionally skipped and why
- Current PR status, explicitly noting that a **human approval / merge is a separate, out-of-scope step this loop does not perform or wait for** (offer it as a hand-off, don't block on it)

---

## Guidelines

- **Targeted by default**: Changes should address what the reviewer flagged — no bloat, no brittleness.
- **Refactor when warranted**: If a finding exposes a real design problem, fix the root cause rather than papering over it. A scoped refactor is better than a fragile patch.
- **Preserve intent**: Evaluate whether suggestions actually serve the PR's original goal before adopting them. Don't abandon a sound approach just because a reviewer proposed an alternative.
- **Be surgical**: Small, targeted fixes. Each commit should be easy to review.
- **Don't fight the linter**: If cubic flags a real issue (type error, unused import, etc.), fix it.
- **Bots define done, not humans**: A clean pass from cubic + codex is the terminal state. Conclude there. Consider any human comments that already exist, but never poll, sleep, or block waiting for a human review or merge.
- **A long loop is a signal, not just work**: fixes that keep spawning the next round's findings mean the loop may be hardening a flawed design. The Phase 2f checkpoint exists to catch this — do not skip it because the individual findings each look reasonable; that is exactly how the inversion hides.
