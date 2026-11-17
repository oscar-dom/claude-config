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
# Run `finish` with a 10-minute tool timeout (or in the background): it waits for
# the CI twice.

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
case "$BRANCH" in hotfix/*) ;; *) fail "not on a hotfix/* branch (run: hotfix.sh start <name>)";; esac

# On main every commit lands as it is, so the title is the commit and must pass the CI.
CC='^(build|chore|ci|docs|feat|fix|perf|refactor|revert|style|test)(\([a-z0-9._/-]+\))?!?: ([^A-Z[:space:]]|[A-Z][A-Z0-9])(.*[^.[:space:]])?$'
printf '%s' "$TITLE" | grep -qE "$CC" && [ "${#TITLE}" -le 100 ] \
  || fail "title is not a valid Conventional Commit (lowercase start, no final period, max 100): $TITLE"

git fetch -q --tags origin main develop || fail "could not fetch main and develop"
if [ -z "$VERSION" ]; then
  LAST=$(git describe --tags --abbrev=0 --match 'v[0-9]*.[0-9]*.[0-9]*' origin/main 2>/dev/null) \
    || fail "main has no version tag yet: pass --version vX.Y.Z"
  IFS=. read -r MA MI PA <<< "${LAST#v}"
  VERSION="v$MA.$MI.$((PA + 1))"
fi
printf '%s' "$VERSION" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+$' || fail "invalid version: $VERSION"
git rev-parse -q --verify "refs/tags/$VERSION" >/dev/null && fail "tag $VERSION already exists"
git ls-remote --exit-code --tags origin "refs/tags/$VERSION" >/dev/null 2>&1 && fail "tag $VERSION already exists on the remote"

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
PR=$(gh pr list --head "$BRANCH" --base main --state open --json number --jq '.[0].number' 2>/dev/null)
if [ -z "$PR" ]; then
  BODY=$(printf 'Hotfix %s.\n\n%s\n' "$VERSION" "$(git log --reverse --format='- %s' origin/main..HEAD)")
  URL=$(gh pr create --base main --head "$BRANCH" --title "$TITLE" --body "$BODY" 2>&1) \
    || fail "could not open the pull request into main: $URL"
  PR=$(printf '%s' "$URL" | grep -oE '[0-9]+$')
  echo "  pr       #$PR opened into main: $URL"
else
  echo "  pr       #$PR already open into main"
fi

# 3. CI, merge commit into main, tag and release
if ! OUT=$(bash "$SCRIPTS/merge-pr.sh" "$PR" merge 2>&1); then
  printf '%s\n' "$OUT" | sed 's/^/           /'
  fail "PR #$PR was not merged into main (see above); nothing was released"
fi
echo "  merge    PR #$PR merged into main"
git fetch -q origin main || fail "merged, but could not fetch main to tag it"
git tag -a "$VERSION" -m "$VERSION" origin/main || fail "merged into main, but could not create tag $VERSION"
git push -q origin "refs/tags/$VERSION" || fail "merged into main, but the tag push failed: git push origin $VERSION"
echo "  tag      $VERSION on $(git rev-parse --short origin/main)"
if gh release create "$VERSION" --verify-tag --title "$VERSION" --generate-notes >/dev/null 2>&1; then
  echo "  release  $VERSION published on GitHub"
else
  echo "  ?        tag pushed, but the GitHub release failed: gh release create $VERSION --verify-tag --generate-notes"
fi

# 4. Bring the fix back into develop. Through a branch cut from main, never with
#    main as the PR head: merged heads get deleted.
SYNC="chore/sync-$VERSION"
git checkout -q -B "$SYNC" origin/main || fail "released $VERSION, but could not create $SYNC: bring main into develop by hand"
if ! OUT=$(git push -q --force-with-lease -u origin "$SYNC" 2>&1); then
  fail "released $VERSION, but the push of $SYNC failed: bring main into develop by hand"
fi
URL=$(gh pr create --base develop --head "$SYNC" --title "chore: bring hotfix $VERSION into develop" \
      --body "Brings the $VERSION hotfix back into develop." 2>&1) \
  || fail "released $VERSION, but could not open the sync PR into develop: $URL"
SPR=$(printf '%s' "$URL" | grep -oE '[0-9]+$')
echo "  sync     PR #$SPR $SYNC -> develop"
if ! OUT=$(bash "$SCRIPTS/merge-pr.sh" "$SPR" merge 2>&1); then
  printf '%s\n' "$OUT" | sed 's/^/           /'
  fail "released $VERSION, but sync PR #$SPR was not merged (likely conflicts with develop): resolve it by hand"
fi
echo "  merge    PR #$SPR merged into develop"

# 5. Local cleanup
git checkout -q develop 2>/dev/null || git checkout -q -b develop origin/develop
git pull -q --ff-only --prune origin develop 2>/dev/null
git branch -q -D "$BRANCH" "$SYNC" 2>/dev/null
echo "HOTFIX RELEASED: $VERSION is on main and the fix is back on develop"
exit 0
}

main "$@"
