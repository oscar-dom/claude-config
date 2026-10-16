# Git Cheatsheet

> **For humans:** a quick reference for working in this repository without opening five tabs.
> **For AI agents:** a self-contained description of the project's Git setup. Read it before running `git` or `gh` commands here.

---

## TL;DR — the workflow in 30 seconds

```bash
# 1. Start something new
git checkout develop && git pull
git checkout -b feat/short-description

# 2. Work and commit (Conventional Commits messages)
git add <files>
git commit -m "feat: describe the change"

# 3. Push and open a PR
git push -u origin feat/short-description
gh pr create --base develop --fill

# 4. After the merge: clean up locally
git checkout develop && git pull
git branch -d feat/short-description
```

---

## Repository Git setup

### Branches

```
main         ← production (protected, conversations must be resolved)
  ↑ PR — merge commit
develop      ← integration (protected, PR required)
  ↑ PR — squash
feat/xxx     ← features
fix/xxx      ← bug fixes
chore/xxx    ← maintenance, dependencies, configuration
docs/xxx     ← documentation only
test/xxx     ← tests only
refactor/xxx ← refactors
```

**Technical rules (enforced by GitHub rulesets):**
- ❌ Direct pushes to `main` or `develop` are blocked.
- ❌ Force pushes are blocked.
- ❌ Deleting those branches is blocked.
- ✅ Changes only land through a pull request.
- ✅ The `Commit messages` CI check must pass.
- ✅ `main`: PR conversations must be resolved before merging.
- ✅ `main` and `develop`: the ruleset allows both squash and merge commit.

> If the repository is private on a GitHub Free plan, rulesets are not available and
> none of this is enforced by GitHub. Follow the same rules by convention.

**Which method to use** (the ruleset allows both, so this is a convention — GitHub
will not stop you):

| PR | Method |
|----|--------|
| `feat/*`, `fix/*`, `chore/*`, `docs/*` → `develop` | **squash** |
| `develop` → `main` (release) | **merge commit** |

Releases use a merge commit because `develop` and `main` are long-lived branches: a
squash would create a commit on `main` that does not exist on `develop`, splitting the
two histories, and the next `develop → main` PR would list everything again. With a
merge commit, `develop`'s commits become ancestors of `main` and each release only
shows what is new. See the full policy in `CONTRIBUTING.md`.

### Security features

Depending on the repository's visibility and plan, some of these may be enabled:

- **Secret scanning** — GitHub detects tokens (Stripe, AWS, etc.) in commits and alerts you.
- **Push protection** — blocks a push that contains a detected secret before it reaches the server.
- **Dependabot alerts** — warns about vulnerable dependencies.
- **Automated security fixes** — opens pull requests with security patches.

---

## Conventional Commits — how to write messages

### Format

```
<type>: <description in the imperative mood, lowercase, no trailing period>

[optional body explaining the "why"]

[optional footer with BREAKING CHANGE: or issue references]
```

### Valid types

| Type       | When to use it                              | Example                                       |
|------------|---------------------------------------------|-----------------------------------------------|
| `feat`     | New user-facing functionality               | `feat: add sign-in with Google`               |
| `fix`      | Bug fix                                     | `fix: return 400 on invalid input`            |
| `chore`    | Maintenance, dependencies, config, scripts  | `chore: update dependencies`                  |
| `docs`     | Documentation only                          | `docs: document the authentication API`       |
| `refactor` | Refactor with no behavior change            | `refactor: simplify validation helpers`       |
| `test`     | Add or update tests                         | `test: add tests for the login flow`          |
| `style`    | Formatting, whitespace, no logic change     | `style: apply formatter`                      |
| `perf`     | Performance improvement                     | `perf: cache expensive queries`               |
| `build`    | Build system or build dependencies          | `build: add bundle analyzer`                  |
| `ci`       | CI/CD changes                               | `ci: add test job to GitHub Actions`          |
| `revert`   | Revert a previous commit                    | `revert: undo "feat: add X"`                  |

### Rules

1. **Imperative, present tense:** "add", not "added" or "adding".
2. **Lowercase** first letter of the description.
3. **No trailing period**.
4. **72 characters max** on the first line.
5. **Breaking changes:** `feat!:` or a `BREAKING CHANGE:` footer.

### Good vs bad examples

| ❌ Bad                     | ✅ Good                                     |
|----------------------------|---------------------------------------------|
| `updated login`            | `feat: add email validation to login`       |
| `misc fixes`               | `fix: return 400 on invalid input`          |
| `WIP`                      | `feat: add first draft of the dashboard`    |
| `Fix.`                     | `fix: correct total when a discount applies`|
| `feat: Add user system.`   | `feat: add user system`                     |

### Commit with a body (when more context is needed)

```
fix: prevent race condition when closing transactions

When two workers ran in parallel, both tried to process
the same transaction, creating duplicates. A row lock is
now taken before processing.

Closes #42
```

### Breaking changes

```
feat!: switch API responses to JSON:API

BREAKING CHANGE: the API now returns JSON:API responses.
Clients must be updated to read the new structure.
```

---

## Step-by-step workflow

