# Shared by ship.sh and hotfix.sh. Sourced, not run.
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

# valid_title "<title>" -> 0 if the title follows the convention.
valid_title() {
  printf '%s' "$1" | grep -qE "$CC_PATTERN" && [ "${#1}" -le "$CC_MAX_LENGTH" ]
}
