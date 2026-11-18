#!/usr/bin/env bash
# Fake `gh` for the setup-git-flow script tests (tests/test-setup-git-flow.sh),
# installed as `gh` at the front of PATH.
#
# It plays GitHub's part against a local bare repository: pull requests are
# small files in $FAKE_GH_STATE, and `gh pr merge` really merges (squash or merge
# commit) in a scratch clone of $FAKE_GH_REMOTE and pushes the result. Only the
# calls the scripts make are implemented; anything else exits 2 so a test fails
# loudly instead of passing by accident.
#
# Test switches, as files in $FAKE_GH_STATE:
#   ci-red-all   every PR's checks fail        ci-red-<n>  PR <n>'s checks fail
#   dependabot   lines printed by `gh pr list --author app/dependabot`
#   late-required  holds a number K: the required check "Commit messages" only
#                  registers after K queries (another check is there from the
#                  start and already finished, as GitHub's Dependabot check is)
#   no-required    the required check never registers
#   required-red   the required check fails while every check "finishes"
#
# Portable on purpose (Linux, macOS, Git Bash on Windows): no `sed -i`, no GNU-only
# options.

set -u
ST="${FAKE_GH_STATE:?FAKE_GH_STATE not set}"
REMOTE="${FAKE_GH_REMOTE:?FAKE_GH_REMOTE not set}"
echo "gh $*" >> "$ST/calls"

opt() { local k="$1"; shift; while [ $# -gt 0 ]; do [ "$1" = "$k" ] && { printf '%s' "${2:-}"; return; }; shift; done; }
has() { local k="$1"; shift; local a; for a in "$@"; do [ "$a" = "$k" ] && return 0; done; return 1; }
# set_field <file> <key> <value>: rewrite the file instead of `sed -i`
set_field() { grep -v "^$2=" "$1" > "$1.tmp"; printf '%s=%q\n' "$2" "$3" >> "$1.tmp"; mv "$1.tmp" "$1"; }
pr_count() { local c=0 f; for f in "$ST"/pr.*; do [ -f "$f" ] && c=$((c + 1)); done; echo "$c"; }

case "${1:-} ${2:-}" in
"pr list")
  shift 2
  if has --author "$@"; then [ -f "$ST/dependabot" ] && cat "$ST/dependabot"; exit 0; fi
  head=$(opt --head "$@"); base=$(opt --base "$@"); want=$(opt --state "$@")
  want=$(printf '%s' "${want:-open}" | tr '[:lower:]' '[:upper:]')
  for f in "$ST"/pr.*; do
    [ -f "$f" ] || continue
    n=; h=; b=; state=; . "$f"
    [ "$state" = "$want" ] && [ "$h" = "$head" ] && [ "$b" = "$base" ] && { echo "$n"; exit 0; }
  done
  exit 0;;
"pr create")
  shift 2
  head=$(opt --head "$@"); base=$(opt --base "$@"); title=$(opt --title "$@")
  [ -n "$head" ] || head=$(git symbolic-ref --short HEAD)
  git ls-remote --exit-code --heads "$REMOTE" "$head" >/dev/null 2>&1 \
    || { echo "pull request create failed: head branch $head not found" >&2; exit 1; }
  n=$(( $(pr_count) + 1 ))
  { printf 'n=%s\n' "$n"; printf 'h=%q\n' "$head"; printf 'b=%q\n' "$base"
    printf 't=%q\n' "$title"; printf 'state=OPEN\n'; } > "$ST/pr.$n"
  echo "https://github.com/test/repo/pull/$n";;
"pr edit") exit 0;;
"pr checks")
  shift 2; n="$1"
  red=0; { [ -f "$ST/ci-red-all" ] || [ -f "$ST/ci-red-$n" ]; } && red=1
  bucket=pass; [ "$red" -eq 1 ] && bucket=fail
  rbucket=$bucket; [ -f "$ST/required-red" ] && rbucket=fail
  registered=1
  if [ -f "$ST/no-required" ]; then registered=0
  elif [ -f "$ST/late-required" ] && [ "$(cat "$ST/late-required")" -gt 0 ]; then
    registered=0
  fi
  if has --watch "$@"; then exit "$red"; fi
  if has --json "$@"; then
    case "$*" in
      *select*bucket*) [ "$registered" -eq 1 ] && echo "$rbucket";;
      *select*)
        # Only asking for the required check by name makes it register later:
        # a script that never asks for it never sees the counter reach 0.
        if [ -f "$ST/late-required" ]; then
          k=$(cat "$ST/late-required"); [ "$k" -gt 0 ] && echo $((k - 1)) > "$ST/late-required"
        fi
        echo "$registered";;
      *bucket*) printf '  pass\t.github/dependabot.yml\n'
                [ "$registered" -eq 1 ] && printf '  %s\tCommit messages\n' "$rbucket";;
      *) echo $((registered + 1));;
    esac
    exit 0
  fi
  printf 'Commit messages\t%s\n' "$bucket";;
"pr view")
  shift 2; n="$1"; [ -f "$ST/pr.$n" ] || { echo "no pull request $n" >&2; exit 1; }
  h=; state=; msha=; . "$ST/pr.$n"
  case "$*" in
    *headRefName*) echo "$h";;
    *mergeCommit*) echo "$msha";;
    *state*) echo "$state";;
  esac;;
"pr merge")
  shift 2; n="$1"; f="$ST/pr.$n"
  h=; b=; t=; state=; . "$f"
  [ "$state" = OPEN ] || { echo "pull request $n is not open" >&2; exit 1; }
  W=$(mktemp -d "$ST/merge.XXXXXX")
  git clone -q "$REMOTE" "$W/r" 2>/dev/null && cd "$W/r" && git checkout -q "$b" || exit 1
  if has --squash "$@"; then
    git merge -q --squash "origin/$h" >/dev/null 2>&1 || { echo "Pull request is not mergeable" >&2; exit 1; }
    git commit -q -m "$t (#$n)" || exit 1
  else
    git merge -q --no-ff -m "$t" "origin/$h" >/dev/null 2>&1 || { echo "Pull request is not mergeable" >&2; exit 1; }
  fi
  git push -q origin "$b" 2>/dev/null || exit 1
  has --delete-branch "$@" && git push -q origin --delete "$h" 2>/dev/null
  set_field "$f" state MERGED
  set_field "$f" msha "$(git rev-parse HEAD)";;
"release create") shift 2; echo "$1" >> "$ST/releases";;
*) echo "fake gh: unhandled call: $*" >&2; exit 2;;
esac
