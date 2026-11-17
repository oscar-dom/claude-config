#!/usr/bin/env bash
# Urgent fix of what is already released (main), in two calls.
#
# Usage:  bash ~/.claude/skills/setup-git-flow/scripts/hotfix.sh start <short-name>
#           creates hotfix/<short-name> from the latest main and switches to it.
#           Write the fix AFTER this, on that branch.
#         bash ~/.claude/skills/setup-git-flow/scripts/hotfix.sh finish "<title>" <paths...> [--version vX.Y.Z]
#           commit, PR into main, wait for the CI, merge commit, patch tag and
#           GitHub release, then bring the fix back into develop through a
#           chore/sync-<version> branch, and leave the user on develop.
#           The version defaults to the next patch of the latest tag on main.
#
# Exit:   0 and a last line "HOTFIX STARTED ..." / "HOTFIX RELEASED ...",
#         1 and a last line "HOTFIX NOT DONE: <reason>". When the fix is released
#         but the sync into develop fails, the last line says so: the release
#         stands and only the sync is left.
#
# `finish` waits for the CI twice, which can take longer than a tool timeout:
# agents run it in the background. If it is cut off anyway, run it again: it
# detects what is already done (merged, tagged, synced) and continues.

set -u

main() {
SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fail() { echo "HOTFIX NOT DONE: $*"; exit 1; }

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "not inside a git repository"
ACTION="${1:-}"; shift || true

if [ "$ACTION" = "start" ]; then
  NAME="${1:-}"
  printf '%s' "$NAME" | grep -qE '^[a-z0-9][a-z0-9.-]*$' || fail "usage: hotfix.sh start <short-kebab-name>"
  # Uncommitted work belongs to develop: carrying it onto a branch from main
  # would mix unreleased work into the fix.
  [ -z "$(git status --porcelain)" ] || fail "uncommitted changes: save them first (ship.sh --commit-only) so they do not leak into the hotfix"
  git show-ref --verify --quiet "refs/heads/hotfix/$NAME" && fail "branch hotfix/$NAME already exists"
  git fetch -q origin main || fail "could not fetch origin/main"
  git checkout -q -b "hotfix/$NAME" origin/main || fail "could not create hotfix/$NAME"
  git branch -q --unset-upstream 2>/dev/null
  echo "HOTFIX STARTED: on hotfix/$NAME, from main ($(git rev-parse --short HEAD)). Write the fix now."
  exit 0
fi

[ "$ACTION" = "finish" ] || fail "usage: hotfix.sh start <name> | hotfix.sh finish \"<title>\" <paths...> [--version vX.Y.Z]"

TITLE="${1:-}"; shift || true
VERSION=""; PATHS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --version) VERSION="${2:-}"; shift 2 || shift;;
    *) PATHS+=("$1"); shift;;
  esac
done

