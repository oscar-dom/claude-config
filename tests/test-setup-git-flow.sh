#!/usr/bin/env bash
# Tests for the setup-git-flow scripts, without GitHub.
#
# Usage:  bash tests/test-setup-git-flow.sh
#
# Every case builds a fresh world: a local bare repository as `origin`, a clone
# with main and develop, and tests/fake-gh.sh installed as `gh`, which plays
# GitHub's part (PRs, checks, merges). The scripts run unchanged against it, so
# this covers their logic (order of steps, decisions, failures, resuming), not
# GitHub's real responses: that is what a real setup confirms.
#
# Portable: runs on Linux, macOS and Git Bash on Windows (the CI runs all three).
# Exit: 0 if every check passes, 1 otherwise.

set -u
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
S="$ROOT/skills/setup-git-flow/scripts"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/sgf-tests.XXXXXX")
cleanup() { case "$WORK" in */sgf-tests.*) rm -rf -- "$WORK";; esac; }
trap cleanup EXIT

export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
mkdir -p "$WORK/bin"
cp "$ROOT/tests/fake-gh.sh" "$WORK/bin/gh"
chmod +x "$WORK/bin/gh"
export PATH="$WORK/bin:$PATH"

PASS=0; FAIL=0; N=0; CASE=""; OUT=""; RC=0

# --- helpers ----------------------------------------------------------------

# world: fresh origin + clone, left on develop. Sets W (world dir) and ST (fake state).
world() {
  N=$((N + 1)); W="$WORK/w$N"; ST="$W/state"
  mkdir -p "$ST"
  export FAKE_GH_STATE="$ST" FAKE_GH_REMOTE="$W/remote.git"
  git init -q --bare "$W/remote.git"
  git init -q "$W/repo"
  cd "$W/repo" || exit 1
  git checkout -q -b main
  git remote add origin "$W/remote.git"
  echo app > README.md
  git add README.md
  git commit -q -m "chore: initial commit"
  git push -q -u origin main 2>/dev/null
  git checkout -q -b develop
  git push -q -u origin develop 2>/dev/null
  git -C "$W/remote.git" symbolic-ref HEAD refs/heads/develop
}

# other: a second clone that pushes to develop behind the user's back
other_commit() {  # <file> <content> <message>
  [ -d "$W/other" ] || git clone -q "$W/remote.git" "$W/other" 2>/dev/null
  ( cd "$W/other" && git checkout -q develop && git pull -q origin develop 2>/dev/null &&
    echo "$2" > "$1" && git add "$1" && git commit -q -m "$3" && git push -q origin develop 2>/dev/null )
}

run() { OUT=$("$@" 2>&1); RC=$?; }
last() { printf '%s\n' "$OUT" | tail -1; }

check() {  # <description> <command...>
  local d="$1"; shift
  if "$@" >/dev/null 2>&1; then
    PASS=$((PASS + 1)); echo "  PASS  $CASE: $d"
  else
    FAIL=$((FAIL + 1)); echo "  FAIL  $CASE: $d"
    printf '%s\n' "$OUT" | sed 's/^/          | /'
  fi
}

rc_is()       { [ "$RC" -eq "$1" ]; }
last_starts() { case "$(last)" in "$1"*) return 0;; esac; return 1; }
out_has()     { printf '%s\n' "$OUT" | grep -qF -- "$1"; }
on_branch()   { [ "$(git symbolic-ref --short HEAD)" = "$1" ]; }
local_has()   { git show-ref --verify --quiet "refs/heads/$1"; }
remote_has()  { git ls-remote --exit-code --heads origin "$1" >/dev/null 2>&1; }
tag_remote()  { git ls-remote --exit-code --tags origin "refs/tags/$1" >/dev/null 2>&1; }
not()         { ! "$@"; }
on_develop_file() { git fetch -q origin develop && MSYS_NO_PATHCONV=1 git cat-file -e "origin/develop:$1"; }
subject_of()  { git fetch -q origin "$1" && [ "$(git log -1 --format=%s "origin/$1")" = "$2" ]; }
tag_at_main() { git fetch -q --tags origin main && [ "$(git rev-parse "$1^{commit}")" = "$(git rev-parse origin/main)" ]; }
clean_tree()  { [ -z "$(git status --porcelain)" ]; }
no_rebase()   { [ ! -d .git/rebase-merge ] && [ ! -d .git/rebase-apply ]; }
next_pr()     { local c=0 f; for f in "$ST"/pr.*; do [ -f "$f" ] && c=$((c + 1)); done; echo $((c + 1)); }

