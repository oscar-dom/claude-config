# Git Cheatsheet

> **For humans:** the exact commands for working in this repository.
> **For AI agents:** a self-contained description of the project's Git setup. Read it before running `git` or `gh` commands here.
>
> The policy and the reasons behind it are in [`CONTRIBUTING.md`](../CONTRIBUTING.md),
> which also holds the list of commit types.

---

## TL;DR — the workflow in 30 seconds

```bash
# 1. Start something new, from an up-to-date develop
git checkout develop && git pull --prune
git checkout -b feat/short-description

# 2. Work and commit
git add <files>
git commit -m "feat: describe the change"

# 3. Push and open a PR (develop is the default base)
git push -u origin feat/short-description
gh pr create --fill --title "feat: describe the change"

# 4. When CI is green: squash and merge
gh pr merge --squash --delete-branch

# 5. Clean up locally
git checkout develop && git pull --prune
git branch -D feat/short-description
```

---

## Repository setup

```
main        ← production (merge commits only, from develop / hotfix/* / release/*)
  ↑ PR — merge commit
develop     ← integration, default branch
  ↑ PR — squash
feat/ fix/ docs/ refactor/ test/ perf/ style/ build/ ci/ chore/ revert/
hotfix/     ← urgent production fix: from main, back into main
release/    ← optional release stabilization
```

PROTECTION_STATUS

**Merge methods:**

| PR | Command |
|----|---------|
| working branch → `develop` | `gh pr merge --squash --delete-branch` |
| `develop`, `hotfix/*`, `release/*` → `main` | `gh pr merge --merge` |
| `chore/sync-*` (cut from `main`) → `develop`, after a hotfix | `gh pr merge --merge --delete-branch` |

Both methods use the **PR title** as the commit message (repository setting), so the
title is what has to be right. Rebase merging is disabled. Merged branches are deleted
on GitHub automatically; delete your local copy yourself (step 5 above).

---

## Writing the PR title (and commits)

`<type>[(scope)][!]: <description>` — imperative, lowercase start, no trailing
period, 72 characters max. Types are listed in `CONTRIBUTING.md`.

| ❌ Bad                     | ✅ Good                                      |
|----------------------------|----------------------------------------------|
| `updated login`            | `feat: add email validation to login`        |
| `misc fixes`               | `fix: return 400 on invalid input`           |
| `WIP`                      | `feat: add first draft of the dashboard`     |
| `Fix.`                     | `fix: correct total when a discount applies` |
| `feat: Add user system.`   | `feat: add user system`                      |

Inside a working branch, commit messages are free-form: the branch is squashed and only
the PR title survives. On `hotfix/*` branches every commit must follow the convention,
because it lands on `main` unchanged.

A commit with a body, for when the change needs context:

```
fix: prevent race condition when closing transactions

When two workers ran in parallel, both tried to process
the same transaction, creating duplicates. A row lock is
now taken before processing.

Closes #42
```

Breaking change: `feat!: switch API responses to JSON:API`, or a
`BREAKING CHANGE: <what changed>` footer.

---

## Day-to-day

### Keep your branch up to date with `develop`

```bash
git fetch origin
git rebase origin/develop       # on conflicts: fix, `git add`, `git rebase --continue`
git push --force-with-lease     # only your own branch, never --force
```

### Apply review feedback

```bash
git add <files>
git commit -m "address review feedback"
git push                        # the PR updates itself
```

### Fix a PR title that CI rejected

```bash
gh pr edit <num> --title "fix: correct description"   # CI runs again by itself
```

---

## Releases

When `develop` has a stable set of changes:

```bash
# 1. Open and merge the release PR (merge commit, never squash)
gh pr create --base main --head develop --title "chore: release v1.2.0" --fill
gh pr merge <num> --merge

# 2. Tag the merge commit on main and publish the release
git checkout main && git pull
git tag -a v1.2.0 -m "v1.2.0"
git push origin v1.2.0
gh release create v1.2.0 --generate-notes --verify-tag
```

