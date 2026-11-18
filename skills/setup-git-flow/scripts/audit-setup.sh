#!/usr/bin/env bash
# Closing audit of setup-git-flow.
#
# Checks that nothing is left half-done (unpushed commits, branches without
# upstream, open PRs, pending promotions, unpushed tags) and READS BACK from
# GitHub what configure-github.sh applied: merge settings, rulesets, the
# required check and secret scanning. A successful API call is not proof that
# the setting is in place; reading it back is.
#
# Usage:  bash ~/.claude/skills/setup-git-flow/scripts/audit-setup.sh [--no-ai-attribution] [temp-branch]
#           --no-ai-attribution  the user chose the "no AI attribution" rule:
#                                also check that no commit carries it
#           temp-branch          defaults to chore/git-flow-setup
#
# Exit:   0 if everything is closed, 1 if something is missing. The exit code is
#         what matters: a 1 cannot be narrated as success.
#
# Legend: OK = verified, MISSING = blocks the close, ? = warning that does not
# block (plan limits, checks that could not run, optional hardening).

set -u

CHECK_AI=0
if [ "${1:-}" = "--no-ai-attribution" ]; then CHECK_AI=1; shift; fi
TEMP="${1:-chore/git-flow-setup}"
MISSING=0

ok()      { printf '  OK       %s\n' "$1"; }
missing() { printf '  MISSING  %s\n' "$1"; MISSING=$((MISSING + 1)); }
warn()    { printf '  ?        %s\n' "$1"; }

echo "Closing audit"
echo "==================="

# It has to be a repository, and its root has to be this directory.
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "  MISSING  this is not a git repository"
  exit 1
}
# Paths are not compared: on Windows the same directory has two valid forms
# (C:/... and /c/...), so string comparison gives false positives. --show-prefix
# is the path relative to the repository root: empty means "at the root"; non-empty
# covers both bad cases, a subdirectory and a folder inside someone else's repo.
PREFIX=$(git rev-parse --show-prefix 2>/dev/null)
if [ -n "$PREFIX" ]; then
  echo "  MISSING  the audit must run from the repository root"
  echo "           repository root: $ROOT"
  echo "           you are inside:  $PREFIX"
  echo "           if that root is unexpected, this project lives inside someone else's repo"
  exit 1
fi

# Without this the remote refs are stale and checks 3, 4, 6, 7 and 9 lie.
git fetch --quiet --prune --tags 2>/dev/null || warn "fetch failed: remote refs may be stale"

HAVE_GH=0; REPO=""; VIS=""
if command -v gh >/dev/null 2>&1; then
  REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null)
  VIS=$(gh repo view --json visibility --jq .visibility 2>/dev/null)
  [ -n "$REPO" ] && HAVE_GH=1
fi
# Without gh nothing on GitHub can be read back, so the setup cannot be called closed.
[ "$HAVE_GH" -eq 1 ] || missing "0. gh is missing or the repository is not reachable on GitHub: checks 5, 8 and 10-14 cannot run"

# Same rule as configure-github.sh: only a non-public repository with GitHub's
# plan message counts as a plan limit; anything else is a real failure.
is_plan_limit() {
  [ "$VIS" != "PUBLIC" ] || return 1
  printf '%s' "$1" | grep -qiE 'Upgrade to GitHub Pro|make this repository public|not available for this repository|Advanced Security|Secret Protection'
}

# 1. Clean working tree
if [ -z "$(git status --porcelain)" ]; then
  ok "1. clean working tree"
else
  missing "1. uncommitted changes:"
  git status --short | sed 's/^/           /'
fi

# 2. No local commit left unpushed, on ANY branch. The upstream is checked too:
#    %(upstream:track) is empty both for an in-sync branch and for a branch with
#    no upstream, so a never-pushed branch would slip through as clean.
PROBLEMS=""
while IFS='|' read -r branch upstream track; do
  [ -z "$branch" ] && continue
  if [ -z "$upstream" ]; then
    PROBLEMS="${PROBLEMS}           $branch: no upstream, never pushed\n"
  elif printf '%s' "$track" | grep -q 'ahead'; then
    PROBLEMS="${PROBLEMS}           $branch: $track\n"
  fi
done <<< "$(git for-each-ref --format='%(refname:short)|%(upstream:short)|%(upstream:track)' refs/heads)"
if [ -z "$PROBLEMS" ]; then
  ok "2. no branch with unpushed commits"
else
  missing "2. commits that never reached the remote:"
  printf '%b' "$PROBLEMS"
fi

# 3. main and develop exist on the remote
for r in main develop; do
  if git ls-remote --exit-code --heads origin "$r" >/dev/null 2>&1; then
    ok "3. $r exists on the remote"
  else
    missing "3. $r does NOT exist on the remote"
  fi
done

