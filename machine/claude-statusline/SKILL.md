---
name: claude-statusline
description: Configure a Claude Code (and Cursor CLI) status line showing folder, model, and context % in that order — folder and model in fixed Nord colors, context % threshold-colored green/yellow/red by usage. Use when setting up statusline, context percentage, or the Claude footer bar.
---

# Claude status line

Machine-local. Install the script on this Mac, then point Claude Code (and optionally Cursor CLI) at it.

## What it shows

Left → right:

| Field | Color | Why |
|---|---|---|
| **Branch / worktree / dir** | Nord9 blue (`#81A1C1`) | Where you are, first |
| **Model** | Nord15 mauve (`#B48EAD`) | Distinct from folder and from the context colors below |
| **Context used %** | Threshold: green `#A3BE8C` (<50%), yellow `#EBCB8B` (50–79%), red `#BF616A` (≥80%) | The color itself is the warning — no separate label, just the number |

All three use 24-bit truecolor escapes (`\033[38;2;R;G;Bm`), not the 16-color ANSI palette.

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

You should see blue `tmp`, mauve `Opus (Thinking)`, green `42%` (green because it's under 50%).

## Notes

- Custom status lines sit **above** Claude's built-in footer and hide most keyboard hints. That is expected.
- Context % can be `null` early in a session; the script treats that as `0`.
- Do not put this script's output in a product skill — it is host chrome, not agent workflow.