# release_first: ship a feature and release v0.1.0, so main has a version tag
release_first() {
  echo base > base.txt
  bash "$S/ship.sh" feat/base "feat: add base" base.txt >/dev/null 2>&1
  bash "$S/release.sh" v0.1.0 >/dev/null 2>&1
}

echo "setup-git-flow script tests ($(uname -s))"

# --- lib.sh -----------------------------------------------------------------
CASE="lib"
( . "$S/lib.sh"
  ok=0
  for t in "feat: add login" "fix: README typo" "feat(api)!: drop v1" "feat: UI"; do valid_title "$t" || ok=1; done
  for t in "feat: Add login" "feat: add login." "Add login" "feat:  add" "feat: x "; do valid_title "$t" && ok=1; done
  exit $ok ) ; RC=$?; OUT="title validation"
check "valid_title accepts and rejects the expected titles" rc_is 0
( . "$S/lib.sh"
  version_gt v1.10.0 v1.9.0 && version_gt v2.0.0 v1.99.99 && version_gt v0.1.1 v0.1.0 &&
  ! version_gt v1.2.0 v1.2.0 && ! version_gt v0.9.0 v1.2.0 ) ; RC=$?; OUT="version comparison"
check "version_gt compares numerically (v1.10.0 > v1.9.0)" rc_is 0

# --- ship.sh ----------------------------------------------------------------
CASE="ship normal"; world
echo login > login.txt
run bash "$S/ship.sh" feat/login "feat: add login" login.txt
check "exits 0 with SHIPPED"                  last_starts "SHIPPED"
check "the change is on develop"              on_develop_file login.txt
check "develop's commit is the PR title"      subject_of develop "feat: add login (#1)"
check "user is back on develop"               on_branch develop
check "branch deleted locally"   not local_has feat/login
check "branch deleted on the remote"          not remote_has feat/login
check "reports the CI check"                  out_has "check    Commit messages: pass"

CASE="ship invalid title"; world
echo x > x.txt
run bash "$S/ship.sh" feat/x "feat: Add x." x.txt
check "refuses"                               rc_is 1
check "creates no branch"                     not local_has feat/x

CASE="ship no changes"; world
run bash "$S/ship.sh" fix/nothing "fix: nothing" .
check "refuses"                               rc_is 1
check "leaves no empty branch"                not local_has fix/nothing
check "stays on develop"                      on_branch develop

CASE="ship from main"; world
git checkout -q main; echo y > y.txt
run bash "$S/ship.sh" feat/y "feat: add y" y.txt
check "refuses on main"                       rc_is 1

CASE="ship from hotfix"; world
git checkout -q -b hotfix/z; echo z > z.txt
run bash "$S/ship.sh" feat/z "feat: add z" z.txt
check "refuses on a hotfix branch"            rc_is 1
check "points to hotfix.sh"                   out_has "hotfix.sh finish"

CASE="ship commit-only"; world
echo c > c.txt
run bash "$S/ship.sh" --commit-only docs/c "docs: add c" c.txt
check "exits 0 with COMMITTED"                last_starts "COMMITTED"
check "commit is on the new branch"           on_branch docs/c
check "nothing was pushed"                    not remote_has docs/c

CASE="ship red CI, then retry"; world
echo r > r.txt; touch "$ST/ci-red-all"
run bash "$S/ship.sh" feat/r "feat: add r" r.txt
check "does not merge"                        rc_is 1
check "work stays on its branch"              on_branch feat/r
check "branch is pushed (PR open)"            remote_has feat/r
check "develop is untouched"                  not on_develop_file r.txt
rm -f "$ST/ci-red-all"
run bash "$S/ship.sh" feat/r "feat: add r"
check "retry reuses the open PR"              out_has "already open"
check "retry ships"                           last_starts "SHIPPED"
check "the change is on develop"              on_develop_file r.txt

