#!/usr/bin/env bash
# Releases develop into main in ONE call: release PR, wait for the CI, merge
# commit, version tag and GitHub release.
#
# Usage:  bash ~/.claude/skills/setup-git-flow/scripts/release.sh --suggest
#           read-only: current version, what develop has that main does not, the
#           suggested next version (feat -> minor, fix -> patch, ! -> major) and
#           the Dependabot pull requests waiting, so they can go in first
#         bash ~/.claude/skills/setup-git-flow/scripts/release.sh vX.Y.Z
#           the release itself, once the user has confirmed the version
#
# Exit:   0 and a last line "SUGGESTED ..." / "RELEASED ...",
#         1 and a last line "NOT RELEASED: <reason>".
#
# The release waits for the CI, which can take longer than a tool timeout: agents
# run it in the background. If it is cut off anyway, run it again with the same
# version: it reuses the open PR, or tags the release if it was already merged.

set -u

main() {
SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fail() { echo "NOT RELEASED: $*"; exit 1; }

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "not inside a git repository"
git fetch -q --tags origin main develop || fail "could not fetch main and develop"

LAST=$(git describe --tags --abbrev=0 --match 'v[0-9]*.[0-9]*.[0-9]*' origin/main 2>/dev/null)
CHANGES=$(git log --reverse --no-merges --format='%s' origin/main..origin/develop)

if [ "${1:-}" = "--suggest" ]; then
  # Dependabot updates the pinned GitHub Actions through PRs into develop. A
  # release is the natural moment to apply them, so they are listed here and
  # nowhere else (daily ships stay quiet).
  DEPS=$(gh pr list --author app/dependabot --state open --json number,title,baseRefName \
         --jq '.[] | "#\(.number) \(.title) (into \(.baseRefName))"' 2>/dev/null)
  if [ -n "$DEPS" ]; then
    echo "  updates  Dependabot pull requests waiting (apply them first, then suggest again):"
    printf '%s\n' "$DEPS" | sed 's/^/           /'
  fi
  echo "  current  ${LAST:-none (first release)}"
  if [ -z "$CHANGES" ]; then
    echo "NOTHING TO RELEASE: develop has nothing that main does not already have"
    exit 0
  fi
  echo "  changes  develop -> main:"
  printf '%s\n' "$CHANGES" | sed 's/^/           - /'
  if [ -z "$LAST" ]; then
    echo "SUGGESTED: v0.1.0 (or v1.0.0 if it is already usable in production: ask)"
    exit 0
  fi
  IFS=. read -r MA MI PA <<< "${LAST#v}"
  if printf '%s\n' "$CHANGES" | grep -qE '^[a-z]+(\([^)]*\))?!:' ||
     git log --format=%B origin/main..origin/develop | grep -q '^BREAKING CHANGE:'; then
    NEXT="v$((MA + 1)).0.0"; WHY="breaking change"
  elif printf '%s\n' "$CHANGES" | grep -qE '^feat(\([^)]*\))?:'; then
    NEXT="v$MA.$((MI + 1)).0"; WHY="new feature"
  else
    NEXT="v$MA.$MI.$((PA + 1))"; WHY="fixes and maintenance only"
  fi
  echo "SUGGESTED: $NEXT ($WHY)"
  exit 0
fi

VERSION="${1:-}"
printf '%s' "$VERSION" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+$' || fail "usage: release.sh --suggest | release.sh vX.Y.Z"
git ls-remote --exit-code --tags origin "refs/tags/$VERSION" >/dev/null 2>&1 && fail "tag $VERSION already exists"
if [ -n "$LAST" ] && [ "$(printf '%s\n%s\n' "${LAST#v}" "${VERSION#v}" | sort -V | tail -1)" != "${VERSION#v}" ]; then
  fail "$VERSION is not higher than the current version $LAST"
fi
git tag -d "$VERSION" >/dev/null 2>&1   # a local-only tag from a cut-off run: recreated below
TITLE="chore: release $VERSION"

# Resume: a previous run merged the release (main's last commit is this release's
# merge commit, titled after the PR) and was cut off before tagging.
if [ -z "$CHANGES" ] && [ "$(git log -1 --format=%s origin/main)" = "$TITLE" ]; then
  echo "  resume   the release PR was already merged into main"
else
  [ -n "$CHANGES" ] || fail "develop has nothing that main does not already have"
  [ -z "$(git status --porcelain)" ] || fail "uncommitted changes: ship or set them aside first"

  PR=$(gh pr list --head develop --base main --state open --json number --jq '.[0].number' 2>/dev/null)
  if [ -z "$PR" ]; then
    BODY=$(printf 'Release %s.\n\n%s\n' "$VERSION" "$(printf '%s\n' "$CHANGES" | sed 's/^/- /')")
    URL=$(gh pr create --base main --head develop --title "$TITLE" --body "$BODY" 2>&1) \
      || fail "could not open the release pull request: $URL"
    PR=$(printf '%s' "$URL" | grep -oE '[0-9]+$')
    echo "  pr       #$PR opened: $URL"
  else
    gh pr edit "$PR" --title "$TITLE" >/dev/null 2>&1
    echo "  pr       #$PR already open, retitled to \"$TITLE\""
  fi

  if ! OUT=$(bash "$SCRIPTS/merge-pr.sh" "$PR" merge 2>&1); then
    printf '%s\n' "$OUT" | sed 's/^/           /'
    fail "release PR #$PR was not merged (see above)"
  fi
  echo "  merge    PR #$PR merged into main (merge commit)"
fi

git fetch -q origin main || fail "merged, but could not fetch main to tag it"
git tag -a "$VERSION" -m "$VERSION" origin/main || fail "merged, but could not create tag $VERSION"
git push -q origin "refs/tags/$VERSION" || fail "merged and tagged locally, but the tag push failed: git push origin $VERSION"
echo "  tag      $VERSION on $(git rev-parse --short origin/main)"
if gh release create "$VERSION" --verify-tag --title "$VERSION" --generate-notes >/dev/null 2>&1; then
  echo "  release  $VERSION published on GitHub"
else
  echo "  ?        tag pushed, but the GitHub release failed: gh release create $VERSION --verify-tag --generate-notes"
fi

# Leave the user on an up-to-date develop
CUR=$(git symbolic-ref --quiet --short HEAD)
[ "$CUR" = "develop" ] || git checkout -q develop
git pull -q --ff-only origin develop 2>/dev/null
echo "RELEASED: $VERSION is on main"
exit 0
}

main "$@"
