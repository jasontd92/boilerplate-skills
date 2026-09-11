# machine/ — this Mac, not the product

Skills under `skills/` are portable agent workflows. Everything here is **host setup**: iTerm2, Claude Code chrome, status line. Copy these onto a laptop; do not drop them into an application repo's `.claude/skills/` unless you want every clone to install terminal dots.

| Skill | What it does |
|---|---|
| [iterm2-claude-status](iterm2-claude-status/SKILL.md) | Install iTerm2 + Claude Code integration. Session dots: **red** awaiting action, **white** working, **green** stopped/complete. |
| [claude-statusline](claude-statusline/SKILL.md) | Status line: **yellow context %**, **white model**, **blue branch/worktree**. Script in `claude-statusline/statusline.sh`. |

Install order: iTerm2 → Claude Code integration (dots) → statusline script → confirm both in a live `claude` session.
