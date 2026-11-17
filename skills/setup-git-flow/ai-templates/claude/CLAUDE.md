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
- Stop and explain (no retry loops) only when a script ends in `NOT SHIPPED` or
  `NOT RELEASED`, or when there are conflicts. Say what happened and the safe next
  step.

### Recipes

The scripts live in the `setup-git-flow` skill. Always call them exactly as written
(the user's permission rule matches that path) and with a 10-minute tool timeout:
they wait for the CI.

**Save / upload the work** ("commit", "push", "update the repo", "upload today's work"):

1. `git status --short` and `git diff --stat`; read the diff where the intent is unclear.
   Leave out what must not be versioned (secrets, local data, build output) and say so.
2. Choose the type (`feat`, `fix`, `docs`, `refactor`, `test`, `perf`, `style`,
   `build`, `ci`, `chore`), the branch `<type>/<short-kebab-description>` and the title,
   a Conventional Commit: `feat: validate email on login` (imperative, lowercase start,
   no final period, max 100 characters, in English). Unrelated changes → one ship per
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
2. Present the changes and the suggested version; ask once, the version included.
3. `bash ~/.claude/skills/setup-git-flow/scripts/release.sh vX.Y.Z` — release PR, CI,
   merge commit into `main`, tag and GitHub release.

**Anything else** (urgent production fix, undoing a commit, a lost branch, conflicts):
read only the matching section of `docs/git-cheatsheet.md`.

**Scripts not installed** (another machine): same plan, by hand: branch from
`develop`, commit, push, `gh pr create --base develop`, then
`gh pr checks <n> --watch` (10-minute timeout) and only when green
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
