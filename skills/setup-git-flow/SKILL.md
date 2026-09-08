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

Before staging, sort out `.gitignore` — see the note below on why this one template
cannot wait.

**If the project has no `.gitignore`:** copy `templates/.gitignore`.

**If it already has one: MERGE, never overwrite.** An existing `.gitignore` is often
the only thing keeping personal data out of the repo — local datasets, SQLite
databases, audio recordings, model weights, scraped content. Overwriting it with the
skill's baseline silently re-exposes all of it in the very first commit, which is
pushed straight to a fresh remote. Keep the project's file as the base and append only
the skill's patterns that are missing:

```bash
# The base copy goes OUTSIDE the repo — a .gitignore.bak left in the tree gets
# picked up by the `git add -A` below and committed.
BASE=$(mktemp) && cp .gitignore "$BASE"

{ echo ""; echo "# ===== added by setup-git-flow ====="; } >> .gitignore
while IFS= read -r line; do
  [ -z "$line" ] && continue
  case "$line" in \#*) continue;; esac
  grep -qxF -- "$line" "$BASE" || echo "$line" >> .gitignore
done < "<skill-path>/templates/.gitignore"   # quoted: `< <` would read as process substitution

rm -f "$BASE"
```

This never rewrites or reorders an existing line, so every project entry survives.
Two caveats: if **either** file uses negation patterns (`!foo`), order decides the
outcome and you must merge by hand instead; and review the result for near-duplicates
(the baseline has `Thumbs.db`, a project may already have the broader `*.db`) — they
are harmless, just noise.

**Verify before committing.** Ask git directly, rather than reading the file and
assuming — `git check-ignore` is the authority on what is actually excluded:

```bash
# Every path here must print as ignored. Use the project's real sensitive paths
# plus the secret patterns, e.g.:
git check-ignore -v .env private.pem id_rsa datos/x.db recording.wav model.gguf

# And the reverse: source that MUST stay trackable must print nothing.
git check-ignore -v src/app.py README.md
```

Then stage — but do not commit yet:

```bash
git add -A
git status            # ALWAYS review this — see the warning below
```

#### Scan the staged content with gitleaks, before the commit

`.gitignore` and gitleaks protect against the same accident from two different angles,
and neither one covers the other:

| | Matches on | Catches | Misses |
|---|---|---|---|
| `.gitignore` | **file name / path** | `.env`, `*.pem`, `datos/`, `id_rsa` | a key written *inside* `config.py` |
| gitleaks | **file content** | `AWS_SECRET = "AKIA…"` on line 40 of a tracked source file | nothing about names — it reads what is there |

No `.gitignore` pattern will ever stop an API key hardcoded in `config.py`,
`settings.py` or a notebook, because the filename is entirely legitimate. And this
commit is pushed to a fresh remote immediately, so there is no later gate to catch it:

```bash
# Scans exactly what `git add -A` staged
gitleaks git --staged --redact --verbose
```

`--redact` keeps the secret itself out of the terminal and any logs. If `gitleaks git`
is unavailable, `gitleaks dir . --redact --verbose` scans the working tree instead
(broader: it also reads files `.gitignore` excludes).

**If gitleaks is not installed: say so and carry on — never abort the setup over it.**
It is a defence in depth, not a prerequisite. But say it out loud, in the final summary
as well as here: the initial commit went in **without a content scan**, and it is pushed
to the remote straight away, so nothing else will catch a key hardcoded in a tracked
file. Tell the user how to get it — see the troubleshooting entry on gitleaks not being
installed — and suggest they scan and amend before pushing if the project has any
history of credentials in source.

**If gitleaks runs and reports findings, that is different: stop.** Do not commit. A
finding here means the secret would be published by the next command. Show the user
what was found (redacted), let them remove it from the file and rotate the credential
if it was ever real, then re-scan. "Not installed" is a warning; "found something" is a
full stop.

Only once the scan is clean (or explicitly skipped) do you commit:

```bash
git commit -m "chore: initial commit"
```

`git status` after `git add -A` is the last checkpoint: it lists exactly what the
initial commit will publish. If anything sensitive appears, or anything expected is
missing, fix `.gitignore` and re-check before committing — not after.

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

`git add -A` stages everything not ignored. With no `.gitignore`, or with one that lost
its entries to an overwrite, that can mean `.env`, `*.pem`, private keys, local
databases, datasets, recordings or model weights — and the initial commit is pushed to a
fresh remote immediately, so a secret committed here is a secret published. GitHub push
protection only catches recognisable token formats: it will not stop a `.env`, a SQLite
file of personal data, or a `.wav`.

This is why `.gitignore` is settled **before** the initial commit and rides along in
it, even though every other template waits for its own PR (see step 6): it is the only
one that has to be in place before the first `git add -A` to do its job. And it is why
the merge above is additive — the project's own entries are protecting data the
baseline knows nothing about, so losing them is as bad as never having the baseline.

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
- `.gitignore` — **already handled in step 1**, which copies or merges it before the initial commit. Nothing to do here; do not re-copy it over the merged file, that would drop the project's own entries.
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

## Final summary to give the user

After completing, report:
- ✅ Branches created: `main`, `develop`
- ✅ Branch protection rulesets active (or pending if private+free)
- ✅ Security features enabled (secret scanning, push protection, dependabot)
- ✅ Templates and CI workflow in place (`Lint & Type check`, `Python checks`, `Commit messages` required on both branches)
- ✅ `CONTRIBUTING.md` documents the flow, including the merge policy (squash into `develop`, merge commit for `develop → main`)
- ✅ Staged content scanned with gitleaks before the initial commit — or, if gitleaks was not installed: ⚠️ say plainly that the initial commit went in **unscanned**, and point at the troubleshooting entry for installing it

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
- **gitleaks not installed** → the initial commit in step 1 goes in **without a content
  scan**, and `.gitignore` does not cover the gap: no filename pattern stops an API key
  hardcoded inside a legitimately-named `config.py`. This never aborts the setup, but it
  must be said out loud rather than passed over.

  Install it as a release binary — it is a single static executable, no toolchain and no
  build step:

  ```bash
  brew install gitleaks        # macOS / Linuxbrew
  winget install gitleaks      # Windows
  # or download a binary from github.com/gitleaks/gitleaks/releases and put it on PATH
  ```

  Confirm with `gitleaks version`, then scan retroactively:

  ```bash
  gitleaks git --redact --verbose    # the whole history, not just what is staged
  ```

  If that turns up anything already committed, rotating the credential is the fix —
  rewriting history does not un-publish what was pushed.
