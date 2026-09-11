#!/usr/bin/env bash
# Symlink skills/ into the local Claude Code and/or Cursor skill dirs.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SKILLS_SRC="${ROOT}/skills"

install_claude=0
install_cursor=0

usage() {
  cat <<'EOF'
Usage: ./install.sh [--claude] [--cursor] [--help]

With no flags, links skills into both ~/.claude/skills and ~/.cursor/skills.
EOF
}

if [[ $# -eq 0 ]]; then
  install_claude=1
  install_cursor=1
else
  for arg in "$@"; do
    case "$arg" in
      --claude) install_claude=1 ;;
      --cursor) install_cursor=1 ;;
      -h|--help) usage; exit 0 ;;
      *) echo "unknown arg: $arg" >&2; usage; exit 1 ;;
    esac
  done
fi

link_into() {
  local dest="$1"
  mkdir -p "$dest"
  local linked=0
  for skill_dir in "${SKILLS_SRC}"/*/; do
    [[ -d "$skill_dir" ]] || continue
    local name
    name="$(basename "$skill_dir")"
    ln -sfn "${skill_dir%/}" "${dest}/${name}"
    linked=$((linked + 1))
  done
  echo "linked ${linked} skills → ${dest}"
}

if [[ "$install_claude" -eq 1 ]]; then
  link_into "${HOME}/.claude/skills"
fi
if [[ "$install_cursor" -eq 1 ]]; then
  link_into "${HOME}/.cursor/skills"
fi