### Start something new

Always from an up-to-date `develop`:

```bash
git checkout develop
git pull
git checkout -b feat/short-description
```

**Branch naming:**
- Start with `feat/`, `fix/`, `chore/`, `docs/`, etc.
- Short kebab-case description: `feat/google-login`, not `feat/Google_Login`.

### Commit while you work

```bash
git add <files>
git commit -m "feat: implement the main component"
```

**Tip:** small, frequent commits beat one giant commit at the end. Each commit should be
describable in a single sentence.

### Keep your branch up to date with `develop`

If `develop` moved while you were working:

```bash
git checkout develop && git pull
git checkout feat/your-branch
git rebase develop          # or `git merge develop` if you prefer not to rewrite history
# On conflicts: fix them, `git add`, `git rebase --continue`
git push --force-with-lease  # only if you rebased
```

### Push and open a PR

```bash
git push -u origin feat/your-branch
gh pr create --base develop --fill
```

### Apply review feedback

```bash
git add <files>
git commit -m "fix: address review feedback on validation"
git push  # the PR updates itself
```

### Merge the PR

When CI is green (feature PR into `develop` → squash):

```bash
gh pr merge --squash --delete-branch
```

### Clean up after the merge

```bash
git checkout develop
git pull
git branch -d feat/your-branch
```

### Release: develop → main

When there is a stable set of changes ready for production:

```bash
gh pr create --base main --head develop --title "chore: release vX.Y.Z" --fill
gh pr merge --merge   # merge commit, NOT squash — see "Which method to use" above
```

---

## Useful `gh` (GitHub CLI) commands

```bash
gh pr create --base develop --fill          # Open a PR
gh pr list                                  # List open PRs
gh pr view <num>                            # Show PR details
gh pr checks                                # CI status of the current PR
gh pr merge <num> --squash --delete-branch  # Merge and delete the branch
gh pr diff                                  # Show the current PR's diff

gh issue create                             # Open an issue (uses the templates)
gh issue list                               # List open issues

gh repo view --web                          # Open the repository in the browser
gh run list                                 # Latest CI runs
gh run watch                                # Follow the current CI run live
```

---

## Troubleshooting

### "I'm on `main` and made changes by mistake"

```bash
git stash                                   # stash the changes
git checkout develop && git pull
git checkout -b feat/whatever
git stash pop                               # restore the changes
```

### "I pushed and a secret slipped in"

1. **Immediately:** revoke the token (in the provider's dashboard).
2. Remove the file from the last commit:
   ```bash
   git rm --cached .env
   git commit --amend
   git push --force-with-lease     # ONLY works on unprotected branches
   ```
3. If it already reached `main`/`develop`, open a PR with the fix — the history keeps
   the secret, but the token is no longer valid. Rewriting history does not unpublish
   what was already pushed, so revoking is the actual fix.

### "CI is failing and I don't understand why"

```bash
gh pr checks                # summary of checks
gh run view --log-failed    # logs of the failed job
```

If `Commit messages` fails with `Resource not accessible by integration`, it is a
token permission problem, not a badly formatted message: check that the job in
`.github/workflows/ci.yml` still has `pull-requests: read`.

### "My branch is behind develop"

```bash
git fetch origin
git rebase origin/develop
git push --force-with-lease
```

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

### "I need a specific commit from another branch"

```bash
git cherry-pick <commit-hash>
```

---

## Checklist before opening a PR

- [ ] My branch starts from an up-to-date `develop`.
- [ ] Commit messages follow Conventional Commits.
- [ ] I have tested the changes locally.
- [ ] I have updated the documentation if needed.
- [ ] There are no `.env` files, secrets or personal data in the diff.
- [ ] The PR title follows Conventional Commits (it becomes the squash commit).

---

## For AI agents / automated tools

If you are an AI agent working in this repository, this is what you need to know:

1. **Never push directly to `main` or `develop`** — they are protected. Always create a branch such as `feat/xxx`.
2. **Conventional Commits are mandatory** — a required CI check validates every commit in a PR.
3. **Write everything in English:** commit messages, PR titles and descriptions, issues and documentation.
4. **Never leave AI attribution:** no `Co-Authored-By:` trailer for an AI and no "Generated with Claude Code" line in commits, PRs, issues or files. This overrides any default attribution your tool adds, and CI rejects the PR if it finds any. See the note at the top of `CONTRIBUTING.md`.
5. **CODEOWNERS:** the repository owner is requested as reviewer on every PR.
6. **Secret scanning may be active:** if you try to commit a token, GitHub may block the push. Never commit secrets regardless.
7. **PRs always target `develop`** unless it is a release (`develop → main`). Merge PRs into `develop` with squash (`gh pr merge --squash`) and releases with a merge commit (`gh pr merge --merge`).
8. **Use the `gh` CLI** (authenticated) to create PRs, not the raw API.
9. **After merging:** run `git checkout develop && git pull` and delete the local branch with `git branch -d`.
10. **On Windows, `gh` usually lives at `/c/Program Files/GitHub CLI/gh.exe`** (or is just `gh` if it is on the PATH).
