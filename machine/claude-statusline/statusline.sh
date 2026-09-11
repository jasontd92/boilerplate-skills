#!/usr/bin/env bash
# Claude Code / Cursor CLI status line.
# Palette (black terminal): context=yellow (highest), model=white, path=blue (lowest).
set -euo pipefail

input=$(cat)

MODEL=$(printf '%s' "$input" | jq -r '.model.display_name // "model"')
PARAM=$(printf '%s' "$input" | jq -r '.model.param_summary // empty')
PCT=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
CWD=$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // empty')
WT_NAME=$(printf '%s' "$input" | jq -r '.worktree.name // empty')
WT_PATH=$(printf '%s' "$input" | jq -r '.worktree.path // empty')

# Prefer git branch; fall back to worktree name or directory basename.
DIR="$CWD"
if [[ -n "$WT_PATH" && -d "$WT_PATH" ]]; then
  DIR="$WT_PATH"
fi

BRANCH=""
if [[ -n "$DIR" ]] && git -C "$DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  BRANCH=$(git -C "$DIR" branch --show-current 2>/dev/null || true)
fi

if [[ -n "$BRANCH" ]]; then
  PLACE="$BRANCH"
elif [[ -n "$WT_NAME" ]]; then
  PLACE="$WT_NAME"
else
  PLACE="${DIR##*/}"
fi

# Shorten very long worktree/branch names so context stays visible.
if [[ ${#PLACE} -gt 36 ]]; then
  PLACE="…${PLACE: -35}"
fi

MODEL_LABEL="$MODEL"
if [[ -n "$PARAM" ]]; then
  MODEL_LABEL="$MODEL $PARAM"
fi

# ANSI: yellow context, white model, blue place. Reset after each field.
Y=$'\033[1;33m'
W=$'\033[0;37m'
B=$'\033[0;34m'
R=$'\033[0m'

printf '%sctx %s%%%s  %s%s%s  %s%s%s\n' \
  "$Y" "$PCT" "$R" \
  "$W" "$MODEL_LABEL" "$R" \
  "$B" "$PLACE" "$R"
