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
#                  registers after K queries for it
#   no-required    the required check never registers
#   required-red   the required check fails
#   required-pending  holds a number K: the required check is "pending" for K
#                  queries, then passes
#   other-pending  GitHub's own ".github/dependabot.yml" check stays pending
#                  forever (as it does for real); other-red: it fails
#   required-contexts  lines returned as the base branch's ruleset contexts
#                  (`gh api .../rules/branches/<b>`); missing = no rulesets
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
  red=0; { [ -f "$ST/ci-red-all" ] || [ -f "$ST/ci-red-$n" ] || [ -f "$ST/required-red" ]; } && red=1
  other=pass; [ -f "$ST/other-pending" ] && other=pending; [ -f "$ST/other-red" ] && other=fail
  # The required check's state: not registered yet (empty), pending, pass or fail.
  counter_down() { local k; k=$(cat "$1"); [ "$k" -gt 0 ] && { echo $((k - 1)) > "$1"; return 0; }; return 1; }
  required_state() {
    if [ -f "$ST/no-required" ]; then echo ""; return; fi
    if [ -f "$ST/late-required" ] && [ "$(cat "$ST/late-required")" -gt 0 ]; then echo ""; return; fi
    if [ -f "$ST/required-pending" ] && [ "$(cat "$ST/required-pending")" -gt 0 ]; then echo pending; return; fi
    if [ "$red" -eq 1 ]; then echo fail; else echo pass; fi
  }
  # `gh pr checks --watch` waits for EVERY check: with one stuck pending it never
  # returns. Make that visible instead of hanging the tests.
  if has --watch "$@"; then
    [ "$other" = pending ] && { echo "fake gh: --watch would wait forever on .github/dependabot.yml" >&2; exit 1; }
    exit "$red"
  fi
  if has --json "$@"; then
    jq=$(opt --jq "$@")
    case "$jq" in
      *'select(.name == "'*)
        name=$(printf '%s' "$jq" | sed 's/.*select(\.name == "\([^"]*\)").*/\1/')
        # Asking for the required check by name is what makes it register later
        # or finish: a script that never asks never sees the counters move.
        if [ "$name" = "Commit messages" ]; then
          state=$(required_state)
          [ -f "$ST/late-required" ] && counter_down "$ST/late-required"
          [ -n "$state" ] && [ -f "$ST/required-pending" ] && counter_down "$ST/required-pending"
        elif [ "$name" = ".github/dependabot.yml" ]; then state=$other
        else state=""; fi
        case "$jq" in
          *bucket*) [ -n "$state" ] && echo "$state";;
          *) [ -n "$state" ] && echo 1 || echo 0;;
        esac;;
      *bucket*)
        printf '  %s\t.github/dependabot.yml\n' "$other"
        state=$(required_state); [ -n "$state" ] && printf '  %s\tCommit messages\n' "$state";;
      *) echo 2;;
    esac
    exit 0
  fi
  printf 'Commit messages\t%s\n.github/dependabot.yml\t%s\n' "$(required_state)" "$other";;
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
"api "*)
  # Only the rulesets' required contexts of a branch; no file = no rulesets
  # (a private repository on Free answers with an error).
  case "${2:-}" in
    *"/rules/branches/"*)
      [ -f "$ST/required-contexts" ] || { echo "Upgrade to GitHub Pro" >&2; exit 1; }
      cat "$ST/required-contexts";;
    *) echo "fake gh: unhandled api call: $*" >&2; exit 2;;
  esac;;
*) echo "fake gh: unhandled call: $*" >&2; exit 2;;
esac
