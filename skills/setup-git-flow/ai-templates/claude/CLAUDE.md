# CLAUDE.md

## Git workflow

This repository follows Git Flow lite. Before running `git` or `gh` commands, read
[`docs/git-cheatsheet.md`](docs/git-cheatsheet.md) — it is the source of truth for
branches, commits, pull requests, releases and hotfixes. The policy behind it is in
[`CONTRIBUTING.md`](CONTRIBUTING.md).

Rules that always apply:

- Never push to `main` or `develop`. Work on a branch from `develop` (`feat/`, `fix/`,
  `chore/`, `docs/`, `refactor/`, `test/`…) and open a pull request into `develop`.
- The PR title must be a Conventional Commit (`feat: add x`): it becomes the commit
  message. CI rejects the PR otherwise.
- Merge into `develop` with squash; merge into `main` (releases and hotfixes) with a
  merge commit. Never squash into `main`.
- Rewrite history only on your own unmerged branch, and push it with
  `--force-with-lease`, never `--force`. Never use `--no-verify`.
- After a merge: `git checkout develop && git pull --prune`, then
  `git branch -D <branch>` (squash merges are not detected by `git branch -d`).
- Write commits, PRs, issues and docs in English.
- No AI attribution anywhere: no `Co-Authored-By:` trailer for an AI and no
  "Generated with" line in commits, PRs or files. CI rejects it.