CASE="ship conflict"; world
echo mine > README.md
bash "$S/ship.sh" --commit-only fix/readme "fix: reword readme" README.md >/dev/null 2>&1
other_commit README.md theirs "docs: theirs"
run bash "$S/ship.sh" fix/readme "fix: reword readme"
check "refuses"                               rc_is 1
check "says it is a conflict"                 out_has "conflicts"
check "no rebase left in progress"            no_rebase
check "nothing was pushed"                    not remote_has fix/readme
check "tree is clean"                         clean_tree

CASE="ship after develop moved"; world
echo a > a.txt
bash "$S/ship.sh" --commit-only feat/a "feat: add a" a.txt >/dev/null 2>&1
other_commit b.txt b "feat: add b"
run bash "$S/ship.sh" feat/a "feat: add a"
check "rebases and ships"                     last_starts "SHIPPED"
check "says it rebased"                       out_has "rebased"
check "develop has both changes"              on_develop_file b.txt
check "develop has the shipped change"        on_develop_file a.txt

CASE="ship resumed after merge"; world
echo m > m.txt
bash "$S/ship.sh" --pr-only feat/m "feat: add m" m.txt >/dev/null 2>&1
gh pr merge 1 --squash --delete-branch >/dev/null 2>&1
run bash "$S/ship.sh" feat/m "feat: add m"
check "only cleans up"                        out_has "already merged"
check "exits 0"                               rc_is 0
check "back on develop"                       on_branch develop
check "local branch removed"                  not local_has feat/m

# --- release.sh -------------------------------------------------------------
CASE="release"; world
echo f > f.txt; bash "$S/ship.sh" feat/f "feat: add f" f.txt >/dev/null 2>&1
run bash "$S/release.sh" --suggest
check "first release suggests v0.1.0"         out_has "SUGGESTED: v0.1.0"
run bash "$S/release.sh" v0.1.0
check "releases"                              last_starts "RELEASED"
check "tag on the remote"                     tag_remote v0.1.0
check "tag on main's merge commit"            tag_at_main v0.1.0
check "main's commit is the release"          subject_of main "chore: release v0.1.0"
check "GitHub release created"                grep -qx v0.1.0 "$ST/releases"
check "back on develop"                       on_branch develop
run bash "$S/release.sh" --suggest
check "nothing left to release"               last_starts "NOTHING TO RELEASE"
echo p > p.txt; bash "$S/ship.sh" fix/p "fix: correct p" p.txt >/dev/null 2>&1
run bash "$S/release.sh" --suggest
check "a fix suggests a patch"                out_has "SUGGESTED: v0.1.1"
echo q > q.txt; bash "$S/ship.sh" feat/q "feat: add q" q.txt >/dev/null 2>&1
run bash "$S/release.sh" --suggest
check "a feature suggests a minor"            out_has "SUGGESTED: v0.2.0"
echo k > k.txt; bash "$S/ship.sh" feat/k "feat!: break k" k.txt >/dev/null 2>&1
run bash "$S/release.sh" --suggest
check "a breaking change suggests a major"    out_has "SUGGESTED: v1.0.0"
run bash "$S/release.sh" v0.0.9
check "refuses a lower version"               rc_is 1
run bash "$S/release.sh" v0.1.0
check "refuses an existing tag"               rc_is 1
echo "#9 ci: bump the actions group with 1 update (into develop)" > "$ST/dependabot"
run bash "$S/release.sh" --suggest
check "lists pending Dependabot PRs"          out_has "Dependabot pull requests waiting"

CASE="release resumed after merge"; world
echo g > g.txt; bash "$S/ship.sh" feat/g "feat: add g" g.txt >/dev/null 2>&1
n=$(next_pr)
gh pr create --base main --head develop --title "chore: release v0.1.0" --body x >/dev/null 2>&1
gh pr merge "$n" --merge >/dev/null 2>&1
run bash "$S/release.sh" v0.1.0
check "resumes"                               out_has "resume"
check "tags it"                               tag_remote v0.1.0
check "exits 0"                               rc_is 0

# --- hotfix.sh --------------------------------------------------------------
CASE="hotfix start with unsaved work"; world
echo wip > wip.txt
run bash "$S/hotfix.sh" start crash
check "refuses"                               rc_is 1
check "creates no branch"                     not local_has hotfix/crash

