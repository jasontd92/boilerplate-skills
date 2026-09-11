# boilerplate-skills

Portable agent skills, generalized from project workflows. No product branding.

## Layout

```
skills/     # Copy into a repo's .claude/skills/ and/or .cursor/skills/
machine/    # This laptop only — iTerm2 dots, Claude/Cursor status line
```

To use a workflow skill in a project:

```bash
cp -R skills/ship skills/sprint skills/analyze skills/browser-tests skills/pr-review-loop \
  /path/to/repo/.claude/skills/
```

Cursor personal skills can live in `~/.cursor/skills/` the same way.

## Lifted (generalized)

| Skill | Role |
|---|---|
| [`ship`](skills/ship/SKILL.md) | One feature → analyze → implement → lint → browser POW → PR → bot review. Was `agentive-ship`. |
| [`sprint`](skills/sprint/SKILL.md) | Multi-PR CEO/PM/EM/Verifier/Designer orchestration. Was `agentive-sprint`. |
| [`analyze`](skills/analyze/SKILL.md) | Pre-implementation analysis + browser-scenario blueprint. |
| [`browser-tests`](skills/browser-tests/SKILL.md) | Playwright proof-of-work, evidence, PR upload. |
| [`pr-review-loop`](skills/pr-review-loop/SKILL.md) | Cubic/codex loop until bots are green. Humans never block. |

Branding, product paths, Auth0/AUDI/OrbStack defaults, and Elixir/Phoenix folder maps were stripped. Stack-specific commands are "discover the project's helpers."

## Other skills in the source tree (not lifted)

Source: `auditai` `.claude/skills/`. Git history was not in the zip, so authorship is inferred from content (personal machine paths, workflow voice, vs product-domain runbooks).

### Likely the same author — still product- or stack-coupled

Worth a second pass if you want them in this repo after a generalization pass like `ship`/`sprint`.

| Skill | Why it didn't come over yet |
|---|---|
| `implement` | Same lifecycle as ship Phase 2, hard-coded Elixir/Next/`just claude-*`/auditai worktrees. |
| `pr-ready` | Cubic + full-lint + browser loop; OrbStack/Auth0/AUDI. |
| `pr-commit` | Already mostly generic. Smallest follow-up lift. |
| `todo-batch` | Strong pattern; worktree boot is auditai/`just up-no-turbo`. Sprint already points at `/todo-batch`. |
| `worktree` | Devcontainer + OrbStack + shared Postgres + makedeb. Pattern is reusable; the file is not. |
| `worktree-staging` | Staging AWS dump into an isolated worktree DB. Company account/MFA baked in. |

### Product / domain (leave in the app repo)

| Skill | Domain |
|---|---|
| `coaudit-evals`, `fsr-evals`, `fsr-self-improvement-loop` | CoAudit / FSR evals |
| `qa-cartographer`, `qa-curator`, `qa-explorer`, `qa-fix`, `qa-fixture-maintainer`, `qa-review`, `qa-scout` | App QA map + staging oracle |
| `product-announcement`, `product-mapper` | In-app announcements / surface map |
| `watchdog` | Sentry org/project hard-coded |

## Machine section

See [`machine/README.md`](machine/README.md). Separate from agent workflows on purpose: installing iTerm2 or a statusline script is not something a coding agent in a random repo should do.
