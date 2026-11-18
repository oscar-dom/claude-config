#!/usr/bin/env bash
# Applies the repository settings, security features and rulesets on GitHub.
#
# Usage:  bash ~/.claude/skills/setup-git-flow/scripts/configure-github.sh [owner/repo]
#         (without an argument, uses the repository of the current directory)
#
# Exit:   0 if everything the plan allows was applied, 1 if something really failed.
#
# The endpoints are fixed in here. That is why granting permission to the skill's
# scripts is enough: a generic rule such as `gh api -X PATCH repos/<owner>/*` would
# allow any PATCH on any repository, including making it public.
#
# What the plan does not allow (403/422 on a private repo without a paid plan) is
# NOT a failure: it is reported as UNAVAILABLE and the script carries on.
#
# Safe to re-run: settings are rewritten with the same values and an existing
# ruleset is updated in place, never duplicated.

set -u
# Git Bash (Windows): never rewrite arguments such as rev:path into Windows paths.
export MSYS_NO_PATHCONV=1
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="${1:-$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null)}"
[ -n "$REPO" ] || { echo "Could not determine the repository"; exit 1; }

FAILURES=0
VIS=$(gh repo view "$REPO" --json visibility --jq .visibility 2>/dev/null)
# Without this, a wrong repository name would 404 on every call and look like success.
[ -n "$VIS" ] || { echo "FAILED: repository $REPO does not exist or is not accessible"; exit 1; }
echo "Configuring $REPO (visibility: $VIS)"
echo "==================="

# An error only counts as a plan limit if the repository is NOT public and GitHub
# says so with its plan message. A bare 403 or 422 is not enough: GitHub returns
# 422 for a ruleset with invalid JSON too, and 403 when the token lacks scopes.
# Calling those "unavailable" would leave the repository unprotected and the
# summary would blame the plan.
is_plan_limit() {
  [ "$VIS" != "PUBLIC" ] || return 1
  printf '%s' "$1" | grep -qiE 'Upgrade to GitHub Pro|make this repository public|not available for this repository|Advanced Security|Secret Protection'
}

# Runs one call and classifies it: OK, UNAVAILABLE (plan) or FAILED.
call() {
  label="$1"; shift
  out=$(gh api "$@" 2>&1); code=$?
  if [ $code -eq 0 ]; then
    printf '  OK           %s\n' "$label"
  elif is_plan_limit "$out"; then
    printf '  UNAVAILABLE  %s (not allowed by the plan or the visibility)\n' "$label"
  else
    printf '  FAILED       %s\n' "$label"
    printf '%s\n' "$out" | head -3 | sed 's/^/               /'
    FAILURES=$((FAILURES + 1))
  fi
}

# 1. Merge settings. They work on EVERY plan, private Free included, because they
#    belong to the repository and not to the rulesets. On a private Free repo they
#    are the only thing GitHub really enforces.
#    - Squash and merge commit only; rebase merging disabled.
#    - Both methods take the PR title as the commit title: the conventional title
#      the CI validates is what lands in history, not the branch's first commit
#      or "Merge pull request #N".
#    - Empty body (BLANK). The PR description follows the template (checkboxes,
#      comments, "Closes #") and would fill history with noise. The context stays
#      on the PR, linked by the (#N) GitHub appends to the squash title.
#    - Branches are deleted on merge. GitHub never deletes the default branch
#      (develop) or a protected branch.
call "merge settings (squash + merge commit, PR title without body, delete branches)" \
  -X PATCH "repos/$REPO" --silent \
  -F allow_squash_merge=true \
  -F allow_merge_commit=true \
  -F allow_rebase_merge=false \
  -F delete_branch_on_merge=true \
  -f squash_merge_commit_title=PR_TITLE \
  -f squash_merge_commit_message=BLANK \
  -f merge_commit_title=PR_TITLE \
  -f merge_commit_message=BLANK

# 2. develop as the default branch: PRs target it without --base, and nobody
#    opens a PR against main by mistake.
if gh api "repos/$REPO/branches/develop" --silent >/dev/null 2>&1; then
  call "default branch: develop" -X PATCH "repos/$REPO" --silent -f default_branch=develop
else
  printf '  FAILED       default branch: develop does not exist on the remote\n'
  FAILURES=$((FAILURES + 1))
fi

# 3. Security.
call "vulnerability alerts (Dependabot)"    -X PUT "repos/$REPO/vulnerability-alerts" --silent
call "automated security fixes (Dependabot)" -X PUT "repos/$REPO/automated-security-fixes" --silent
call "secret scanning and push protection"  -X PATCH "repos/$REPO" --silent \
  -f 'security_and_analysis[secret_scanning][status]=enabled' \
  -f 'security_and_analysis[secret_scanning_push_protection][status]=enabled'

# 4. Rulesets: created, or updated when one with the same name already exists.
#    Updating (instead of skipping) means re-running the script on a repository
#    set up by an older version of the skill applies the new rules.
EXISTING=$(gh api "repos/$REPO/rulesets" --jq '.[] | "\(.id)\t\(.name)"' 2>&1); rc=$?
if [ $rc -ne 0 ] && is_plan_limit "$EXISTING"; then
  echo "  UNAVAILABLE  protection rulesets (need a public repository or a paid plan)"
  echo "               goes to the summary as PENDING, with this reason"
elif [ $rc -ne 0 ]; then
  printf '  FAILED       could not list the rulesets\n'
  printf '%s\n' "$EXISTING" | head -3 | sed 's/^/               /'
  FAILURES=$((FAILURES + 1))
else
  for f in "$SKILL_DIR"/rulesets/*.json; do
    name=$(sed -n 's/.*"name": *"\([^"]*\)".*/\1/p' "$f" | head -1)
    id=$(printf '%s\n' "$EXISTING" | awk -F '\t' -v n="$name" '$2 == n { print $1; exit }')
    if [ -n "$id" ]; then
      call "ruleset \"$name\" (updated)" -X PUT "repos/$REPO/rulesets/$id" --input "$f" --silent
    else
      call "ruleset \"$name\"" -X POST "repos/$REPO/rulesets" --input "$f" --silent
    fi
  done
fi

echo "==================="
if [ "$FAILURES" -eq 0 ]; then
  echo "DONE: everything this plan allows was applied."
  echo "Do not trust this alone: audit-setup.sh reads it all back at the end."
  exit 0
fi
echo "WITH FAILURES: $FAILURES call(s) failed for a reason other than the plan."
exit 1
