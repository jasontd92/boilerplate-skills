#!/usr/bin/env bash
# Claude Code / Cursor CLI status line.
# Order: folder - model - context%. Nord neutrals for folder/model;
# context is threshold-colored (green <50%, yellow 50-79%, red >=80%) so the
# color itself is the warning.
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

# Truecolor: folder = Nord9 blue, model = Nord15 mauve.
FOLDER_COLOR=$'\033[38;2;129;161;193m'
MODEL_COLOR=$'\033[38;2;180;142;173m'
R=$'\033[0m'

# Context: threshold-colored so the color itself is the warning.
if (( PCT >= 80 )); then
  CTX_COLOR=$'\033[38;2;191;97;106m'   # Nord11 red
elif (( PCT >= 50 )); then
  CTX_COLOR=$'\033[38;2;235;203;139m'  # Nord13 yellow
else
  CTX_COLOR=$'\033[38;2;163;190;140m'  # Nord14 green
fi

printf '%s%s%s  %s%s%s  %s%s%%%s\n' \
  "$FOLDER_COLOR" "$PLACE" "$R" \
  "$MODEL_COLOR" "$MODEL_LABEL" "$R" \
  "$CTX_COLOR" "$PCT" "$R"
