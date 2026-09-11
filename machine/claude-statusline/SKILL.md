---
name: claude-statusline
description: Configure a Claude Code (and Cursor CLI) status line showing context % in yellow, model in white, and branch/worktree path in blue. Use when setting up statusline, context percentage, or the Claude footer bar.
---

# Claude status line

Machine-local. Install the script on this Mac, then point Claude Code (and optionally Cursor CLI) at it.

## What it shows

Left → right, by visibility on a black terminal:

| Field | Color | Why |
|---|---|---|
| **Context used %** | Bold yellow (`\033[1;33m`) | Highest — you act when this climbs |
| **Model** | White (`\033[0;37m`) | Comfortable, still readable |
| **Branch / worktree / dir** | Blue (`\033[0;34m`) | Lowest — enough to tell sessions apart, recedes on black |

Place resolution: `git branch --show-current` in the session cwd (or worktree path) → else worktree name → else directory basename.

Script: [`statusline.sh`](statusline.sh) in this folder.

## Install

```bash
mkdir -p ~/.claude
cp machine/claude-statusline/statusline.sh ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
```

Requires `jq`. (`brew install jq` if missing.)

### Claude Code — `~/.claude/settings.json`

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh",
    "padding": 2
  }
}
```

Or `/statusline` inside Claude and paste: "context percentage in bold yellow, model in white, git branch or worktree in blue, directory least prominent".

### Cursor CLI — `~/.cursor/cli-config.json`

Same script works; Cursor's payload is aligned with Claude's.

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh",
    "padding": 2
  }
}
```

## Verify

```bash
echo '{
  "model": {"display_name": "Opus", "param_summary": "(Thinking)"},
  "workspace": {"current_dir": "/tmp"},
  "context_window": {"used_percentage": 42.7}
}' | ~/.claude/statusline.sh
```

You should see yellow `ctx 42%`, white `Opus (Thinking)`, blue place name.

## Notes

- Custom status lines sit **above** Claude's built-in footer and hide most keyboard hints. That is expected.
- Context % can be `null` early in a session; the script treats that as `0`.
- Do not put this script's output in a product skill — it is host chrome, not agent workflow.
