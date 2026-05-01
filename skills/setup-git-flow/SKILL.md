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
4. **Has a GitHub remote:** `git remote -v`. If not, ask user to either:
   - Create a repo via `gh repo create` (offer to do it).
   - Add remote manually: `git remote add origin <url>`.
5. **Repo visibility for branch protection:** `gh repo view --json visibility`. Branch protection rulesets require either:
   - Public repo (free), or
   - GitHub Pro/Team/Enterprise (private repo).
   - If repo is private and user is on Free plan, **ask the user** before making it public:
     - Explain implications (code visible, but secret scanning + push protection get enabled).
     - If user agrees: `gh repo edit --visibility public --accept-visibility-change-consequences`.
     - If user declines: skip branch protection step (continue with everything else) and document in `progress.md` that this is pending.

## Steps

### 1. Determine the GitHub owner/repo

```bash
gh repo view --json nameWithOwner --jq .nameWithOwner
```

Save as `OWNER_REPO` for later use in API calls.

### 2. Determine the user's GitHub username

```bash
gh api user --jq .login
```

Save as `GH_USERNAME`. Used in CODEOWNERS.

### 3. Create `develop` branch

If `develop` doesn't exist:

```bash
git checkout main
git pull
git checkout -b develop
git push -u origin develop
```

### 4. Copy templates

Copy the contents of this skill's `templates/` directory into the project root, preserving the directory structure. The templates include:

- `.github/PULL_REQUEST_TEMPLATE.md`
- `.github/ISSUE_TEMPLATE/bug_report.md`
- `.github/ISSUE_TEMPLATE/feature_request.md`
- `.github/ISSUE_TEMPLATE/config.yml` — **must replace `OWNER/REPO` placeholder with actual repo path**
- `.github/CODEOWNERS` — **must replace `@OWNER` placeholder with `@$GH_USERNAME`**
- `.github/workflows/ci.yml`
- `CONTRIBUTING.md` — **must replace `OWNER/REPO` placeholder if any references**
- `.gitignore` (only add if no `.gitignore` exists, or merge with existing — see `templates/.gitignore` for the secrets-hardened baseline)
- `docs/git-cheatsheet.md` — practical day-to-day reference for humans and AIs. Place it under `docs/` if the project has that folder, otherwise at the root. Reference it from `CLAUDE.md` (if exists) and from `CONTRIBUTING.md`.

### 5. Commit and push templates via PR (do NOT push to main directly)

```bash
git checkout -b chore/git-flow-setup
git add .github CONTRIBUTING.md .gitignore
git commit -m "chore: set up Git Flow with PR templates, CI, and contribution guide"
git push -u origin chore/git-flow-setup
gh pr create --base develop --title "chore: set up Git Flow" --fill
gh pr merge --squash --admin --delete-branch
```

Then sync develop to main:

```bash
git checkout develop && git pull
gh pr create --base main --head develop --title "chore: initial Git Flow setup" --fill
gh pr merge --squash --admin
```

### 6. Apply branch protection rulesets

Only if repo is public OR user has paid plan.

The `rulesets/` directory in this skill contains JSON files for `main` and `develop`. Apply them:

```bash
# For main (squash-only, conversation resolution required, linear history)
gh api -X POST repos/$OWNER_REPO/rulesets --input <skill-path>/rulesets/main.json

# For develop (PR required, no force push, no deletion)
gh api -X POST repos/$OWNER_REPO/rulesets --input <skill-path>/rulesets/develop.json
```

Note: The rulesets use `actor_id: 5` (admin role) with `bypass_mode: pull_request` — meaning admins must still go through PRs but can self-merge.

### 7. Enable security features

```bash
gh api -X PATCH repos/$OWNER_REPO \
  -f 'security_and_analysis[secret_scanning][status]=enabled' \
  -f 'security_and_analysis[secret_scanning_push_protection][status]=enabled'

gh api -X PUT repos/$OWNER_REPO/vulnerability-alerts
gh api -X PUT repos/$OWNER_REPO/automated-security-fixes
```

### 8. Document the setup

If the project has a `CLAUDE.md` and/or `docs/progress.md`, update them with:
- Branching strategy summary (or reference to `CONTRIBUTING.md`).
- Note that branch protection is active on `main` and `develop`.
- Date of setup.

If no docs exist, just leave `CONTRIBUTING.md` as the source of truth.

### 9. Future: commitlint + husky (post-package.json)

The CI workflow includes commitlint validation. For local pre-commit validation, **wait until the project has `package.json`**, then add:

```bash
pnpm add -D husky @commitlint/cli @commitlint/config-conventional
pnpm exec husky init
echo "pnpm exec commitlint --edit \$1" > .husky/commit-msg
```

And create `commitlint.config.cjs`:
```js
module.exports = { extends: ['@commitlint/config-conventional'] };
```

Document this as a TODO in `progress.md` if relevant.

## Final summary to give the user

After completing, report:
- ✅ Branches created: `main`, `develop`
- ✅ Branch protection rulesets active (or pending if private+free)
- ✅ Security features enabled (secret scanning, push protection, dependabot)
- ✅ Templates and CI workflow in place
- ✅ `CONTRIBUTING.md` documents the flow
- 📝 Future TODO: install husky + commitlint when `package.json` exists

## Customization options to consider

When invoking this skill, the user might want variations. Ask if unclear:
- **Single-dev mode** vs multi-dev: in single-dev, `required_approving_review_count: 0` (default). In team mode, set it to 1+.
- **Strict CI** vs permissive: strict means `Lint & Type check` is a required status check on PR merges (add to ruleset `required_status_checks`).
- **Issue templates language**: default is Spanish (since this template was authored for Spanish-speaking user). Translate to English or other if user prefers.
- **PR template detail level**: default is medium-detail. Some teams prefer minimal.

## Troubleshooting

- **"Upgrade to GitHub Pro"** when applying rulesets → repo is private + Free. Either make public or skip.
- **PR merge fails after applying rulesets** → ensure `bypass_actors` has the admin entry, otherwise even the owner can't merge.
- **CI workflow fails on first push** → it's expected; no `package.json` yet. The workflow has guards for this.
- **`gh: command not found`** → after install, may need new shell session or explicit PATH: `export PATH="/c/Program Files/GitHub CLI:$PATH"`.
