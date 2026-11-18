# Shared by ship.sh, release.sh, hotfix.sh and merge-pr.sh. Sourced, not run.

# Git Bash (Windows) rewrites arguments that look like paths, such as
# origin/develop:.github/workflows/ci.yml, into Windows paths. Never for these scripts.
export MSYS_NO_PATHCONV=1

# The CI job every PR must pass before merging: the `name:` of the job in the CI
# template and the `context` of the rulesets. merge-pr.sh waits for it by name.
# The claude-config CI (scripts/check-convention-sync.sh) checks all three agree.
REQUIRED_CHECK="Commit messages"
#
# The commit convention, in ONE place for the scripts. The CI template
# (templates/.github/workflows/ci.yml) needs its own copy because it runs in the
# user's repository, where this file does not exist. The claude-config CI
# (scripts/check-convention-sync.sh) fails if the two copies drift apart.
#
# Conventional Commits: <type>[(scope)][!]: <description>. The description does
# not start like a sentence ("Add ..."), may start with an acronym ("README",
# "API"), and has no trailing period.
CC_PATTERN='^(build|chore|ci|docs|feat|fix|perf|refactor|revert|style|test)(\([a-z0-9._/-]+\))?!?: ([^A-Z[:space:]]|[A-Z][A-Z0-9])(.*[^.[:space:]])?$'
CC_MAX_LENGTH=100

# What to tell the user when a title is rejected.
TITLE_RULE="<type>[(scope)][!]: <description>, no capitalized first word (acronyms are fine), no final period, max $CC_MAX_LENGTH characters"

# version_gt vA.B.C vX.Y.Z -> 0 if the first version is higher. Pure bash: `sort -V`
# is missing on some systems.
version_gt() {
  local a b i
  IFS=. read -r -a a <<< "${1#v}"
  IFS=. read -r -a b <<< "${2#v}"
  for i in 0 1 2; do
    [ "${a[i]:-0}" -gt "${b[i]:-0}" ] && return 0
    [ "${a[i]:-0}" -lt "${b[i]:-0}" ] && return 1
  done
  return 1
}

# valid_title "<title>" -> 0 if the title follows the convention.
valid_title() {
  printf '%s' "$1" | grep -qE "$CC_PATTERN" && [ "${#1}" -le "$CC_MAX_LENGTH" ]
}