CASE="hotfix"; world; release_first
run bash "$S/hotfix.sh" start crash
check "starts from main"                      on_branch hotfix/crash
check "announces the version"                 out_has "will publish v0.1.1"
run bash "$S/hotfix.sh" finish "fix: crash"
check "refuses without a fix"                 rc_is 1
echo fixed > crash.txt
run bash "$S/hotfix.sh" finish "fix: stop the crash" crash.txt
check "releases"                              last_starts "HOTFIX RELEASED"
check "patch tag on the remote"               tag_remote v0.1.1
check "GitHub release created"                grep -qx v0.1.1 "$ST/releases"
check "fix is back on develop"                on_develop_file crash.txt
check "back on develop"                       on_branch develop
check "hotfix branch removed"                 not local_has hotfix/crash
check "sync branch removed"                   not remote_has chore/sync-v0.1.1

CASE="hotfix resumed after main merge"; world; release_first
bash "$S/hotfix.sh" start late >/dev/null 2>&1
echo late > late.txt; git add late.txt; git commit -q -m "fix: late"
git push -q -u origin hotfix/late 2>/dev/null
n=$(next_pr)
gh pr create --base main --head hotfix/late --title "fix: late" --body x >/dev/null 2>&1
gh pr merge "$n" --merge --delete-branch >/dev/null 2>&1
run bash "$S/hotfix.sh" finish "fix: late"
check "resumes after the main merge"          out_has "already merged into main"
check "tags it"                               tag_remote v0.1.1
check "fix is back on develop"                on_develop_file late.txt

CASE="hotfix sync fails, then retry"; world; release_first
bash "$S/hotfix.sh" start sync >/dev/null 2>&1
echo s > s.txt
touch "$ST/ci-red-$(( $(next_pr) + 1 ))"   # the sync PR is the second one opened
run bash "$S/hotfix.sh" finish "fix: sync" s.txt
check "reports the release stands"            out_has "released v0.1.1, but sync PR"
check "tag is already published"              tag_remote v0.1.1
rm -f "$ST"/ci-red-*
run bash "$S/hotfix.sh" finish
check "retry resumes the sync"                out_has "resume   syncing v0.1.1"
check "retry finishes"                        last_starts "HOTFIX RELEASED"
check "fix is back on develop"                on_develop_file s.txt
check "hotfix branch removed"                 not local_has hotfix/sync

# --- merge-pr.sh ------------------------------------------------------------
CASE="merge-pr already merged"; world
echo d > d.txt; bash "$S/ship.sh" feat/d "feat: add d" d.txt >/dev/null 2>&1
run bash "$S/merge-pr.sh" 1 squash
check "a merged PR counts as merged"          last_starts "MERGED"
check "exits 0"                               rc_is 0

CASE="merge-pr waits for the required check"; world
git checkout -q -b feat/late; echo l > l.txt; git add l.txt; git commit -q -m "feat: add l"
git push -q -u origin feat/late 2>/dev/null
gh pr create --base develop --head feat/late --title "feat: add l" --body x >/dev/null 2>&1
echo 2 > "$ST/late-required"   # another check is already there and finished
run env MERGE_PR_POLL=0 bash "$S/merge-pr.sh" 1 squash
check "waits until 'Commit messages' registers" grep -q '^0$' "$ST/late-required"
check "then merges"                           last_starts "MERGED"

CASE="merge-pr without the required check"; world
git checkout -q -b feat/none; echo o > o.txt; git add o.txt; git commit -q -m "feat: add o"
git push -q -u origin feat/none 2>/dev/null
gh pr create --base develop --head feat/none --title "feat: add o" --body x >/dev/null 2>&1
touch "$ST/no-required"
run env MERGE_PR_MAX_WAIT=1 MERGE_PR_POLL=1 bash "$S/merge-pr.sh" 1 squash
check "does not merge"                        rc_is 1
check "names the missing check"               out_has "'Commit messages' check has not appeared"
check "the PR stays open"                     grep -q '^state=OPEN' "$ST/pr.1"

