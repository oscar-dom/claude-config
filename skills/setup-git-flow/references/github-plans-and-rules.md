# GitHub: plans, settings, rulesets and merge policy

Detail of pre-flight check 5 and step 4 of `SKILL.md`.

## What each plan includes (personal accounts)

| | Public (any plan) | Private, Free | Private, Pro |
|---|---|---|---|
| Merge settings, `develop` as default branch, CI, Dependabot | yes | yes | yes |
| Rulesets (`main`, `develop`, `v*` tags) | yes | **no** (`403 Upgrade to GitHub Pro`) | yes |
| Secret scanning and push protection | yes | **no** | **no** (needs GitHub Secret Protection, organizations only) |
| Code readable by anyone | yes | no | no |

Read the plan with `gh api user --jq .plan.name` (`free`, `pro`…). If the repository
will be created in an **organization**, the organization's plan is what counts:
`gh api orgs/<org> --jq .plan.name` (needs a member with permissions; if it does not
answer, show the full table and say so). In organizations, Team is equivalent to Pro
for rulesets.

How to use it when asking about visibility: show **only the column that applies** to
each option. On Pro, choosing private keeps branch protection, and that must be said.
On Free, private means no rulesets and no secret scanning: a valid choice, not a
problem to solve.

## What GitHub enforces in each case

The **repository settings** applied by `configure-github.sh` work on every plan, and
on a private Free repository they are the only thing GitHub enforces:

| Setting | Value | Effect |
|---|---|---|
| `allow_squash_merge` / `allow_merge_commit` | `true` | the two methods of the policy |
| `allow_rebase_merge` | `false` | no button outside the policy |
| `squash_merge_commit_title` / `_message` | `PR_TITLE` / `BLANK` | the squash commit is the PR title, not the first commit's, and without the template noise |
| `merge_commit_title` / `_message` | `PR_TITLE` / `BLANK` | releases land as `chore: release vX.Y.Z`, not `Merge pull request #N` |
| `delete_branch_on_merge` | `true` | the remote branch is deleted on merge |
| `default_branch` | `develop` | PRs target `develop` without `--base` |

On automatic deletion: GitHub never deletes the default branch or a protected branch.
That is why `develop` is safe as the head of the release PR. `main` must **never** be
the head of a PR (on a private Free repository it has no protection and would be
deleted): to bring a hotfix back into `develop`, cut a `chore/sync-*` branch from
`main`.

`audit-setup.sh` reads every one of these values back at the end (check 10).

## Rulesets

- `main.json`: PRs only, required `Commit messages` check, conversations resolved, no
  force push or deletion, **merge commit only**.
- `develop.json`: PRs only, required check, no force push or deletion, squash and merge
  commit (the merge commit is needed to bring a hotfix in from `chore/sync-*`).
- `tags.json`: `v*` tags cannot be deleted or moved. No bypass: a published version is
  immutable; if it is wrong, publish another one.

The required check carries `"integration_id": 15368`, the GitHub Actions app. Without
it any status named `Commit messages` would count, and anyone with write access could
post a green one through the API without the CI running. If the project adds a
required check from another app (not Actions), that one carries its own app's
`integration_id`, or none.

The empty bodies (`BLANK`) are on purpose: the PR description follows the template
(checkboxes, HTML comments, `Closes #`) and would be noise in the commit. The context
stays on the PR, linked by the `(#N)` GitHub appends to the squash title. That is why
a breaking change is marked with `!` in the PR title: a `BREAKING CHANGE:` footer in a
working-branch commit is lost in the squash.

The branch rulesets use `actor_id: 5` (admin) with `bypass_mode: pull_request`: nobody
pushes directly to `main` or `develop`, but an admin **can** merge a PR bypassing the
rules (GitHub shows them a "bypass rules" checkbox). It is the escape hatch for a
broken CI, and `CONTRIBUTING.md` says so. `merge-pr.sh` does **not** use `--admin`: if
a ruleset requires approvals, the PR waits for the review.

`main` has no `required_linear_history`: it forbids merge commits, which is exactly the
release method.

`audit-setup.sh` reads back that the three rulesets are active (check 11) and that the
pull request rule and the `Commit messages` check from GitHub Actions are in effect on
`main` and `develop` (check 12).

## Why squash into `develop` and merge commit into `main`

- **Squash into `develop`:** the working branch is short-lived and deleted; squashing
  it splits no history and leaves one commit per change. That is why the CI validates
  **the PR title** on these PRs, and not the intermediate commits: it is the only
  thing that survives.
- **Merge commit into `main`:** `develop` and `main` live forever. A squash between them
  creates a commit on `main` that does not exist on `develop`, the histories diverge
  and every release lists everything again. With a merge commit, `develop`'s commits
  become ancestors of `main`. Since they land as they are, on these PRs the CI
  validates **every commit** as well as the title.

## `PROTECTION_STATUS` text

`CONTRIBUTING.md` and `docs/git-cheatsheet.md` have a `PROTECTION_STATUS` line. Replace
it in both with the text matching what `configure-github.sh` **really applied** (not
what was intended):

**Rulesets applied:**

```markdown
GitHub enforces the rules below through repository rulesets.
```

**Rulesets unavailable (private without a paid plan):**

```markdown
> [!NOTE]
> This repository is private on a plan without rulesets, so GitHub does **not**
> enforce the branch rules below: they are followed by convention, and the CI check
> reports but does not block. GitHub does enforce, on every plan: squash and merge
> commit as the only merge methods, the PR title as the commit message, and the
> deletion of merged branches.
```
