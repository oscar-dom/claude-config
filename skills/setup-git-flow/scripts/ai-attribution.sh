#!/usr/bin/env bash
# Applies the user's answer to the "no AI attribution" question to the copied
# templates. Run it from the project root, after copying the templates.
#
# Usage:  bash ~/.claude/skills/setup-git-flow/scripts/ai-attribution.sh <keep|remove>
#           keep    the rule applies: drop only the marker lines
#           remove  the rule does not apply: drop the marked blocks entirely
#
# Exit:   0 if every marker is resolved, 1 otherwise.
#
# The templates wrap everything about the rule between two marker lines:
#   <!-- ai-attribution:start --> ... <!-- ai-attribution:end -->   (Markdown)
#   # ai-attribution:start ... # ai-attribution:end                 (YAML)
# A script, and not hand edits, so the result is the same on every run and no
# half-removed sentence or orphan CI step is left behind.

set -u

MODE="${1:-}"
case "$MODE" in keep|remove) ;; *)
  echo "Usage: ai-attribution.sh <keep|remove>"; exit 1;;
esac

FILES="CONTRIBUTING.md docs/git-cheatsheet.md .github/workflows/ci.yml CLAUDE.md AGENTS.md"
FAILED=0
for f in $FILES; do
  [ -f "$f" ] || continue
  grep -qE 'ai-attribution:(start|end)' "$f" || continue
  tmp=$(mktemp)
  if [ "$MODE" = "keep" ]; then
    awk '!/ai-attribution:(start|end)/' "$f" > "$tmp"
  else
    awk '
      /ai-attribution:start/ { skip = 1; next }
      /ai-attribution:end/   { skip = 0; next }
      !skip
    ' "$f" > "$tmp"
  fi
  # Keep the file's own line endings and permissions: write in place.
  cat "$tmp" > "$f"; rm -f "$tmp"
  if grep -qE 'ai-attribution:(start|end)' "$f"; then
    echo "  FAILED  $f still has markers"
    FAILED=1
  else
    echo "  OK      $f ($MODE)"
  fi
done

[ "$FAILED" -eq 0 ] || exit 1
echo "DONE: no AI attribution rule $( [ "$MODE" = keep ] && echo kept || echo removed )."
exit 0