CASE="merge-pr with the required check red"; world
git checkout -q -b feat/red; echo e > e.txt; git add e.txt; git commit -q -m "feat: add e"
git push -q -u origin feat/red 2>/dev/null
gh pr create --base develop --head feat/red --title "feat: add e" --body x >/dev/null 2>&1
touch "$ST/required-red"
run bash "$S/merge-pr.sh" 1 squash
check "does not merge"                        rc_is 1
check "says the required check did not pass"  out_has "finished as 'fail'"

# open_pr <branch> <file>: a working branch with one commit and its PR into develop
open_pr() {
  git checkout -q -b "$1"; echo x > "$2"; git add "$2"; git commit -q -m "feat: add $2"
  git push -q -u origin "$1" 2>/dev/null
  gh pr create --base develop --head "$1" --title "feat: add $2" --body x >/dev/null 2>&1
}

CASE="merge-pr with GitHub's Dependabot check stuck pending"; world
open_pr feat/stuck s.txt
touch "$ST/other-pending"
run env MERGE_PR_POLL=0 bash "$S/merge-pr.sh" 1 squash
check "merges once the required check passed"  last_starts "MERGED"
check "says what it did not wait for"          out_has "not waited for: .github/dependabot.yml"

CASE="merge-pr with a non-required check red"; world
open_pr feat/other o.txt
touch "$ST/other-red"
run env MERGE_PR_POLL=0 bash "$S/merge-pr.sh" 1 squash
check "does not merge"                         rc_is 1
check "names the failed check"                 out_has ".github/dependabot.yml"
check "the PR stays open"                      grep -q '^state=OPEN' "$ST/pr.1"

CASE="merge-pr while the required check runs"; world
open_pr feat/slow w.txt
echo 3 > "$ST/required-pending"
run env MERGE_PR_POLL=0 bash "$S/merge-pr.sh" 1 squash
check "waits for it to finish"                 grep -q '^0$' "$ST/required-pending"
check "then merges"                            last_starts "MERGED"

CASE="merge-pr with the rulesets' required checks"; world
open_pr feat/rules r.txt
printf 'Commit messages\nTests\n' > "$ST/required-contexts"
run env MERGE_PR_MAX_WAIT=0 MERGE_PR_POLL=0 bash "$S/merge-pr.sh" 1 squash
check "waits for every required context"       out_has "waiting for 'Tests'"
check "does not merge without one of them"     rc_is 1
check "names the missing one"                  out_has "'Tests' check has not appeared"
printf 'Commit messages\n' > "$ST/required-contexts"
run env MERGE_PR_POLL=0 bash "$S/merge-pr.sh" 1 squash
check "merges when they all passed"            last_starts "MERGED"

# --- ai-attribution.sh ------------------------------------------------------
for mode in keep remove; do
  CASE="ai-attribution $mode"; world
  cp -R "$ROOT/skills/setup-git-flow/templates/." .
  cp "$ROOT/skills/setup-git-flow/ai-templates/claude/CLAUDE.md" .
  run bash "$S/ai-attribution.sh" "$mode"
  check "exits 0"                             rc_is 0
  check "leaves no markers"                   not grep -rqE 'ai-attribution:(start|end)' .
  if [ "$mode" = keep ]; then
    check "keeps the CI step"                 grep -q "Reject AI attribution" .github/workflows/ci.yml
  else
    check "removes the CI step"               not grep -q "Reject AI attribution" .github/workflows/ci.yml
    check "removes every mention"             not grep -rqi "AI attribution" .
    check "keeps the rest of the CI"          grep -q "Validate commit messages" .github/workflows/ci.yml
  fi
done

# --- audit-setup.sh ---------------------------------------------------------
CASE="audit"; world
printf 'x\n<!-- ai-attribution:start -->\n' > CONTRIBUTING.md
mkdir -p .github/workflows; echo "name: CI" > .github/workflows/ci.yml
git add CONTRIBUTING.md .github; git commit -q -m "docs: x"; git push -q origin develop 2>/dev/null
run bash "$S/audit-setup.sh"
check "is not closed"                         rc_is 1
check "finds ci.yml on develop (rev:path, Git Bash)" out_has "OK       9. .github/workflows/ci.yml is on develop"
check "detects leftover markers"              out_has "ai-attribution markers left"
check "does not close without GitHub"         out_has "cannot run"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
