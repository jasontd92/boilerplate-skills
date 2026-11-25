# Reviewer-ready

The goal is the lowest reviewer load for the same result. Run this after the review bots are green and before a human reviews. `pr-review-loop` Phase 3 runs it. `task-to-pr`, `sprint`, `blitz` and `todo-batch` reach it through `pr-review-loop`, or they link here.

## 1. Scope defaults

These are defaults. The requester can ask for more, for example an explicit cleanup.

- **One review mode per PR.** Mechanical changes need a different kind of reading from logic changes. Mechanical means renames, moves, routes no longer served, and generated output. Logic means fixes and features. When a task needs both, open two PRs. Say whether they are independent or must merge in order, and say which one regenerates shared generated files.
- **The smallest change is the default.** Prefer a change that can be undone to a deletion or a refactor: disable it, stop registering it, or put it behind a flag. Delete or refactor only when the requester asks for that cleanup. Ask before you delete code your team did not write.
- **The PR's purpose is the default scope.** Leave out changes the purpose does not need, even good ones. When you find a problem that existed before the PR, write a follow-up ticket. Do not fix it here, and list it in the PR only if this PR changes it.
- **Check every caller before you change an interface.** An interface is a route, a function signature, a schema, a config key, an event or a file format. Search for callers:
  - this repo, including tests, scripts and docs;
  - other repos and clients: web, mobile, bots, workers and jobs;
  - runtime traffic or logs, when you have them.

  Record what you checked under Verification.

## 2. Tightening pass

Run one pass per PR, in a worker with its own worktree.

1. Run a code-review tool on the diff against the base, for example `/code-review` at `high`.
2. Run a second reviewer with this prompt:
   > Review this branch's diff against the base to reduce reviewer load. Find code, comments, tests or concepts the PR does not need, simpler ways to do the same thing, and real bugs. Ignore style nits. Do not suggest added hardening. Report file:line and the suggested change.
3. **Triage.**
   - Accept a finding only if it removes or simplifies code without losing promised behaviour, or if it fixes a real bug.
   - Reject nits.
   - Reject added code for marginal stability: extra guards, validation, helpers or abstractions for unlikely cases. More code for marginal stability is the wrong trade.
4. **Look for review-loop residue.** Earlier review rounds add guards, helpers and long docstrings. The final design often does not need them.
5. **Keep a list of settled decisions.** Give it to every worker, so workers do not reopen them. When a bot raises a settled decision again, reply in its thread with the reason, and leave the code as it is. Resolve threads that are fixed and outdated, because open threads add noise.
6. **Output.** Make one batched commit, and do not push until the orchestrator checks it. Report:
   - the hand-written diff stat before and after (exclude generated files);
   - each accepted change, in one line;
   - each rejected finding, with a one-line reason.

## 3. History

- **Commits.** Make one commit per fix or logical step. Put generated output in its own commit. Mark generated paths so the host collapses them, for example `path/** linguist-generated=true` in `.gitattributes`.
- **Review fixes are fixups.** During review loops, commit each fix with `git commit --fixup=<sha of the commit it fixes>`. Before a human reviews, fold them in: `GIT_SEQUENCE_EDITOR=true git rebase -i --autosquash <base>`. Never leave a change followed by its revert.
- **Rewrite safely.**
  - Make a backup branch first.
  - Check that the final tree equals the tested tree: compare `git rev-parse HEAD^{tree}` before and after.
  - Push with `git push --force-with-lease=<branch>:<full sha from git ls-remote>`. Never type a hash from memory.
  - A force push restarts the bot reviews, so do it once, at the end.

## 4. Description

Write it for the reviewer, not the author.

- **Shape**, in this order:
  1. **What:** short bullets.
  2. **Why:** the reason the change is needed.
  3. **How:** only if the code does not make it clear.
  4. **Core review:** what to read, in order, and what to skip.
  5. **Verification:** a completed `- [x]` checklist, one result per line.
  6. **No regressions:** a separate section, when it is long.
  7. **Follow-ups.**
- **No review history.** Give the count, for example "Copilot reviewed it 4 times". Do not narrate the finds and fixes.
- **Fix PRs.** Use a table of Issue, Fix, and "Red on base, green here". The red column names the test file and the assertion that fails on the base.
- **Large diffs.** Explain the line count in the header with a percentage table:
  - generated deletions;
  - moved lines that the host shows as removed and added again;
  - generated additions;
  - hand-written lines.

  `git diff --diff-algorithm=histogram` separates moved lines from real changes.
- **No regressions** covers:
  - test counts on the base and on the branch;
  - each existing test that changed, and why;
  - control tests that pass on both.
- **Follow-ups.** List only the ones this PR causes or that the reviewer needs to know about.
- **Product choices inside a fix.** State the effect, whether it can be undone, why it is needed now, and the default. A reviewer can then accept it without a meeting.

## 5. Evidence: run it, do not recall it

- **Red/green.** Run the PR's tests against the base branch's source code: the PR's tests with the base's code. Record why each test fails. An assertion that shows the bug is strong evidence. An import error only shows that the new code is missing. Then record the green run on the branch.
- **Check claims where the reviewer sees them.** For example, is the generated file collapsed? Does the header count match the table?
- **Use precise wording.** Write "not served since <date> (#<PR>)", not "no longer exists".
- **Counts come from a run**, with the command that produced them.

## Final checklist

- [ ] One review mode per PR
- [ ] Tightening pass done, with line counts before and after
- [ ] One commit per fix, fixups folded in, tree equals the tested tree
- [ ] Description follows section 4, including Core review
- [ ] Red/green and no-regressions evidence comes from runs
- [ ] Every caller of a changed interface checked
- [ ] Settled findings answered in their threads; fixed and outdated threads resolved
