# Contributing Guide

This guide explains how to work in this repository: the *what* and the *why*.

> **Quick reference:** the exact commands for every step (branches, PRs, releases,
> hotfixes, fixing mistakes) are in [`docs/git-cheatsheet.md`](docs/git-cheatsheet.md).

<!-- ai-attribution:start -->
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
<!-- ai-attribution:end -->

---

## Branching strategy (Git Flow lite)

```
main        ← production: every commit is a release, protected
  ↑ PR — merge commit        (from develop or hotfix/*)
develop     ← integration, protected, default branch
  ↑ PR — squash
<type>/<description>   ← one short-lived branch per change
```

Working branches are named after the commit type of the change, in kebab-case:
`feat/google-login`, `fix/empty-input`, `chore/update-deps`, `docs/api-auth`,
`refactor/date-helpers`, `test/login-flow`, `perf/query-cache`, `ci/add-test-job`.

Two special branches only exist when needed:

- `hotfix/<description>` — an urgent fix for production. Branches from `main`, merges
  back into `main`, and then a branch cut from `main` is merged into `develop` so the
  fix is not lost.
- `chore/sync-<version>` — brings a released hotfix back: cut from `main`, merged
  into `develop`.

### Rules

- **Never** push directly to `main` or `develop`. Always go through a pull request.
- Every change is developed on its own branch, created from an up-to-date `develop`.
- Only `develop` and `hotfix/*` can be merged into `main` (CI checks it).
- Rewrite history only on your own unmerged branch, and push it with
  `--force-with-lease`, never `--force`.

### Merge policy

| PR | Method | Why |
|----|--------|-----|
| working branch → `develop` | **Squash** | one clean commit per change; the branch is deleted |
| `develop` / `hotfix/*` → `main` | **Merge commit** | keeps the long-lived histories connected |
| `chore/sync-*` (cut from `main`) → `develop`, after a hotfix | **Merge commit** | brings the fix back without rewriting anything |

The repository is configured so that both methods use the **PR title** as the commit
message, with an empty body: the description stays on the pull request, linked from
the `(#123)` GitHub appends to the squashed title. Rebase merging is disabled and
merged branches are deleted automatically.

**Why releases use a merge commit instead of squash:** `develop` and `main` are both
long-lived branches. Squashing `develop → main` creates a new commit on `main` that
does not exist on `develop`, so the two histories diverge and every following release
PR lists everything again. With a merge commit, `develop`'s commits become ancestors of
`main` and the next release only shows what is new.

### Releases and versions

Versions follow [Semantic Versioning](https://semver.org/): `MAJOR.MINOR.PATCH`. A
release is a `develop → main` PR titled `chore: release vX.Y.Z`, followed by a
`vX.Y.Z` tag on the merge commit and a GitHub release. Version tags are permanent:
never move or delete one; if a release is wrong, publish a new version.

---

## Commit convention

We use [Conventional Commits](https://www.conventionalcommits.org/). This is the single
list of types for the repository.

```
<type>[(optional scope)][!]: <description>

[optional body: the "why" of the change]

[optional footer: BREAKING CHANGE: ...]
```

| Type | When to use it | Example |
|------|----------------|---------|
| `feat` | New user-facing functionality | `feat: add sign-in with Google` |
| `fix` | Bug fix | `fix: handle empty input in validation` |
| `docs` | Documentation only | `docs: document the payments API` |
| `refactor` | Code change with no behavior change | `refactor: simplify date helpers` |
| `test` | Add or update tests | `test: add tests for authentication` |
| `perf` | Performance improvement | `perf: cache expensive queries` |
| `style` | Formatting, whitespace (no logic change) | `style: apply formatter` |
| `build` | Build system or dependencies | `build: add bundle analyzer` |
| `ci` | CI/CD configuration | `ci: add test job` |
| `chore` | Maintenance that fits nothing above | `chore: release v1.2.0` |
| `revert` | Revert a previous change | `revert: undo google sign-in` |

### Rules

- Description in the **imperative, present tense** ("add", not "added" or "adds").
- Do **not** capitalize the first word (`add`, not `Add`); acronyms and names in
  capitals are fine (`fix: README typo`, `feat: API keys`).
- **No trailing period**, **100 characters max**.
- Breaking change: `!` after the type, `feat!: ...`. Put it in the PR title: it is
  what survives the squash. A `BREAKING CHANGE:` footer only survives in commits that
  reach `main` as they are (`hotfix/*`).
- A pull request opened with GitHub's **Revert** button keeps its `Revert "..."` title:
  CI accepts it as is.

### What CI validates

| PR into | Validated | Why |
|---|---|---|
| `develop` | the **PR title** | the branch is squashed: only the title survives, as the commit message |
| `main` | the PR title **and every commit** | merge commits keep the commits as they are |

So inside a working branch, commit freely: what matters is the PR title. Commits on a
`hotfix/*` branch must follow the convention, because they land on `main` unchanged.

---

## Pull requests

- Fill in the pull request template.
- Title: a Conventional Commit (see above). It becomes the commit message.
- Link issues in the description: `Closes #123`. The description is not copied into
  the commit, so this is where the *why* of the change lives.
- Labels (optional): `bug`, `enhancement`, `documentation`.
<!-- ai-attribution:start -->
- Keep the title and description free of AI attribution.
<!-- ai-attribution:end -->
- Wait for CI to pass before merging.

### What the repository enforces

PROTECTION_STATUS

| | `develop` | `main` |
|---|---|---|
| Changes only through a pull request | yes | yes |
| Required check: `Commit messages` | yes | yes |
| Allowed merge method | squash, merge commit | merge commit only |
| Required approvals | 0 | 0 |
| All review conversations resolved | no | yes |
| Force push and branch deletion | blocked | blocked |
| Version tags `v*` | — | cannot be moved or deleted |

Nobody can push directly to `develop` or `main`. Repository **admins**, however, can
merge a pull request that does not meet these rules: GitHub shows them a "bypass
rules" option. It is an escape hatch for a broken CI, not part of the normal flow.

Approvals default to 0 so a solo maintainer can merge their own pull requests. For a
team, raise `required_approving_review_count` in the rulesets to 1 or more.
`.github/CODEOWNERS` lists who is asked to review; GitHub never asks the author of a
PR, so with a single maintainer it has no effect until someone else contributes.

---

## FAQ

**What if I commit to `develop` or `main` by mistake?**
The push is rejected. Move the commits to a new branch:
`git branch fix/whatever && git reset --hard origin/develop` (or `origin/main`).

**`git branch -d` says my merged branch is "not fully merged".**
Expected with squash merges: the commit on `develop` is a new one. Once the PR is
merged, delete the branch with `git branch -D`.

**What if CI fails?**
Open the "Checks" tab of the PR and read the log. A bad PR title is fixed by editing
the title: CI runs again. A bad commit on a PR into `main` is fixed with
`git rebase -i` and `git push --force-with-lease`.
<!-- ai-attribution:start -->
If the failing step is `Reject AI attribution`, remove the AI trailer or
"Generated with" line as the log indicates.
<!-- ai-attribution:end -->
