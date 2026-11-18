#!/usr/bin/env bash
# The commit convention lives in two places that cannot share a file:
#   skills/setup-git-flow/scripts/lib.sh                     (ship.sh, hotfix.sh)
#   skills/setup-git-flow/templates/.github/workflows/ci.yml (the user's CI)
# If they drift, a title the scripts accept is rejected by the CI (or the other
# way round) and the agent loops. The same goes for the name of the required
# check, which also lives in the rulesets. This check fails when they differ.

set -u
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

LIB=skills/setup-git-flow/scripts/lib.sh
CI=skills/setup-git-flow/templates/.github/workflows/ci.yml

lib_pattern=$(sed -n "s/^CC_PATTERN='\(.*\)'$/\1/p" "$LIB")
lib_max=$(sed -n 's/^CC_MAX_LENGTH=\([0-9]*\)$/\1/p' "$LIB")
ci_pattern=$(sed -n "s/^ *CC_PATTERN: '\(.*\)'$/\1/p" "$CI")
ci_max=$(sed -n 's/^ *CC_MAX_LENGTH: *\([0-9]*\)$/\1/p' "$CI")

fail=0
for v in lib_pattern lib_max ci_pattern ci_max; do
  [ -n "${!v}" ] || { echo "::error::could not read $v: did the file layout change?"; fail=1; }
done
if [ "$lib_pattern" != "$ci_pattern" ]; then
  echo "::error::CC_PATTERN differs between $LIB and $CI"
  echo "  lib: $lib_pattern"
  echo "  ci:  $ci_pattern"
  fail=1
fi
if [ "$lib_max" != "$ci_max" ]; then
  echo "::error::CC_MAX_LENGTH differs: $LIB=$lib_max, $CI=$ci_max"
  fail=1
fi
# The required check: lib.sh's REQUIRED_CHECK (merge-pr.sh waits for it by name)
# must be the CI job's name and the rulesets' required context, or every PR waits
# forever for a check that never reports.
lib_check=$(sed -n 's/^REQUIRED_CHECK="\(.*\)"$/\1/p' "$LIB")
ci_jobs=$(sed -n 's/^    name: *\(.*\)$/\1/p' "$CI")
[ -n "$lib_check" ] || { echo "::error::could not read REQUIRED_CHECK from $LIB"; fail=1; }
if ! printf '%s\n' "$ci_jobs" | grep -qxF -- "$lib_check"; then
  echo "::error::no job in $CI is named '$lib_check' (REQUIRED_CHECK in $LIB)"
  fail=1
fi
for rs in skills/setup-git-flow/rulesets/main.json skills/setup-git-flow/rulesets/develop.json; do
  if ! grep -qF "\"context\": \"$lib_check\"" "$rs"; then
    echo "::error::$rs does not require the context '$lib_check'"
    fail=1
  fi
done

[ "$fail" -eq 0 ] && echo "Commit convention in sync: scripts, CI template and rulesets agree."
exit "$fail"
