#!/usr/bin/env bash
# Ships the user's work into develop in ONE call: branch, commit, push, pull
# request, wait for the CI, squash merge and local cleanup.
#
# Usage:  bash ~/.claude/skills/setup-git-flow/scripts/ship.sh [--commit-only|--pr-only] <branch> "<title>" <paths...>
#           <branch>   working branch, e.g. feat/email-validation. Created from
#                      develop if you are on develop; if you are already on a
#                      working branch, that branch is used and this is ignored.
#           <title>    Conventional Commit, e.g. "feat: validate email on login".
#                      Commit message and PR title (the PR title becomes the
#                      commit on develop).
#           <paths>    what to commit ("." for everything). Required on purpose:
#                      choose the files after reading `git status`.
#           --commit-only  stop after the commit (nothing leaves the machine)
#           --pr-only      stop after opening the pull request (no merge)
#
# Exit:   0 and a last line "SHIPPED ..." / "COMMITTED ..." / "PR OPENED ...",
#         1 and a last line "NOT SHIPPED: <reason>".
#
# Run it with a 10-minute tool timeout: it waits for the CI.
#
# Why a script: one permission and one tool call instead of ten commands, each
# with its own permission prompt, and no CI polling from the agent.

set -u

# Everything inside main(): `git checkout` and branch deletion change the tree,
# and bash must have read the whole script before that happens.
main() {
SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STOP=""
case "${1:-}" in --commit-only|--pr-only) STOP="$1"; shift;; esac
BRANCH="${1:-}"; TITLE="${2:-}"
[ $# -ge 2 ] && shift 2 || set --

fail() { echo "NOT SHIPPED: $*"; exit 1; }

[ -n "$BRANCH" ] && [ -n "$TITLE" ] || fail "usage: ship.sh [--commit-only|--pr-only] <branch> \"<title>\" <paths...>"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "not inside a git repository"

# Same rule as the CI, checked here so a bad title fails in a second and not
# after a push and a CI run.
CC='^(build|chore|ci|docs|feat|fix|perf|refactor|revert|style|test)(\([a-z0-9._/-]+\))?!?: ([^A-Z[:space:]]|[A-Z][A-Z0-9])(.*[^.[:space:]])?$'
printf '%s' "$TITLE" | grep -qE "$CC" && [ "${#TITLE}" -le 100 ] \
  || fail "title is not a valid Conventional Commit (lowercase start, no final period, max 100): $TITLE"

CURRENT=$(git symbolic-ref --quiet --short HEAD) || fail "detached HEAD: check out a branch first"
case "$CURRENT" in
  main) fail "you are on main: work goes through develop (a production fix is a hotfix, see docs/git-cheatsheet.md)";;
  develop)
    case "$BRANCH" in main|develop) fail "branch name '$BRANCH' is reserved";; esac
    # Check before branching, so "nothing to save" leaves no empty branch behind.
    [ $# -gt 0 ] && [ -n "$(git status --porcelain -- "$@")" ] \
      || fail "no changes to save in: ${*:-(no paths given)}"
    git show-ref --verify --quiet "refs/heads/$BRANCH" && fail "branch $BRANCH already exists locally: pick another name"
    git checkout -q -b "$BRANCH" || fail "could not create branch $BRANCH"
    echo "  branch   $BRANCH created from develop";;
  *)
    [ "$CURRENT" = "$BRANCH" ] || echo "  branch   already on $CURRENT: using it instead of $BRANCH"
    BRANCH="$CURRENT"
    echo "  branch   $BRANCH";;
esac

# 1. Commit, if the paths bring anything
if [ $# -gt 0 ]; then
  git add -- "$@" || fail "git add failed for: $*"
fi
if ! git diff --cached --quiet; then
  git commit -q -m "$TITLE" || fail "git commit failed (a hook may have rejected it)"
  echo "  commit   $(git log -1 --format='%h %s')"
else
  echo "  commit   nothing new to commit"
fi

if [ "$STOP" = "--commit-only" ]; then
  echo "COMMITTED on $BRANCH (not pushed)"
  exit 0
fi

# 2. Bring the branch up to date with develop
git fetch -q origin develop || fail "could not fetch origin/develop"
AHEAD=$(git rev-list --count origin/develop..HEAD)
[ "$AHEAD" -gt 0 ] || fail "branch $BRANCH has nothing that develop does not already have"
if ! git merge-base --is-ancestor origin/develop HEAD; then
  if git rebase -q origin/develop >/dev/null 2>&1; then
    echo "  update   rebased on the latest develop"
  else
    git rebase --abort >/dev/null 2>&1
    fail "conflicts with the latest develop: they must be resolved by hand (nothing was pushed)"
  fi
fi

# 3. Push (force-with-lease only matters after a rebase of an already pushed branch)
if ! OUT=$(git push -q --force-with-lease -u origin "$BRANCH" 2>&1); then
  printf '%s\n' "$OUT" | tail -5 | sed 's/^/           /'
  fail "push rejected (if push protection found a secret, remove it from the commit)"
fi
echo "  push     origin/$BRANCH"

# 4. Pull request: reuse the open one, or open it. The body lists the commits:
#    short, and the template's checkboxes do not apply to an agent.
PR=$(gh pr list --head "$BRANCH" --base develop --state open --json number --jq '.[0].number' 2>/dev/null)
if [ -z "$PR" ]; then
  BODY=$(printf 'Changes:\n\n%s\n' "$(git log --reverse --format='- %s' origin/develop..HEAD)")
  URL=$(gh pr create --base develop --head "$BRANCH" --title "$TITLE" --body "$BODY" 2>&1) \
    || fail "could not open the pull request: $URL"
  PR=$(printf '%s' "$URL" | grep -oE '[0-9]+$')
  echo "  pr       #$PR opened: $URL"
else
  gh pr edit "$PR" --title "$TITLE" >/dev/null 2>&1
  echo "  pr       #$PR already open, updated"
fi

if [ "$STOP" = "--pr-only" ]; then
  echo "PR OPENED: #$PR ($BRANCH -> develop), not merged"
  exit 0
fi

# 5. Wait for the CI and squash merge (merge-pr.sh never bypasses the rules)
if ! OUT=$(bash "$SCRIPTS/merge-pr.sh" "$PR" squash 2>&1); then
  printf '%s\n' "$OUT" | sed 's/^/           /'
  fail "PR #$PR was not merged (see above); the work is safe on $BRANCH"
fi
echo "  merge    PR #$PR squashed into develop"

# 6. Local cleanup: back on an up-to-date develop, working branch removed
git checkout -q develop || fail "merged, but could not switch back to develop"
git pull -q --ff-only --prune origin develop || echo "  ?        merged, but develop could not fast-forward: run git pull"
git branch -q -D "$BRANCH" 2>/dev/null
echo "SHIPPED: \"$TITLE\" is on develop (PR #$PR)"
exit 0
}

main "$@"
