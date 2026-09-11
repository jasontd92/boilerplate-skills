---
name: iterm2-claude-status
description: Install iTerm2 and the Claude Code integration so each session shows a colored status dot — red awaiting action, white working, green stopped/complete. Use when setting up a Mac terminal for Claude Code, session dots, or the Session Status toolbelt.
---

# iTerm2 + Claude Code session dots

This is **machine-local**. It does not belong in a product repo. Install once on the Mac that runs Claude Code.

## Install iTerm2

```bash
brew install --cask iterm2
```

Open iTerm2 at least once so it creates `~/Library/Application Support/iTerm2`. Use iTerm2 (not Terminal.app) as the host for `claude` sessions.

## Install the Claude Code integration

Requirements: `claude` on PATH, iTerm2's Python API enabled.

1. iTerm2 → **Install Claude Code Integration**
2. Enable the **Python API** (macOS will prompt)
3. Install the **cc-status hook** into `~/.claude/settings.json` (points at a stable path inside iTerm2's config dir)
4. Show the toolbelt and enable **Session Status** (`View > Toolbelt > Session Status`, or `⌘⇧B` for the toolbelt)
5. Optional: install the Claude Code Workgroup + auto-enter triggers on the profiles you run `claude` in

Repair later with **iTerm2 → Reinstall Claude Code Integration** (Claude can rewrite `settings.json` and drop the hook). Uninstall with **iTerm2 → Uninstall Claude Code Integration**.

Docs: [iTerm2 Claude Code integration](https://iterm2.com/claude-code-integration.html), [Session Status](https://iterm2.com/documentation-session-status.html).

## Desired dot colors

| Claude state | Meaning | Dot |
|---|---|---|
| **waiting** | Needs you — permission prompt, question, approval | **Red** |
| **working** | Running a prompt or tool (including background agents) | **White** |
| **idle** | Turn finished / stopped — waiting for the next message | **Green** |

Red = interrupt me. White = leave it alone, it's busy. Green = done, you can read or start the next turn.

The official integration already maps those three states. Confirm the **dot colors** match the table:

- Open several `claude` sessions, put one in each state, and look at Session Status.
- If the installer picked different colors, set them on the status command the hook runs (`it2` / Session Status `--dot-color`):

```text
waiting  --dot-color #ff3b30   --text-color #ff3b30
working  --dot-color #ffffff   --text-color #dddddd
idle     --dot-color #32d74b   --text-color #32d74b
```

Exact flag names follow current iTerm2 (`it2 set-status` / Set Tab Status). Prefer the integration's hook over a third-party tab-color plugin so Session Status, Workgroups, and dots stay in sync.

## Verify

1. Start `claude` in two tabs.
2. In tab A, send a prompt that needs permission → **red**.
3. In tab B, send a long prompt → **white** while tools run.
4. When tab B finishes → **green**.
5. Click the Session Status row to jump to that session. Waiting sessions should sort to the top.

## Notes

- With recent Claude Code, a session stays **working** while background agents/tasks it launched are still running, even if the main conversation is between turns. That is correct — do not treat that lull as idle.
- This skill is Mac + iTerm2 only. Cursor CLI statusline is a separate surface; see `machine/claude-statusline`.