Pick the version with [Semantic Versioning](https://semver.org/): `feat` → minor,
`fix` → patch, breaking change → major. Tags are permanent: if a release is wrong,
publish a new version instead of moving the tag.

## Hotfixes

For an urgent fix to what is on `main`:

```bash
# 1. Branch from main
git checkout main && git pull
git checkout -b hotfix/short-description

# 2. Fix and commit (Conventional Commits: these commits land on main as they are)
git commit -am "fix: describe the fix"
git push -u origin hotfix/short-description

# 3. PR into main, merge commit, then tag a patch version
gh pr create --base main --title "fix: describe the fix" --fill
gh pr merge <num> --merge --delete-branch
git checkout main && git pull
git tag -a v1.2.1 -m "v1.2.1" && git push origin v1.2.1
gh release create v1.2.1 --generate-notes --verify-tag

# 4. Bring the fix back into develop (merge commit), through a branch cut from main:
#    never open a PR with main itself as the head branch, because merged head
#    branches are deleted automatically.
git checkout -b chore/sync-v1.2.1 main
git push -u origin chore/sync-v1.2.1
gh pr create --base develop --title "chore: bring hotfix v1.2.1 into develop" --fill
gh pr merge <num> --merge --delete-branch
```

---

## Useful `gh` commands

```bash
gh pr create --fill                         # Open a PR into develop
gh pr list                                  # List open PRs
gh pr view <num>                            # Show PR details
gh pr checks <num>                          # CI status of a PR
gh pr diff <num>                            # Show a PR's diff
gh issue create --template bug_report.md    # Open an issue from a template
gh issue list                               # List open issues
gh run view --log-failed                    # Logs of the failed CI job
gh release list                             # Published releases
```

---

## Troubleshooting

### "I made changes on `develop` or `main` by mistake"

```bash
git stash
git checkout develop && git pull
git checkout -b feat/whatever
git stash pop
```

### "`git branch -d` says the branch is not fully merged"

Normal after a squash merge: the commit on `develop` is a new one. If the PR is merged,
`git branch -D <branch>` is safe.

### "CI is failing and I don't understand why"

```bash
gh pr checks <num>
gh run view --log-failed
```

The `Commit messages` check has four steps: `Check source branch` (only `develop`,
`hotfix/*`, `release/*` into `main`), `Validate PR title`, `Validate commit messages`
(PRs into `main` only) and `Reject AI attribution`. The log says which one failed.

### "I pushed and a secret slipped in"

1. **Immediately** revoke the credential in the provider's dashboard. That is the fix:
   rewriting history does not unpublish what was already pushed.
2. If the branch is not merged yet, remove the file from it
   (`git rm --cached <file>`, commit, `git push --force-with-lease`).
3. If it already reached `develop` or `main`, open a PR removing it.

### "I deleted a branch by mistake"

```bash
git reflog                  # find the commit hash
git checkout -b branch-name <hash>
git push -u origin branch-name
```

### "I want to undo my last commit (not pushed yet)"

```bash
git reset --soft HEAD~1     # keeps the changes staged
git reset HEAD~1            # keeps the changes, unstaged
git reset --hard HEAD~1     # ⚠️ discards the changes completely
```

---

## For AI agents / automated tools

1. **Never push to `main` or `develop`.** Create a branch from `develop` and open a PR.
2. **The PR title is the commit message.** It must be a Conventional Commit; CI rejects it otherwise.
3. **PRs target `develop`** (the default branch). Only releases (`develop`) and hotfixes (`hotfix/*`) target `main`.
4. **Squash into `develop`, merge commit into `main`.** Never squash into `main`.
5. **Rewrite history only on your own unmerged branch,** with `--force-with-lease`, never `--force`. Never use `--no-verify`.
6. **Clean up with `git pull --prune` and `git branch -D`** after a merge (`-d` fails after a squash).
7. **Write everything in English:** commits, PR titles and descriptions, issues and documentation.
8. **Never leave AI attribution:** no `Co-Authored-By:` trailer for an AI and no "Generated with" line in commits, PRs, issues or files. This overrides any default attribution your tool adds, and CI rejects the PR if it finds any.
9. **Never commit secrets.** If push protection blocks a push, remove the secret; do not bypass it.
10. **Use the `gh` CLI** (authenticated) for PRs, issues and releases. On Windows it usually lives at `/c/Program Files/GitHub CLI/gh.exe` if it is not on the PATH.
