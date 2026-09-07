---
name: setup-git-flow
description: Set up a complete Git Flow lite configuration in a new project. Use when the user asks to "set up Git", "configure Git Flow", "replicate Git config", "initialize repo with Git Flow", "set up branch protection", or starts a new project that needs branching strategy + PR templates + CI + branch protection rules. Creates main/develop branches with rulesets, PR/issue templates, CODEOWNERS, GitHub Actions CI workflow, and CONTRIBUTING.md following Conventional Commits.
---

# Setup Git Flow Skill

Sets up a complete Git Flow lite configuration: `main` + `develop` branches with protection, PR/issue templates, CI workflow, CODEOWNERS, and contribution guide.

## When to invoke

- User says "set up Git Flow", "configure git for this project", "initialize repo properly", "replicate the Git setup", or similar.
- Starting a new project where the user wants professional branching from day 1.
- User wants to add branch protection rules and PR templates to an existing repo.

## Prerequisites checks

Before doing anything, verify:

1. **`git` available:** `git --version`
2. **`gh` (GitHub CLI) available:** `gh --version` and `gh auth status`
   - If `gh` is missing, instruct user to install: `winget install --id GitHub.cli` (Windows), `brew install gh` (macOS), or download from https://cli.github.com/
   - If not authenticated: tell user to run `gh auth login` themselves (interactive, opens browser).
3. **Inside a git repo:** `git rev-parse --is-inside-work-tree`. If not, ask whether to `git init` first.
4. **Has commits and a GitHub remote:** `git rev-parse --verify HEAD` and `git remote -v`.
   Either may be missing in a brand-new project — step 1 handles both. Do not skip it:
   the rest of the steps assume `main` exists and has an upstream.
5. **Repo visibility for branch protection:** `gh repo view --json visibility`. Branch protection rulesets require either:
   - Public repo (free), or
   - GitHub Pro/Team/Enterprise (private repo).
   - If repo is private and user is on Free plan, **ask the user** before making it public:
     - Explain implications (code visible, but secret scanning + push protection get enabled).
     - If user agrees: `gh repo edit --visibility public --accept-visibility-change-consequences`.
     - If user declines: skip branch protection step (continue with everything else) and document in `progress.md` that this is pending.

## Steps

### 1. Bootstrap: make sure `main` exists, has a commit, and has an upstream

**Do this before anything else.** Every later step assumes `main` exists with an
upstream, and the commands in them (`git checkout main`, `git pull`, `gh repo view`)
all fail on a freshly initialised repo: with no commits there is no `main` to check
out, no upstream to pull from, and possibly no remote to query.

Check what is actually missing:

```bash
git rev-parse --is-inside-work-tree 2>/dev/null   # is it a repo?
git rev-parse --verify HEAD 2>/dev/null           # does it have commits?
git remote get-url origin 2>/dev/null             # does it have a remote?
```

**If the repo has no commits**, make the initial commit on `main` with the project
content that already exists:

```bash
git init -b main                 # only if not a repo yet
git symbolic-ref HEAD refs/heads/main   # if init named the branch master
```

Before staging, **copy `templates/.gitignore`** if the project has no `.gitignore`
(see the note below on why this one template cannot wait), then:

```bash
git status            # ALWAYS review this first — see the warning below
git add -A
git commit -m "chore: initial commit"
```

**If the repo has no remote**, create it and push `main`:

```bash
gh repo create <name> --private --source=. --remote=origin
git push -u origin main
```

Mind the visibility you pick here: on a Free plan a **private** repo cannot have
rulesets, so step 7 will fail with `403 Upgrade to GitHub Pro` and the repo ends up
with no branch protection. Prerequisite 5 covers the trade-off — decide it now with the
user rather than discovering it at step 7, since changing visibility later means
`gh repo edit --visibility public --accept-visibility-change-consequences`.

If the remote exists but `main` has no upstream: `git push -u origin main`.

#### ⚠️ Review `git status` before `git add -A`

`git add -A` stages everything not ignored. In a project with no `.gitignore` yet that
can mean `.env`, `*.pem`, private keys, `node_modules/`, build output or local
databases — and the initial commit is pushed to a fresh remote immediately, so a
secret committed here is a secret published. GitHub push protection only catches
recognisable token formats, not arbitrary `.env` contents.

This is why `templates/.gitignore` is copied **before** the initial commit and rides
along in it, even though every other template waits for its own PR (see step 6): it is
the only one that has to exist before the first `git add -A` to do its job. If
`git status` shows anything that should not be tracked, extend `.gitignore` and
re-check before committing.

### 2. Determine the GitHub owner/repo

```bash
gh repo view --json nameWithOwner --jq .nameWithOwner
```

Save as `OWNER_REPO` for later use in API calls.

### 3. Determine the user's GitHub username