# 4. Nothing on develop left unpromoted to main
if git rev-parse --verify --quiet origin/main >/dev/null && git rev-parse --verify --quiet origin/develop >/dev/null; then
  N=$(git rev-list --count origin/main..origin/develop)
  if [ "$N" = "0" ]; then
    ok "4. develop and main in sync"
  else
    missing "4. develop has $N commit(s) not promoted to main"
    git log --oneline origin/main..origin/develop | sed 's/^/           /'
  fi
else
  warn "4. cannot compare: origin/main or origin/develop is missing"
fi

# 5. No setup PR left open. Only the PRs the setup opens count: from the temporary
#    branch, and develop into main. Others (Dependabot, which configure-github.sh
#    enables and may open PRs right away, or PRs that already existed) are not
#    half-done setup work: listed as a warning, never blocking forever.
if [ "$HAVE_GH" -eq 1 ]; then
  if ! ALL=$(gh pr list --state open --json number,title,headRefName,baseRefName \
      --jq '.[] | "#\(.number)|\(.headRefName)|\(.baseRefName)|\(.title)"' 2>/dev/null); then
    missing "5. could not list the pull requests"
  else
    OWN=""; OTHER=""
    while IFS='|' read -r num head base title; do
      [ -z "$num" ] && continue
      line="           $num $head -> $base: $title\n"
      if [ "$head" = "$TEMP" ] || { [ "$head" = "develop" ] && [ "$base" = "main" ]; }; then
        OWN="${OWN}${line}"
      else
        OTHER="${OTHER}${line}"
      fi
    done <<< "$ALL"
    if [ -z "$OWN" ]; then
      ok "5. no setup pull request left open"
    else
      missing "5. setup pull requests still open:"
      printf '%b' "$OWN"
    fi
    if [ -n "$OTHER" ]; then
      warn "5. other open pull requests, unrelated to the setup (not blocking):"
      printf '%b' "$OTHER"
    fi
  fi
fi

# 6. The temporary setup branch is gone
if [ -n "$(git branch --list "$TEMP")" ]; then
  missing "6. temporary branch $TEMP still exists locally"
else
  ok "6. temporary branch $TEMP is gone locally"
fi
if git ls-remote --exit-code --heads origin "$TEMP" >/dev/null 2>&1; then
  missing "6. temporary branch $TEMP still exists on the remote"
else
  ok "6. temporary branch $TEMP is gone on the remote"
fi

# 7. Every local tag is pushed
LOCAL_TAGS=$(git tag -l)
if [ -z "$LOCAL_TAGS" ]; then
  ok "7. no local tags to push"
else
  UNPUSHED=""
  for t in $LOCAL_TAGS; do
    git ls-remote --exit-code --tags origin "refs/tags/$t" >/dev/null 2>&1 || UNPUSHED="$UNPUSHED $t"
  done
  if [ -z "$UNPUSHED" ]; then
    ok "7. every tag is on the remote"
  else
    missing "7. unpushed tags:$UNPUSHED"
  fi
fi

# 8. develop is the default branch (set by configure-github.sh)
if [ "$HAVE_GH" -eq 1 ]; then
  DEFAULT=$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name 2>/dev/null)
  if [ "$DEFAULT" = "develop" ]; then
    ok "8. develop is the default branch"
  elif [ -z "$DEFAULT" ]; then
    warn "8. could not read the default branch"
  else
    missing "8. the default branch is $DEFAULT, not develop (re-run configure-github.sh)"
  fi
fi

# 9. The templates reached develop complete: the CI exists, and no
#    ai-attribution marker was left behind (ai-attribution.sh was run).
if git rev-parse --verify --quiet origin/develop >/dev/null; then
  # MSYS_NO_PATHCONV only here: Git Bash (Windows) would turn this <rev>:<path>
  # argument into a Windows path. Not globally: real paths passed to git.exe or
  # gh.exe (e.g. the rulesets' JSON files) need that conversion.
  if MSYS_NO_PATHCONV=1 git cat-file -e origin/develop:.github/workflows/ci.yml 2>/dev/null; then
    ok "9. .github/workflows/ci.yml is on develop"
  else
    missing "9. .github/workflows/ci.yml is NOT on develop"
  fi
  LEFT=$(git grep -lE 'ai-attribution:(start|end)' origin/develop 2>/dev/null | sed 's/^origin\/develop://')
  if [ -z "$LEFT" ]; then
    ok "9. no ai-attribution markers left in the templates"
  else
    missing "9. ai-attribution markers left (run ai-attribution.sh): $(echo $LEFT)"
  fi
fi

