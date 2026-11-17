#!/usr/bin/env bash
# Merges a pull request ONLY if its CI finished green.
#
# Usage:  bash ~/.claude/skills/setup-git-flow/scripts/merge-pr.sh <number> <squash|merge>
#           squash -> working branch into develop (deletes the branch)
#           merge  -> develop, hotfix/* or release/* into main, or a chore/sync-*
#                     branch into develop after a hotfix (merge commit); the
#                     branch is deleted, except develop
#
# Does not use --admin: it merges within the repository rules. If a ruleset
# requires approvals the PR does not have, it does NOT merge and says so,
# instead of bypassing them.
#
# Exit:   0 merged, 1 not merged (red CI, no checks, or an error).
#
# It exists as a script, and not as two loose commands, for two reasons: it forces
# reading the CI before merging, and it lets the user grant ONE permission to the
# skill's scripts instead of `gh pr merge` on any repository.
#
# It waits for the CI, which can take longer than a tool timeout: agents run it in
# the background. Running it again on the same PR is safe.

set -u

# Everything lives inside main(): bash reads the whole function before running
# it. Without this, `gh pr merge --delete-branch` switches branches, the script
# file may change or vanish mid-run and bash would read garbage.
main() {
PR="${1:-}"
MODE="${2:-}"
MAX_WAIT=300   # seconds to wait for the checks to appear

case "$MODE" in squash|merge) ;; *)
  echo "Usage: merge-pr.sh <number> <squash|merge>"; exit 1;;
esac
[ -n "$PR" ] || { echo "Missing the PR number"; exit 1; }

# Re-run of a run that was cut off after the merge: nothing left to do.
if [ "$(gh pr view "$PR" --json state --jq .state 2>/dev/null)" = "MERGED" ]; then
  echo "MERGED: PR #$PR was already merged"
  exit 0
fi

# Right after opening the PR the checks do not exist yet, and "no checks" does
# NOT mean "finished". Count them, without depending on the output text.
echo "PR #$PR: waiting for the checks to register..."
t=0
while :; do
  # gh exits with 8 while checks are pending: ignore its exit code and keep only
  # the number it prints (with `|| echo 0` an extra "0" would sneak in).
  n=$(gh pr checks "$PR" --json name --jq 'length' 2>/dev/null | head -1 | tr -dc '0-9')
  n=${n:-0}
  [ "$n" -gt 0 ] && break
  if [ "$t" -ge "$MAX_WAIT" ]; then
    echo "NOT MERGED: after ${MAX_WAIT}s the PR still has no checks."
    echo "Check that .github/workflows/ci.yml exists on the branch."
    exit 1
  fi
  sleep 5; t=$((t + 5))
done

echo "PR #$PR: $n check(s). Waiting for them to finish..."
if ! gh pr checks "$PR" --watch --interval 10 >/dev/null 2>&1; then
  echo "NOT MERGED: a check failed."
  gh pr checks "$PR" 2>/dev/null | sed 's/^/  /'
  echo "Read the log before changing anything: gh run view --log-failed"
  exit 1
fi

echo "Checks of PR #$PR:"
gh pr checks "$PR" --json name,bucket --jq '.[] | "  \(.bucket)\t\(.name)"'

HEAD_REF=$(gh pr view "$PR" --json headRefName --jq .headRefName 2>/dev/null)
# The commit message comes from the repository settings (PR title, empty body),
# so no --subject or --body here.
if [ "$MODE" = "squash" ]; then
  ARGS=(--squash --delete-branch)
else
  ARGS=(--merge)
  # Every working branch is deleted (hotfix/*, release/*, chore/sync-*), never develop.
  [ "$HEAD_REF" = "develop" ] || ARGS+=(--delete-branch)
fi
if ! OUT=$(gh pr merge "$PR" "${ARGS[@]}" 2>&1); then
  echo "NOT MERGED: GitHub rejected the merge."
  printf '%s\n' "$OUT" | sed 's/^/  /'
  if printf '%s' "$OUT" | grep -qiE 'review|approv'; then
    echo "The PR needs the approvals the ruleset requires. Ask for the review;"
    echo "do not bypass it with --admin."
  fi
  exit 1
fi

STATE=$(gh pr view "$PR" --json state --jq .state 2>/dev/null)
if [ "$STATE" = "MERGED" ]; then
  echo "MERGED: PR #$PR ($MODE)"
  exit 0
fi
echo "NOT MERGED: PR #$PR is in state $STATE"
exit 1
}

main "$@"