```bash
gh api user --jq .login
```

Save as `GH_USERNAME`. Used in CODEOWNERS.

### 4. Create `develop` branch

Step 1 guarantees `main` exists with a commit. If `develop` doesn't exist:

```bash
git checkout main
# Only pull if main tracks an upstream — in a repo bootstrapped in step 1 the
# first push already set it, but `git pull` with no upstream fails outright.
git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1 && git pull
git checkout -b develop
git push -u origin develop
```

### 5. Copy templates

Copy the contents of this skill's `templates/` directory into the project root, preserving the directory structure. The templates include:

- `.github/PULL_REQUEST_TEMPLATE.md`
- `.github/ISSUE_TEMPLATE/bug_report.md`
- `.github/ISSUE_TEMPLATE/feature_request.md`
- `.github/ISSUE_TEMPLATE/config.yml` — **must replace `OWNER/REPO` placeholder with actual repo path**
- `.github/CODEOWNERS` — **must replace `@OWNER` placeholder with `@$GH_USERNAME`**
- `.github/workflows/ci.yml`
- `CONTRIBUTING.md` — **must replace `OWNER/REPO` placeholder if any references**
- `.gitignore` (only add if no `.gitignore` exists, or merge with existing — see `templates/.gitignore` for the secrets-hardened baseline)
- `docs/git-cheatsheet.md` — practical day-to-day reference for humans and AIs. Place it under `docs/` if the project has that folder, otherwise at the root. `CONTRIBUTING.md` already links to it at `docs/git-cheatsheet.md` — if you put it elsewhere, fix those two links. Also reference it from `CLAUDE.md` (if it exists).

### 6. Commit and push templates via PR (do NOT push to main directly)

**Project content and skill templates are two separate commits, in this order:**

| What | Where it lands | When |
|------|----------------|------|
| The project's own code and files | initial commit on `main` | step 1 |
| This skill's templates (`.github/`, `CONTRIBUTING.md`, `docs/`) | `chore/git-flow-setup` → PR to `develop` | this step |

Keeping them separate is what makes step 1 mandatory rather than optional. This step
stages named paths only, never `git add -A`, so in a project that already has code, any
file not committed in step 1 is simply left untracked — and because this step ends in
`gh pr merge --squash --admin --delete-branch`, nothing ever surfaces that omission. The
setup reports success, the PR is green, and the project's actual source is sitting
uncommitted in the working tree.

So: commit the project's content in step 1, then the templates here. Before opening this
PR, run `git status` once more — anything unexpected still untracked means step 1 was
skipped or incomplete.

```bash
git checkout -b chore/git-flow-setup
git add .github CONTRIBUTING.md .gitignore docs/
git commit -m "chore: set up Git Flow with PR templates, CI, and contribution guide"
git push -u origin chore/git-flow-setup
gh pr create --base develop --title "chore: set up Git Flow" --fill
gh pr merge --squash --admin --delete-branch
```

`docs/` must be in that `git add` — step 5 copies `docs/git-cheatsheet.md`, and without
it the cheatsheet stays untracked and never reaches the repo. If the project has no
`docs/` folder and you placed the cheatsheet at the root, stage `git-cheatsheet.md`
instead.

Then sync develop to main. Note the merge method: PRs into `develop` are squashed,
but `develop → main` uses a **merge commit** — see the merge policy note in step 7.

```bash
git checkout develop && git pull
gh pr create --base main --head develop --title "chore: initial Git Flow setup" --fill
gh pr merge --merge --admin
```

### 7. Apply branch protection rulesets

Only if repo is public OR user has paid plan.

The `rulesets/` directory in this skill contains JSON files for `main` and `develop`. Apply them:

```bash
# For main (squash + merge commit allowed, conversation resolution required)
gh api -X POST repos/$OWNER_REPO/rulesets --input <skill-path>/rulesets/main.json

# For develop (PR required, no force push, no deletion)
gh api -X POST repos/$OWNER_REPO/rulesets --input <skill-path>/rulesets/develop.json
```

Note: The rulesets use `actor_id: 5` (admin role) with `bypass_mode: pull_request` — meaning admins must still go through PRs but can self-merge.

**Merge policy (both rulesets allow squash and merge commits, so the rule is a
convention, not an enforced one — `CONTRIBUTING.md` is the source of truth):**

| PR | Method |
|----|--------|
| `feat/*`, `fix/*`, `chore/*`, `docs/*` → `develop` | squash (`gh pr merge --squash`) |
| `develop` → `main` (release) | merge commit (`gh pr merge --merge`) |

`main` deliberately has **no** `required_linear_history` rule: that rule forbids merge
commits, so keeping it while allowing the merge method would be contradictory — GitHub
would show the button and then reject the merge. Releases go in as merge commits so
`develop`'s commits become ancestors of `main`; squashing `develop → main` splits the
two histories and makes every later release PR re-list everything before it.

