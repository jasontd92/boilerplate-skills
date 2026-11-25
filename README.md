# boilerplate-skills

Clone this repo to stand up a coding-agent environment (Claude Code, Cursor, and similar). Skills are stack-agnostic workflows. Machine setup is optional host chrome for the laptop that runs the agent.

## Quick setup

```bash
git clone https://github.com/jasontd92/boilerplate-skills.git
cd boilerplate-skills
./install.sh
```

`install.sh` symlinks every skill in `skills/` into `~/.claude/skills/` and `~/.cursor/skills/`. Existing links with the same name are replaced; nothing else is touched.

Then, from any project:

```bash
claude    # Claude Code picks up ~/.claude/skills
```

To install only Claude or only Cursor: `./install.sh --claude` or `./install.sh --cursor`.

## Skills

| Skill | When to use |
|---|---|
| [`analyze`](skills/analyze/SKILL.md) | Understand the codebase and write a plan. Do not implement. |
| [`task-to-pr`](skills/task-to-pr/SKILL.md) | One feature, one PR: analyze → implement → lint → browser proof → PR → bot review. |
| [`todo-batch`](skills/todo-batch/SKILL.md) | Many small unrelated TODOs → one worktree, one branch, one PR. |
| [`sprint`](skills/sprint/SKILL.md) | Multi-PR program. CEO / PM / EM / Verifier / Designer. Independent PRs or a cutover branch. |
| [`blitz`](skills/blitz/SKILL.md) | A queue of mixed tickets (code, spikes, messages, release steps) with parallel workers and a live board. |
| [`browser-tests`](skills/browser-tests/SKILL.md) | Playwright proof-of-work: render-gated screenshots, evidence, upload to the PR. |
| [`pr-review-loop`](skills/pr-review-loop/SKILL.md) | Drive cubic/codex (or equivalent bots) to green. Humans never block. Merge is out of scope. |

Pick **one** entry skill: `/task-to-pr`, `/todo-batch`, `/sprint`, or `/blitz`. The others are phases those call.

## Machine (this laptop)

Optional. Not required for the skills to run. See [`machine/README.md`](machine/README.md).

- iTerm2 session dots: red = awaiting you, white = working, green = stopped
- Status line: yellow context %, white model, blue branch/worktree
