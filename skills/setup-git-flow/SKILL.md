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
It is a defence in depth, not a prerequisite, and the hooks installed in step 7 will
scan every commit from then on. Tell the user it was skipped and how to get it
(`brew install gitleaks`, `winget install gitleaks`, or a release binary from
`github.com/gitleaks/gitleaks`). If `pre-commit` happens to be installed already, you
can borrow the skill's config without copying it yet:

```bash
pre-commit run gitleaks --all-files -c <skill-path>/templates/.pre-commit-config.yaml
```

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
rulesets, so step 8 will fail with `403 Upgrade to GitHub Pro` and the repo ends up
with no branch protection. Prerequisite 5 covers the trade-off — decide it now with the
user rather than discovering it at step 8, since changing visibility later means
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
- `.pre-commit-config.yaml` — language-agnostic hooks (gitleaks + hygiene). Copy as-is; the stack-specific blocks get appended later in step 11.
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
git add .github CONTRIBUTING.md .gitignore .pre-commit-config.yaml docs/
git commit -m "chore: set up Git Flow with PR templates, CI, and contribution guide"
git push -u origin chore/git-flow-setup
gh pr create --base develop --title "chore: set up Git Flow" --fill
gh pr merge --squash --admin --delete-branch
```

`docs/` and `.pre-commit-config.yaml` must both be in that `git add` — step 5 copies
`docs/git-cheatsheet.md` and the hook config, and without them they stay untracked and
never reach the repo. If the project has no
`docs/` folder and you placed the cheatsheet at the root, stage `git-cheatsheet.md`
instead.

Then sync develop to main. Note the merge method: PRs into `develop` are squashed,
but `develop → main` uses a **merge commit** — see the merge policy note in step 8.

```bash
git checkout develop && git pull
gh pr create --base main --head develop --title "chore: initial Git Flow setup" --fill
gh pr merge --merge --admin
```

### 7. Install the pre-commit hooks

Do this now, as part of the setup — not as a TODO. The base
`.pre-commit-config.yaml` copied in step 5 is language-agnostic, so there is nothing
to wait for: no `pyproject.toml`, no `package.json`, no code at all.

**Install `pre-commit` as a global tool, not a project dependency:**

```bash
uv tool install pre-commit      # preferred
# or: pipx install pre-commit
```

Then, in the repo:

```bash
pre-commit install                 # the pre-commit hook
pre-commit install --hook-type commit-msg   # only if a commit-msg hook is added later
```

#### `pre-commit install` succeeding proves nothing — verify with a real run

`pre-commit install` only writes `.git/hooks/pre-commit`. It does **not** build any
hook environment: that happens lazily, on the first run or the first commit. So it
reports success on a config whose hooks cannot actually be installed, and the failure
surfaces later, at the worst moment — see the troubleshooting entry on the gitleaks
environment for why that moment is expensive.

Always follow it with a real run, and read the exit code:

```bash
pre-commit run --all-files ; echo "exit=$?"
```

| exit | Meaning | What to do |
|---|---|---|
| `0` | every hook ran and passed | done — the hooks are live |
| `1` | hooks ran and **did their job**: something failed or was fixed in place | expected on a first run; re-stage and run again until `0` |
| `3` | pre-commit **could not build a hook environment** — the hooks never ran at all | do not report success; see below |

Exit `1` is normal on a first run: `trailing-whitespace` and `end-of-file-fixer` rewrite
files, and a run that changes files reports failure. Re-stage the fixes and run again;
the second run should be `0`.

Exit `3` is a different thing entirely, and the distinction is what matters here: the
hooks did not run, so nothing is being checked. The output names the repo it choked on,
under `[INFO] Installing environment for <repo>`, followed by a traceback rather than
hook results.

**If any environment fails to build, say so plainly and do not report the setup as
complete.** Report, in the final summary, that the hooks are installed but **not
functional**, name the hook whose environment failed, and give the user the fix from the
troubleshooting section. A step 7 reported as green when `run --all-files` exited `3` is
worse than one reported as failed: the user believes secrets are being scanned on every
commit when nothing is.

Only claim the hooks are live once `pre-commit run --all-files` has actually reached
exit `0`.

#### Why global and not a project dependency

In a Python project, adding `pre-commit` to the dev dependencies is a perfectly good
choice — `uv add --dev pre-commit` pins it in `uv.lock`, so every contributor resolves
the same version. That reproducibility is real, and worth having in a Python repo.

It just cannot be *this* step's default: the skill runs on repos that may have no
`pyproject.toml` and no `package.json`, so there is no manifest to add a dev dependency
to, and no `uv run` to invoke it through. A global tool works the same way everywhere.

So: install globally here, and if the project later turns out to be Python and the user
wants the lockfile pinning, add it as a dev dependency *as well* and drive it with
`uv run pre-commit` — see step 11.

### 8. Apply branch protection rulesets

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

### 9. Enable security features

```bash
gh api -X PATCH repos/$OWNER_REPO \
  -f 'security_and_analysis[secret_scanning][status]=enabled' \
  -f 'security_and_analysis[secret_scanning_push_protection][status]=enabled'