BRANCH=$(git symbolic-ref --quiet --short HEAD) || fail "detached HEAD"
case "$BRANCH" in
  hotfix/*) MODE=hotfix;;
  chore/sync-v*) MODE=sync; VERSION="${BRANCH#chore/sync-}";;   # resuming a cut-off sync
  *) fail "not on a hotfix/* branch (run: hotfix.sh start <name>)";;
esac
git fetch -q --tags origin main develop || fail "could not fetch main and develop"
. "$SCRIPTS/lib.sh"

# Every step below checks whether a previous, cut-off run already did it, so
# running `finish` again always continues where it stopped.

if [ "$MODE" = "hotfix" ]; then
  MAIN_PR=$(gh pr list --head "$BRANCH" --base main --state merged --json number --jq '.[0].number' 2>/dev/null)
  if [ -n "$MAIN_PR" ]; then
    echo "  resume   PR #$MAIN_PR was already merged into main"
  else
    # On main every commit lands as it is, so the title is the commit and must
    # pass the CI (same rule, from lib.sh).
    valid_title "$TITLE" \
      || fail "title is not a valid Conventional Commit (lowercase start, no final period, max 100): $TITLE"
    if [ -n "$VERSION" ]; then
      printf '%s' "$VERSION" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+$' || fail "invalid version: $VERSION"
      git ls-remote --exit-code --tags origin "refs/tags/$VERSION" >/dev/null 2>&1 && fail "tag $VERSION already exists"
    fi

    # 1. Commit the fix
    [ ${#PATHS[@]} -gt 0 ] && { git add -- "${PATHS[@]}" || fail "git add failed"; }
    if ! git diff --cached --quiet; then
      git commit -q -m "$TITLE" || fail "git commit failed (a hook may have rejected it)"
      echo "  commit   $(git log -1 --format='%h %s')"
    fi
    [ "$(git rev-list --count origin/main..HEAD)" -gt 0 ] || fail "the hotfix branch has no commits: write the fix first"
    [ -z "$(git status --porcelain)" ] || echo "  ?        uncommitted changes left out of the hotfix: $(git status --porcelain | wc -l) file(s)"

    # 2. Push and PR into main
    if ! OUT=$(git push -q --force-with-lease -u origin "$BRANCH" 2>&1); then
      printf '%s\n' "$OUT" | tail -5 | sed 's/^/           /'
      fail "push rejected"
    fi
    MAIN_PR=$(gh pr list --head "$BRANCH" --base main --state open --json number --jq '.[0].number' 2>/dev/null)
    if [ -z "$MAIN_PR" ]; then
      BODY=$(printf 'Hotfix.\n\n%s\n' "$(git log --reverse --format='- %s' origin/main..HEAD)")
      URL=$(gh pr create --base main --head "$BRANCH" --title "$TITLE" --body "$BODY" 2>&1) \
        || fail "could not open the pull request into main: $URL"
      MAIN_PR=$(printf '%s' "$URL" | grep -oE '[0-9]+$')
      echo "  pr       #$MAIN_PR opened into main: $URL"
    else
      echo "  pr       #$MAIN_PR already open into main"
    fi

    # 3. CI and merge commit into main
    if ! OUT=$(bash "$SCRIPTS/merge-pr.sh" "$MAIN_PR" merge 2>&1); then
      printf '%s\n' "$OUT" | sed 's/^/           /'
      fail "PR #$MAIN_PR was not merged into main (see above); nothing was released"
    fi
    echo "  merge    PR #$MAIN_PR merged into main"
    git fetch -q --tags origin main || fail "merged, but could not fetch main"
  fi
  MSHA=$(gh pr view "$MAIN_PR" --json mergeCommit --jq .mergeCommit.oid 2>/dev/null)
  [ -n "$MSHA" ] && git cat-file -e "$MSHA^{commit}" 2>/dev/null || fail "merged, but could not find the merge commit of PR #$MAIN_PR"

  # 4. Patch tag and GitHub release, unless a previous run already tagged it
  TAGGED=$(git tag --points-at "$MSHA" | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -1)
  if [ -n "$TAGGED" ]; then
    VERSION="$TAGGED"
    echo "  resume   already tagged $VERSION"
  else
    if [ -z "$VERSION" ]; then
      LAST=$(git describe --tags --abbrev=0 --match 'v[0-9]*.[0-9]*.[0-9]*' "$MSHA" 2>/dev/null) \
        || fail "merged into main, but main has no version tag yet: run again with --version vX.Y.Z"
      IFS=. read -r MA MI PA <<< "${LAST#v}"
      VERSION="v$MA.$MI.$((PA + 1))"
    fi
    git tag -a "$VERSION" -m "$VERSION" "$MSHA" || fail "merged into main, but could not create tag $VERSION"
    git push -q origin "refs/tags/$VERSION" || fail "merged into main, but the tag push failed: git push origin $VERSION"
    echo "  tag      $VERSION on $(git rev-parse --short "$MSHA")"
    if gh release create "$VERSION" --verify-tag --title "$VERSION" --generate-notes >/dev/null 2>&1; then
      echo "  release  $VERSION published on GitHub"
    else
      echo "  ?        tag pushed, but the GitHub release failed: gh release create $VERSION --verify-tag --generate-notes"
    fi
  fi
else
  MSHA=$(git rev-parse -q --verify "refs/tags/$VERSION^{commit}") || fail "on $BRANCH, but tag $VERSION does not exist"
  echo "  resume   syncing $VERSION into develop"
fi

# 5. Bring the fix back into develop. Through a branch cut from the released
#    commit, never with main as the PR head: merged heads get deleted.
SYNC="chore/sync-$VERSION"
if git merge-base --is-ancestor "$MSHA" origin/develop; then
  echo "  sync     $VERSION is already in develop"
else
  SPR=$(gh pr list --head "$SYNC" --base develop --state open --json number --jq '.[0].number' 2>/dev/null)
  if [ -z "$SPR" ]; then
    git checkout -q -B "$SYNC" "$MSHA" || fail "released $VERSION, but could not create $SYNC: bring main into develop by hand"
    git push -q --force-with-lease -u origin "$SYNC" >/dev/null 2>&1 \
      || fail "released $VERSION, but the push of $SYNC failed: run hotfix.sh finish again"
    URL=$(gh pr create --base develop --head "$SYNC" --title "chore: bring hotfix $VERSION into develop" \
          --body "Brings the $VERSION hotfix back into develop." 2>&1) \
      || fail "released $VERSION, but could not open the sync PR into develop: $URL"
    SPR=$(printf '%s' "$URL" | grep -oE '[0-9]+$')
    echo "  sync     PR #$SPR $SYNC -> develop"
  else
    echo "  sync     PR #$SPR already open"
  fi
  if ! OUT=$(bash "$SCRIPTS/merge-pr.sh" "$SPR" merge 2>&1); then
    printf '%s\n' "$OUT" | sed 's/^/           /'
    fail "released $VERSION, but sync PR #$SPR was not merged (likely conflicts with develop): resolve it by hand"
  fi
  echo "  merge    PR #$SPR merged into develop"
fi

# 6. Local cleanup
git checkout -q develop 2>/dev/null || git checkout -q -b develop origin/develop
git pull -q --ff-only --prune origin develop 2>/dev/null
git branch -q -D "$SYNC" 2>/dev/null
# Local hotfix branches already released (their commits are in main), including
# the one of a run that was resumed from the sync step.
for b in $(git branch --format='%(refname:short)' --merged origin/main --list 'hotfix/*'); do
  git branch -q -D "$b" 2>/dev/null
done
echo "HOTFIX RELEASED: $VERSION is on main and the fix is back on develop"
exit 0
}

main "$@"
