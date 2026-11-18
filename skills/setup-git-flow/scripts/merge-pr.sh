#!/usr/bin/env bash
# Merges a pull request ONLY if its required checks passed and no check failed.
#
# Usage:  bash ~/.claude/skills/setup-git-flow/scripts/merge-pr.sh <number> <squash|merge>
#           squash -> working branch into develop (deletes the branch)
#           merge  -> develop or hotfix/* into main, or a chore/sync-*
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
SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPTS/lib.sh"   # REQUIRED_CHECK
PR="${1:-}"
MODE="${2:-}"
MAX_WAIT="${MERGE_PR_MAX_WAIT:-300}"   # seconds a required check may take to appear
POLL="${MERGE_PR_POLL:-10}"
CI_TIMEOUT="${MERGE_PR_CI_TIMEOUT:-3600}"   # seconds a required check may run

case "$MODE" in squash|merge) ;; *)
  echo "Usage: merge-pr.sh <number> <squash|merge>"; exit 1;;
esac
[ -n "$PR" ] || { echo "Missing the PR number"; exit 1; }

# Re-run of a run that was cut off after the merge: nothing left to do.
if [ "$(gh pr view "$PR" --json state --jq .state 2>/dev/null)" = "MERGED" ]; then
  echo "MERGED: PR #$PR was already merged"
  exit 0
fi

# Which checks must pass: the required contexts of the base branch's rulesets
# when GitHub has them (so jobs the project marks as required later count too),
# otherwise the skill's own required check (private repositories on Free have no
# rulesets).
BASE=$(gh pr view "$PR" --json baseRefName --jq .baseRefName 2>/dev/null)
REQUIRED=$(gh api "repos/{owner}/{repo}/rules/branches/$BASE" \
  --jq '[.[] | select(.type == "required_status_checks") | .parameters.required_status_checks[].context] | unique | .[]' 2>/dev/null)
[ -n "$REQUIRED" ] || REQUIRED="$REQUIRED_CHECK"

# Wait for each REQUIRED check by name, and only for those:
# - "some check exists" is not enough: other checks can register and finish
#   before the CI starts, which once merged a PR without its CI;
# - "every check finished" is not either: GitHub's own validation of
#   .github/dependabot.yml can stay pending forever and never let a PR merge.
bucket_of() {
  gh pr checks "$PR" --json name,bucket --jq ".[] | select(.name == \"$1\") | .bucket" 2>/dev/null | head -1
}
OLDIFS=$IFS; IFS='
'
for c in $REQUIRED; do
  IFS=$OLDIFS
  echo "PR #$PR: waiting for '$c'..."
  t=0
  while :; do
    b=$(bucket_of "$c")
    case "$b" in
      pass|skipping) break ;;
      fail|cancel)
        echo "NOT MERGED: '$c' finished as '$b'."
        gh pr checks "$PR" 2>/dev/null | sed 's/^/  /'
        echo "Read the log before changing anything: gh run view --log-failed"
        exit 1 ;;
      "")
        if [ "$t" -ge "$MAX_WAIT" ]; then
          echo "NOT MERGED: after ${MAX_WAIT}s the '$c' check has not appeared."
          echo "Check that the workflow exists on the branch and its job is named '$c'."
          exit 1
        fi ;;
      *)
        if [ "$t" -ge "$CI_TIMEOUT" ]; then
          echo "NOT MERGED: '$c' is still '$b' after ${CI_TIMEOUT}s. Run this again to keep waiting."
          exit 1
        fi ;;
    esac
    sleep "$POLL"; t=$((t + POLL))
  done
  IFS='
'
done
IFS=$OLDIFS

# Checks that are not required are not waited for, but one that already failed
# still stops the merge: a red check is never ignored.
ALL=$(gh pr checks "$PR" --json name,bucket --jq '.[] | "  \(.bucket)\t\(.name)"' 2>/dev/null)
FAILED=$(printf '%s\n' "$ALL" | awk -F '\t' '$1 ~ /^  (fail|cancel)$/')
if [ -n "$FAILED" ]; then
  echo "NOT MERGED: a check failed:"
  printf '%s\n' "$FAILED"
  echo "Read the log before changing anything: gh run view --log-failed"
  exit 1
fi
PENDING=$(printf '%s\n' "$ALL" | awk -F '\t' '$1 ~ /^  pending$/ { print $2 }')
[ -z "$PENDING" ] || echo "  note: not required and still running, not waited for: $(echo $PENDING)"

echo "Checks of PR #$PR:"
gh pr checks "$PR" --json name,bucket --jq '.[] | "  \(.bucket)\t\(.name)"'

HEAD_REF=$(gh pr view "$PR" --json headRefName --jq .headRefName 2>/dev/null)
# The commit message comes from the repository settings (PR title, empty body),
# so no --subject or --body here.
if [ "$MODE" = "squash" ]; then
  ARGS=(--squash --delete-branch)
else
  ARGS=(--merge)
  # Every working branch is deleted (hotfix/*, chore/sync-*), never develop.
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