gh api -X PUT repos/$OWNER_REPO/vulnerability-alerts
gh api -X PUT repos/$OWNER_REPO/automated-security-fixes
```

### 10. Document the setup

If the project has a `CLAUDE.md` and/or `docs/progress.md`, update them with:
- Branching strategy summary (or reference to `CONTRIBUTING.md`).
- Note that branch protection is active on `main` and `develop`.
- Date of setup.

If no docs exist, just leave `CONTRIBUTING.md` as the source of truth.

### 11. Stack-specific hooks (append to the base config)

Steps 5 and 7 already installed the language-agnostic hooks. This step only adds the
blocks that depend on the stack, and it is the one step here that has to wait: ruff and
mypy need a `pyproject.toml`, commitlint needs a `package.json`.

> **Append to `.pre-commit-config.yaml` — never replace it.** Add entries under the
> existing `repos:` list and leave what is already there alone. Writing a fresh
> stack-specific file over it silently deletes the gitleaks hook, which is the one hook
> protecting against committed secrets. This is exactly the mistake the `.gitignore`
> handling in step 1 exists to prevent, in the same shape: the file already has content
> that the new content knows nothing about.

Check each `rev` before writing it — they are pinned tags, not floating refs:

```bash
pre-commit autoupdate    # resolves every repo in the file to its latest tag
```

#### Python projects: ruff + mypy

Once `pyproject.toml` exists, append:

```yaml
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

The ruff and mypy versions here must match the ones the CI `Python checks` job installs
via `uv sync`, otherwise hooks and CI will disagree — a commit passes locally and fails
in the PR, or the reverse.

`pre-commit` is already installed globally (step 7), so nothing more is needed to run
these. If you also want it pinned in `uv.lock` for reproducibility across contributors,
add it as a dev dependency **in addition** and drive it through `uv`:

```bash
uv add --dev pre-commit ruff mypy
uv run pre-commit install    # re-point the hook at the project's copy
```

Then use `uv run pre-commit ...` consistently, so the lockfile version is the one that
actually runs.

#### JS/TS projects: commitlint

CI already validates commit messages on PRs (the `Commit messages` job), so this only
moves that feedback earlier, to the moment of committing.

Preferred, since `pre-commit` is already installed and this needs no husky:

```yaml
  - repo: https://github.com/alessandrojcm/commitlint-pre-commit-hook
    rev: v9.26.0
    hooks:
      - id: commitlint
        stages: [commit-msg]
        additional_dependencies: ["@commitlint/config-conventional"]
```

That hook runs at the `commit-msg` stage, which needs its own install:

```bash
pre-commit install --hook-type commit-msg
```

Create `commitlint.config.cjs`:
```js
module.exports = { extends: ['@commitlint/config-conventional'] };
```

Use `husky` instead only if the project already relies on it:

```bash
pnpm add -D husky @commitlint/cli @commitlint/config-conventional
pnpm exec husky init
echo "pnpm exec commitlint --edit \$1" > .husky/commit-msg
```

Do not run both — two `commit-msg` hooks validating the same message is just noise.

After appending anything, re-run everything once:

```bash
pre-commit run --all-files
```

## Final summary to give the user

After completing, report:
- ✅ Branches created: `main`, `develop`
- ✅ Branch protection rulesets active (or pending if private+free)
- ✅ Security features enabled (secret scanning, push protection, dependabot)
- ✅ Templates and CI workflow in place (`Lint & Type check`, `Python checks`, `Commit messages` required on both branches)
- ✅ `CONTRIBUTING.md` documents the flow, including the merge policy (squash into `develop`, merge commit for `develop → main`)
- ✅ Pre-commit hooks installed **and verified** (gitleaks + hygiene) — only claim this if `pre-commit run --all-files` reached exit `0`. If it exited `3`, report instead: ⚠️ hooks installed but NOT functional, name the hook whose environment failed, and note that the repo will reject commits until it is fixed (see troubleshooting)
- ✅ Staged content scanned with gitleaks before the initial commit (or: skipped, and say why)
- 📝 Future TODO: append the stack-specific hooks — ruff + mypy once `pyproject.toml` exists, commitlint once `package.json` exists. **Append** to `.pre-commit-config.yaml`, never overwrite it

