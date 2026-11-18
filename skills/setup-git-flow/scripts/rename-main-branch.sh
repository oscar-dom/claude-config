#!/usr/bin/env bash
# Renames the main branch of an existing repository (master, trunk...) to main,
# on GitHub and locally. Run only with the user's permission: pre-flight check 4
# of the skill decides it.
#
# Usage:  bash ~/.claude/skills/setup-git-flow/scripts/rename-main-branch.sh <current-branch>
#
# Exit:   0 if main ends up as the main branch, 1 otherwise.
#
# On GitHub it uses the rename endpoint, not "create main and delete master": that
# way GitHub retargets open PRs, keeps the branch protection, keeps it as the
# default branch if it was, and redirects old URLs. Other people's clones keep
# working until they run `git branch -m` (GitHub tells them when they visit).

set -u
# Git Bash (Windows): never rewrite arguments such as rev:path into Windows paths.
export MSYS_NO_PATHCONV=1

OLD="${1:-}"
[ -n "$OLD" ] || { echo "Usage: rename-main-branch.sh <current-branch>"; exit 1; }
[ "$OLD" != "main" ] || { echo "The branch is already called main: nothing to do"; exit 0; }

# Without this check an existing main would be overwritten, or the rename would
# fail halfway (renamed on GitHub, not locally).
if git show-ref --verify --quiet refs/heads/main; then
  echo "NOT RENAMED: a local main branch already exists. Decide with the user which one stays."
  exit 1
fi

if git remote get-url origin >/dev/null 2>&1; then
  REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null)
  [ -n "$REPO" ] || { echo "NOT RENAMED: could not determine the origin repository"; exit 1; }

  if gh api "repos/$REPO/branches/main" --silent >/dev/null 2>&1; then
    echo "NOT RENAMED: $REPO already has a main branch on GitHub. Decide with the user which one stays."
    exit 1
  fi

  if gh api "repos/$REPO/branches/$OLD" --silent >/dev/null 2>&1; then
    if ! OUT=$(gh api -X POST "repos/$REPO/branches/$OLD/rename" -f new_name=main --silent 2>&1); then
      echo "NOT RENAMED: GitHub rejected renaming $OLD"
      printf '%s\n' "$OUT" | head -3 | sed 's/^/  /'
      exit 1
    fi
    echo "  OK    $REPO: $OLD renamed to main on GitHub"
  else
    echo "  ?     $OLD does not exist on GitHub: renaming locally only"
  fi
  git fetch --quiet --prune origin
fi

if git show-ref --verify --quiet "refs/heads/$OLD"; then
  git branch -m "$OLD" main || { echo "NOT RENAMED: git branch -m failed"; exit 1; }
  echo "  OK    $OLD renamed to main locally"
fi

if git show-ref --verify --quiet refs/remotes/origin/main; then
  git branch --set-upstream-to=origin/main main >/dev/null
  git remote set-head origin --auto >/dev/null 2>&1
  echo "  OK    main tracks origin/main"
fi

git show-ref --verify --quiet refs/heads/main || { echo "NOT RENAMED: there is no local main branch"; exit 1; }
echo "RENAMED: the main branch is main"
exit 0
