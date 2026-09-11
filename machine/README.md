# Machine setup

Host chrome for the laptop that runs the agent. Skip this if you only want the skills.

| Skill | What it does |
|---|---|
| [iterm2-claude-status](iterm2-claude-status/SKILL.md) | Install iTerm2 + Claude Code integration. Dots: **red** awaiting action, **white** working, **green** stopped. |
| [claude-statusline](claude-statusline/SKILL.md) | Status line: **yellow context %**, **white model**, **blue branch/worktree**. Script: `claude-statusline/statusline.sh`. |

Install order: iTerm2 → Claude Code integration → statusline script → confirm in a live `claude` session.