if [ "$HAVE_GH" -eq 1 ]; then
  # 10. Merge settings, read back
  GOT=$(gh api "repos/$REPO" --jq '[.allow_squash_merge, .allow_merge_commit, .allow_rebase_merge, .delete_branch_on_merge, .squash_merge_commit_title, .squash_merge_commit_message, .merge_commit_title, .merge_commit_message] | map(tostring) | join(",")' 2>/dev/null)
  WANT="true,true,false,true,PR_TITLE,BLANK,PR_TITLE,BLANK"
  if [ "$GOT" = "$WANT" ]; then
    ok "10. merge settings: squash + merge commit, no rebase, PR title, empty body, delete branches"
  elif [ -z "$GOT" ]; then
    missing "10. could not read the merge settings"
  else
    missing "10. merge settings differ (re-run configure-github.sh)"
    echo "           expected: $WANT"
    echo "           got:      $GOT"
  fi

  # 11. Rulesets present and active, read back
  RULESETS=$(gh api "repos/$REPO/rulesets" --jq '.[] | "\(.name)\t\(.enforcement)"' 2>&1); rc=$?
  RULESETS_OK=0
  if [ $rc -ne 0 ] && is_plan_limit "$RULESETS"; then
    warn "11. rulesets unavailable on this plan and visibility: PENDING in the summary, with that reason"
  elif [ $rc -ne 0 ]; then
    missing "11. could not list the rulesets"
    printf '%s\n' "$RULESETS" | head -3 | sed 's/^/           /'
  else
    RULESETS_OK=1
    for name in "Protect main" "Protect develop" "Protect release tags"; do
      state=$(printf '%s\n' "$RULESETS" | awk -F '\t' -v n="$name" '$1 == n { print $2; exit }')
      if [ "$state" = "active" ]; then
        ok "11. ruleset \"$name\" active"
      elif [ -z "$state" ]; then
        missing "11. ruleset \"$name\" does not exist (re-run configure-github.sh)"
      else
        missing "11. ruleset \"$name\" is $state, not active"
      fi
    done
  fi

  # 12. What GitHub really enforces on main and develop: the pull request rule and
  #     the required check, bound to GitHub Actions.
  if [ "$RULESETS_OK" -eq 1 ]; then
    for b in main develop; do
      RULES=$(gh api "repos/$REPO/rules/branches/$b" --jq '[.[] | if .type == "required_status_checks" then (.parameters.required_status_checks[] | "check:\(.context)@\(.integration_id)") else .type end] | join(" ")' 2>/dev/null)
      case " $RULES " in
        *" pull_request "*) ok "12. $b: changes only through pull requests" ;;
        *) missing "12. $b: the pull request rule is not in effect" ;;
      esac
      case " $RULES " in
        *" check:Commit messages@15368 "*) ok "12. $b: required check 'Commit messages' from GitHub Actions" ;;
        *) missing "12. $b: required check 'Commit messages' (GitHub Actions) is not in effect" ;;
      esac
    done
  fi

  # 13. Secret scanning and push protection: free and expected on public
  #     repositories; on private ones they depend on the plan.
  SEC=$(gh api "repos/$REPO" --jq '[.security_and_analysis.secret_scanning.status, .security_and_analysis.secret_scanning_push_protection.status] | map(tostring) | join(",")' 2>/dev/null)
  if [ "$SEC" = "enabled,enabled" ]; then
    ok "13. secret scanning and push protection enabled"
  elif [ "$VIS" = "PUBLIC" ]; then
    missing "13. secret scanning / push protection not enabled on a public repository ($SEC)"
  else
    warn "13. secret scanning not enabled on this private repository (plan limit): PENDING in the summary"
  fi

  # 14. Default workflow token permissions. Repositories created since 2023 default
  #     to read-only; an older one may still allow write to every workflow that
  #     does not declare `permissions:`. Hardening, not part of the setup: warning.
  WF=$(gh api "repos/$REPO/actions/permissions/workflow" --jq .default_workflow_permissions 2>/dev/null)
  if [ "$WF" = "read" ]; then
    ok "14. default workflow token is read-only"
  elif [ -n "$WF" ]; then
    warn "14. default workflow token is '$WF': consider read-only (Settings > Actions > General)"
  else
    warn "14. could not read the default workflow token permissions"
  fi
fi

# 15. No AI attribution in the history, when the user chose that rule
if [ "$CHECK_AI" -eq 1 ]; then
  HITS=$(git log --all --format=%B | grep -iE 'co-authored-by:.*(claude|anthropic)|generated with' || true)
  if [ -z "$HITS" ]; then
    ok "15. no AI attribution in any commit"
  else
    missing "15. commits with AI attribution:"
    printf '%s\n' "$HITS" | head -5 | sed 's/^/           /'
  fi
fi

echo "==================="
if [ "$MISSING" -eq 0 ]; then
  echo "CLOSED: nothing pending, and GitHub reports what the setup applied."
  exit 0
fi
echo "PENDING: $MISSING check(s) not closed."
echo "Do not report the setup as complete. Tell the user what is missing"
echo "and ask for permission to finish it."
exit 1