## Customization options to consider

When invoking this skill, the user might want variations. Ask if unclear:
- **Single-dev mode** vs multi-dev: in single-dev, `required_approving_review_count: 0` (default). In team mode, set it to 1+.
- **Strict CI** vs permissive: the rulesets require `Lint & Type check`, `Python checks` and `Commit messages` by default. If the user wants permissive merges, drop the `required_status_checks` rule from the ruleset JSON before applying it. If you rename a job in `ci.yml`, update the matching `context` in both rulesets — the context is the job's `name`, not its id, and a context that never reports blocks every PR.
- **Issue templates language**: default is Spanish (since this template was authored for Spanish-speaking user). Translate to English or other if user prefers.
- **PR template detail level**: default is medium-detail. Some teams prefer minimal.
- **Hook strictness**: the base `.pre-commit-config.yaml` fixes files in place
  (`trailing-whitespace`, `end-of-file-fixer`). If the user finds that intrusive on an
  existing codebase, drop those two and keep gitleaks plus the `check-*` hooks, which
  only report. Do not drop gitleaks.

## Troubleshooting

- **"Upgrade to GitHub Pro"** when applying rulesets → repo is private + Free. Either make public or skip.
- **PR merge fails after applying rulesets** → ensure `bypass_actors` has the admin entry, otherwise even the owner can't merge.
- **CI jobs are green but empty on first push** → expected; there is no `package.json`/`pyproject.toml` yet. The steps are guarded, but every job still runs and reports, so required status checks are satisfied.
- **PR stuck on "Expected — Waiting for status to be reported"** → a required context never ran. Almost always a job-level `if` (the job is skipped, so it reports nothing) or a job renamed without updating the ruleset context.
- **`gh: command not found`** → after install, may need new shell session or explicit PATH: `export PATH="/c/Program Files/GitHub CLI:$PATH"`.
- **First `pre-commit run --all-files` "fails" with files modified** → expected, not an error. `trailing-whitespace` and `end-of-file-fixer` fix in place; the run reports failure because files changed. Re-stage and run again — it should be clean.
- **gitleaks hook fails to install its environment → THE REPO STOPS ACCEPTING COMMITS.**
  This is the one failure here with a consequence worse than its symptom, so it is worth
  spelling out.

  *Symptom:* during `[INFO] Installing environment for https://github.com/gitleaks/gitleaks`
  you get a traceback instead of hook results — typically a network/TLS error such as
  `CERTIFICATE_VERIFY_FAILED`, or a missing-Go error. The default `gitleaks` id has
  `language: golang`: it **builds gitleaks from source** and needs a Go toolchain that
  pre-commit can fetch or find. That is what fails on Windows, and it is not a problem
  with the config file.

  *Consequence:* once `.git/hooks/pre-commit` exists, **every `git commit` in the repo
  runs it, and a hook whose environment cannot be built aborts the commit.** So the
  failure is not confined to `pre-commit run` — the repo accepts no commits at all until
  it is fixed or bypassed. It surfaces as a stack trace on an ordinary commit, which
  reads like something unrelated broke, and it is easy to assume the commit succeeded
  when it did not (check `git log` before reaching for `git reset`).

  *Two ways out, in order of preference:*

  1. **Install the gitleaks binary and use the `gitleaks-system` hook** — the real fix,
     keeps secret scanning working. Install it (`brew install gitleaks`,
     `winget install gitleaks`, or a release binary from
     `github.com/gitleaks/gitleaks/releases`), confirm with `gitleaks version`, then in
     `.pre-commit-config.yaml` change `- id: gitleaks` to `- id: gitleaks-system`, which
     calls the installed binary and builds nothing. Re-run
     `pre-commit run --all-files` to confirm exit `0`. (`gitleaks-docker` is the same
     idea via a container, if Docker is available.)
  2. **Disable the hook temporarily** — unblocks committing, at the cost of the
     protection. Either comment out the gitleaks `repos:` entry, or run
     `pre-commit uninstall` to remove the hook entirely. Per-commit
     `git commit --no-verify` also gets through, but it skips *every* hook and is easy to
     make a habit of. Whichever you pick, say clearly that secret scanning is off and
     leave it as a TODO — this is the temporary option, not the answer.

  Do not report the setup as complete while this is unresolved; see step 7.
- **`pre-commit` not found after `uv tool install`** → the tool dir is not on PATH yet; `uv tool update-shell` and open a new shell.
- **commitlint hook never runs** → it lives at the `commit-msg` stage, which is a separate install: `pre-commit install --hook-type commit-msg`. `pre-commit install` alone only wires the `pre-commit` stage.
