#!/usr/bin/env bash
# Installs claude-config skills into ~/.claude/skills/
# Re-run after `git pull` to sync changes.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SOURCE="$SCRIPT_DIR/skills"
SKILLS_TARGET="$HOME/.claude/skills"

if [ ! -d "$SKILLS_SOURCE" ]; then
  echo "Error: source skills folder not found at $SKILLS_SOURCE" >&2
  exit 1
fi

mkdir -p "$SKILLS_TARGET"

for skill_dir in "$SKILLS_SOURCE"/*/; do
  skill_name="$(basename "$skill_dir")"
  dest="$SKILLS_TARGET/$skill_name"

  rm -rf "$dest"
  cp -r "$skill_dir" "$dest"
  echo "Installed skill: $skill_name"
done

echo ""
echo "Done. Skills available at: $SKILLS_TARGET"
