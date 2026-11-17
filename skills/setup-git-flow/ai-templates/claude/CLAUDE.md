# CLAUDE.md

## Git workflow

This repository follows Git Flow lite: `main` holds releases, `develop` is the
integration branch (and the default), and every change goes through a short-lived
branch and a pull request into `develop`. **You run git for the user**, who may know
no git at all. Everything below is enough for daily work: do not read
`docs/git-cheatsheet.md` unless a recipe sends you there.

### Talking to the user

- Inspect first, then present **one plan in plain language** and ask **once**: what
  gets saved, under which name, and where it goes. With a yes, run the whole recipe
  without asking again, and end with one or two sentences on what happened.
- Say "save your changes" and "add them to the development version", not "squash",
  "rebase" or "upstream". Name the branch and the message so the user can object.
- Stop and explain (no retry loops) when a script's last line says it did not
  finish (`NOT SHIPPED`, `NOT RELEASED`, `NOT MERGED`, `HOTFIX NOT DONE`): say what
  happened and the safe next step. Never work around a failed CI or a conflict.

### Recipes

The scripts live in the `setup-git-flow` skill. Always call them exactly as written:
the user's permission rule matches that path.

**Scripts that wait for the CI** (`ship.sh` without `--commit-only`, `release.sh vX.Y.Z`,
`hotfix.sh finish`, `merge-pr.sh`) can take longer than a command timeout. Run them
**in the background** (`run_in_background`) and wait for the completion notice: do
not poll, and run no other git command meanwhile. If one is cut off anyway, run the
same command again: it detects what is already done and continues.

**Save / upload the work** ("commit", "push", "update the repo", "upload today's work"):

1. `git status --short` and `git diff --stat`; read the diff where the intent is unclear.
   Leave out what must not be versioned (secrets, local data, build output) and say so.
2. Choose the type (`feat`, `fix`, `docs`, `refactor`, `test`, `perf`, `style`,
   `build`, `ci`, `chore`), the branch `<type>/<short-kebab-description>` and the title,
   a Conventional Commit in English: `feat: validate email on login` (imperative, no
   capitalized first word, no final period; `ship.sh` checks it before pushing). Unrelated changes → one ship per
   topic, all in the same plan.
3. Plan + one question. Then:
   `bash ~/.claude/skills/setup-git-flow/scripts/ship.sh <branch> "<title>" <paths...>`
   It branches off `develop` when needed, commits, pushes, opens the PR, waits for the
   CI, squash-merges and leaves the user on an up-to-date `develop`. Its last line is
   the outcome.
   - "Just commit" → add `--commit-only` first. "Open the PR but don't merge" →
     `--pr-only`.

**Publish a version** ("release", "publish", "move it to main"):

1. `bash ~/.claude/skills/setup-git-flow/scripts/release.sh --suggest` (read-only).
2. Present the changes and the suggested version; ask once, the version included. If
   it lists Dependabot updates, put them in the same question ("apply the pending
   CI tool updates first?"); with a yes, apply them (recipe below) and run
   `--suggest` again before releasing.
3. `bash ~/.claude/skills/setup-git-flow/scripts/release.sh vX.Y.Z` — release PR, CI,
   merge commit into `main`, tag and GitHub release.

**Apply pending updates** ("apply the updates", or from the release recipe):

1. `gh pr list --author app/dependabot --state open` and, for each one,
   `gh pr checks <n>`. Say in plain words what they update (the tools the CI uses,
   or a security fix) and whether their checks are green. Ask once for all.
2. For each one: `bash ~/.claude/skills/setup-git-flow/scripts/merge-pr.sh <n> squash`.
   It only merges when the CI is green; a failed one stays open: explain it.
3. `git checkout develop` and `git pull --prune`.

**Urgent fix of what is released** ("production is broken", "hotfix"):

1. Before touching any code:
   `bash ~/.claude/skills/setup-git-flow/scripts/hotfix.sh start <short-name>`
   (it refuses with uncommitted work: save that first with `ship.sh --commit-only`).
2. Write the fix on that branch, then present one plan: the fix, the title (`fix: …`)
   and the version `start` said it will publish. Ask once.
3. `bash ~/.claude/skills/setup-git-flow/scripts/hotfix.sh finish "<title>" <paths...>`
   — PR into `main`, CI, merge, patch tag and release, then the fix back into
   `develop`. If its last line says the sync into `develop` failed, the release
   stands: explain and resolve only the sync.

**Anything else** (undoing a commit, a lost branch, conflicts): read only the
matching section of `docs/git-cheatsheet.md`.

**Scripts not installed** (another machine): same plan, by hand: branch from
`develop`, commit, push, `gh pr create --base develop`, then
`gh pr checks <n> --watch` (in the background) and only when green
`gh pr merge <n> --squash --delete-branch`; finally `git checkout develop`,
`git pull --prune`, `git branch -D <branch>`.

### Rules that always apply

- Never push to `main` or `develop`, never `--force` (only `--force-with-lease` on your
  own unmerged branch), never `--no-verify`, never `gh pr merge --admin`.
- Squash into `develop`; merge commit into `main`. The PR title becomes the commit
  message.
- Commits, PRs, issues and docs in English, whatever language the user speaks.
<!-- ai-attribution:start -->
- No AI attribution anywhere: no `Co-Authored-By:` trailer for an AI and no
  "Generated with" line in commits, PRs or files. CI rejects it.
<!-- ai-attribution:end -->