### 8. Enable security features

```bash
gh api -X PATCH repos/$OWNER_REPO \
  -f 'security_and_analysis[secret_scanning][status]=enabled' \
  -f 'security_and_analysis[secret_scanning_push_protection][status]=enabled'

gh api -X PUT repos/$OWNER_REPO/vulnerability-alerts
gh api -X PUT repos/$OWNER_REPO/automated-security-fixes
```

### 9. Document the setup

If the project has a `CLAUDE.md` and/or `docs/progress.md`, update them with:
- Branching strategy summary (or reference to `CONTRIBUTING.md`).
- Note that branch protection is active on `main` and `develop`.
- Date of setup.

If no docs exist, just leave `CONTRIBUTING.md` as the source of truth.

### 10. Local pre-commit hooks

CI already validates lint, types, tests and commit messages. Hooks just move that
feedback earlier. Pick the stack that matches the project:

#### Python projects (default): `pre-commit` with ruff + mypy

Wait until the project has a `pyproject.toml`, then:

```bash
uv add --dev pre-commit ruff mypy
uv run pre-commit install
```

Create `.pre-commit-config.yaml` at the project root:

```yaml
repos:
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.16.6
    hooks:
      - id: ruff-check
        args: [--fix]
      - id: ruff-format

  - repo: https://github.com/pre-commit/mirrors-mypy
    rev: v2.3.1
    hooks:
      - id: mypy
```

Check the current `rev` for each repo before writing the file (they are pinned tags,
not floating refs) — e.g. `gh api repos/astral-sh/ruff-pre-commit/releases/latest --jq .tag_name`.
Keep them fresh with `uv run pre-commit autoupdate`.

The ruff and mypy versions here must match the ones the CI `Python checks` job
installs via `uv sync`, otherwise hooks and CI will disagree.

Run against the whole codebase once after installing:

```bash
uv run pre-commit run --all-files
```

#### JS/TS projects: `husky` + `commitlint` (only once `package.json` exists)

```bash
pnpm add -D husky @commitlint/cli @commitlint/config-conventional
pnpm exec husky init
echo "pnpm exec commitlint --edit \$1" > .husky/commit-msg
```

And create `commitlint.config.cjs`:
```js
module.exports = { extends: ['@commitlint/config-conventional'] };
```

For a project with both, `pre-commit` can also run the commitlint hook via
`commit-msg`, so husky is only needed if the project already relies on it.

Document whichever is still pending as a TODO in `progress.md` if relevant.

## Final summary to give the user

After completing, report:
- ✅ Branches created: `main`, `develop`
- ✅ Branch protection rulesets active (or pending if private+free)
- ✅ Security features enabled (secret scanning, push protection, dependabot)
- ✅ Templates and CI workflow in place (`Lint & Type check`, `Python checks`, `Commit messages` required on both branches)
- ✅ `CONTRIBUTING.md` documents the flow, including the merge policy (squash into `develop`, merge commit for `develop → main`)
- 📝 Future TODO: install local hooks — `pre-commit` (ruff + mypy) once `pyproject.toml` exists, husky + commitlint once `package.json` exists

## Customization options to consider

When invoking this skill, the user might want variations. Ask if unclear:
- **Single-dev mode** vs multi-dev: in single-dev, `required_approving_review_count: 0` (default). In team mode, set it to 1+.
- **Strict CI** vs permissive: the rulesets require `Lint & Type check`, `Python checks` and `Commit messages` by default. If the user wants permissive merges, drop the `required_status_checks` rule from the ruleset JSON before applying it. If you rename a job in `ci.yml`, update the matching `context` in both rulesets — the context is the job's `name`, not its id, and a context that never reports blocks every PR.
- **Issue templates language**: default is Spanish (since this template was authored for Spanish-speaking user). Translate to English or other if user prefers.
- **PR template detail level**: default is medium-detail. Some teams prefer minimal.

## Troubleshooting

- **"Upgrade to GitHub Pro"** when applying rulesets → repo is private + Free. Either make public or skip.
- **PR merge fails after applying rulesets** → ensure `bypass_actors` has the admin entry, otherwise even the owner can't merge.
- **CI jobs are green but empty on first push** → expected; there is no `package.json`/`pyproject.toml` yet. The steps are guarded, but every job still runs and reports, so required status checks are satisfied.
- **PR stuck on "Expected — Waiting for status to be reported"** → a required context never ran. Almost always a job-level `if` (the job is skipped, so it reports nothing) or a job renamed without updating the ruleset context.
- **`gh: command not found`** → after install, may need new shell session or explicit PATH: `export PATH="/c/Program Files/GitHub CLI:$PATH"`.
