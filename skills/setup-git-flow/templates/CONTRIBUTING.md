# Contributing Guide

This guide explains how to work in this repository.

> **Quick reference:** for day-to-day work (exact commands, resolving conflicts,
> what to do when something goes wrong) see [`docs/git-cheatsheet.md`](docs/git-cheatsheet.md).
> This guide is the *what* and the *why*; the cheatsheet is the *how*.

> [!IMPORTANT]
> **No AI attribution in this repository.** Claude, Claude Code and any other AI
> assistant must **never** leave their mark as a collaborator here. That means:
>
> - **No `Co-Authored-By:` trailers** for an AI (e.g. `Co-Authored-By: Claude <noreply@anthropic.com>`)
>   in commit messages.
> - **No "Generated with Claude Code"** lines, links or badges (or the equivalent for any
>   other tool) in commit messages, PR titles, PR descriptions, issues, comments or files.
> - **No AI listed as author or committer.** Commits are authored by the human
>   contributor who is responsible for them.
>
> **CI enforces it:** the `Reject AI attribution` step of the required `Commit messages`
> check fails the pull request if any commit or the PR title or description carries
> AI attribution, so a PR with it cannot be merged.
>
> This rule overrides any default attribution the tool adds on its own. If an AI
> assistant prepares a commit or a pull request, remove the attribution before pushing.
> If it slipped into a commit that is not merged yet, reword it
> (`git commit --amend` or `git rebase -i develop`) and push with `--force-with-lease`.

---

## Branching strategy (Git Flow lite)

```
main      ← production, protected
  ↑ PR — merge commit
develop   ← integration, protected
  ↑ PR — squash
feat/<description>   ← one branch per feature
fix/<description>    ← one branch per bug fix
chore/<description>  ← maintenance, dependencies, configuration
docs/<description>   ← documentation changes
```

### Rules

- **Never** push directly to `main` or `develop`. Always go through a pull request.
- Every change is developed on its own branch, created from `develop`.
- Pull requests are merged into `develop`. When there is a stable set of changes, open a
  `develop → main` pull request to release it.

### Merge policy

The `main` and `develop` rulesets allow **both squash and merge commit**, so GitHub
will offer both buttons. Which one to use is not optional; it depends on the PR:

| PR | Method | GitHub button |
|----|--------|---------------|
| `feat/*`, `fix/*`, `chore/*`, `docs/*` → `develop` | **Squash** | "Squash and merge" |
| `develop` → `main` (release) | **Merge commit** | "Create a merge commit" |

**Why releases use a merge commit instead of squash:** `develop` and `main` are both
long-lived branches. Squashing `develop → main` does not merge the branches; it creates
a new commit on `main` that does not exist on `develop`, so the two histories diverge
and `main` never contains `develop`'s commits. In practice, every following
`develop → main` PR lists everything again, because Git has no recent common ancestor
to compare against. With a merge commit, `develop`'s commits land on `main` as they are,
become ancestors, and the next release only shows what is new.

Inside a feature branch, squash is what we want: the branch is short-lived, disposable
and deleted after the merge, so collapsing it into one commit splits no history and
keeps `develop` readable (one commit per feature).

The exact commands for each case are in
[`docs/git-cheatsheet.md`](docs/git-cheatsheet.md).

---

## Step-by-step workflow

### 1. Start something new

```bash
git checkout develop
git pull
git checkout -b feat/short-description
```

### 2. Make changes and commit

```bash
git add <files>
git commit -m "feat: describe the change"
```

(See [Commit convention](#commit-convention) below.)

### 3. Push the branch and open a PR

```bash
git push -u origin feat/short-description
gh pr create --base develop --fill
```

### 4. Address feedback and merge

- Wait for CI to pass (green).
- If changes are requested: add more commits to the same branch and push. The PR
  updates itself.
- When everything is ready: use **"Squash and merge"** (it is a PR into `develop`) to
  keep the history clean. If you are merging the `develop → main` release, the method
  is **merge commit** — see [Merge policy](#merge-policy).

### 5. Clean up after the merge

```bash
git checkout develop
git pull
git branch -d feat/short-description
```

---

## Commit convention

We use [Conventional Commits](https://www.conventionalcommits.org/). CI validates every
commit in a pull request, and the check is required to merge.

### Format

```
<type>: <short description in the imperative mood>

[optional body with more context]

[optional footer with BREAKING CHANGE, issue references, etc.]
```

### Types

| Type | When to use it | Example |
|------|----------------|---------|
| `feat` | New user-facing functionality | `feat: add sign-in with Google` |
| `fix` | Bug fix | `fix: handle empty input in validation` |
| `chore` | Maintenance, dependencies, configuration | `chore: update dependencies` |
| `docs` | Documentation only | `docs: document the payments API` |
| `refactor` | Refactor with no behavior change | `refactor: simplify date helpers` |
| `test` | Add or update tests | `test: add tests for authentication` |
| `style` | Formatting, whitespace (no logic change) | `style: apply formatter` |
| `perf` | Performance improvement | `perf: cache expensive queries` |
| `build` | Build system or build dependencies | `build: add bundle analyzer` |
| `ci` | CI/CD changes | `ci: add test job` |
| `revert` | Revert a previous commit | `revert: undo "feat: add X"` |

### Rules

- Description in the **imperative, present tense** ("add", not "added" or "adds").
- **Lowercase** first letter.
- **No trailing period**.
- **72 characters max** on the first line.
- Breaking change: `feat!:` or a `BREAKING CHANGE:` footer.
- **No AI attribution** in the message: no `Co-Authored-By:` trailer for an AI and no
  "Generated with Claude Code" line — see the note at the top of this guide.

---

## Pull requests

### Before opening a PR

- [ ] The branch is up to date with `develop`.
- [ ] You have tested the changes locally.
- [ ] You have updated the documentation if needed.

### When opening a PR

- Fill in the pull request template.
- Use a Conventional Commits title (it becomes the squash commit).
- Keep the title and description free of AI attribution ("Generated with Claude Code"
  or similar).
- Add relevant labels (`bug`, `enhancement`, `docs`, etc.).
- Link issues: `Closes #123`.

### Review and merge requirements

What the branch rulesets enforce:

| | `develop` | `main` |
|---|---|---|
| Changes only through a pull request | yes | yes |
| Required check: `Commit messages` | yes | yes |
| Required approvals | 0 | 0 |
| All review conversations resolved | no | yes |
| Force push and branch deletion | blocked | blocked |

Approvals default to 0 so a solo maintainer can merge their own pull requests. For a
team, raise `required_approving_review_count` in the rulesets to 1 or more.

---

## FAQ

**What if I commit to `main` by mistake?**
Nothing breaks — `main` is protected and will reject the push. Move the commits to a
new branch: `git branch fix/whatever && git reset --hard origin/main`.

**Squash, merge or rebase?**
Squash for feature PRs into `develop` (one clean commit per feature). Merge commit for
the `develop → main` release, so the two long-lived histories do not split — see
[Merge policy](#merge-policy). Rebase only to keep your branch up to date with
`develop`, never to merge.

**What if CI fails?**
Open the "Checks" tab of the PR and read the log. If `Commit messages` fails, reword
the offending commits (`git rebase -i develop`, then `git push --force-with-lease`) so
they follow the [commit convention](#commit-convention). If the failing step is
`Reject AI attribution`, remove the AI trailer or "Generated with" line from the
commits, or from the PR description, as the log indicates.
