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
5. **Repository visibility — ALWAYS ASK. Never assume, never default.**
   This is the one decision in the whole setup that the user must make out loud, every
   single run. Ask it with `AskUserQuestion` *before* the repo is created, and wait for
   the answer. Do not infer it from the project's contents, from a sensible-sounding
   default, from what the last run chose, or from the fact that `gh repo create` has to
   be told something.

   **If the repo does not exist yet** (the usual case on a fresh project), ask which
   visibility to create it with, and show what each one actually costs:

   | | Private | Public |
   |---|---|---|
   | Branch protection rulesets (step 7) | needs GitHub Pro — returns `403` on Free | free |
   | GitHub secret scanning and push protection | not available on Free | free |
   | Code readable by anyone | no | yes |

   Present both and do not steer. Neither answer is wrong: a project holding personal
   data has a good reason to stay private and go without rulesets, and a repo with
   nothing sensitive in it has a good reason to take the free protection. State the
   trade-off, let the user choose.

   **If the repo already exists**, read what it is now with
   `gh repo view --json visibility --jq .visibility`, tell the user, and ask whether to
   keep it or change it. Never change it silently in either direction.

   Use the answer verbatim in `gh repo create` in step 1.

   **Only turn a repo public on an explicit yes, and say what that means first:** it
   publishes every commit already in the repo, not just future ones, and going private
   again does not unpublish what was fetched or indexed in the meantime. The command is
   `gh repo edit --visibility public --accept-visibility-change-consequences`.

   **"Private, on a Free plan" is a complete and valid answer**, not a problem to solve:
   step 7 returns `403`, gets skipped, and the closing audit records the rulesets as a
   pending decision with its reason. Do not reopen the question at step 7, and do not
   treat it as a failure.

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
#
# `tr -d '\r'` on BOTH sides is load-bearing, not tidiness: these templates are
# stored CRLF and a project's own .gitignore is usually LF. Compared raw, every
# template pattern carries a trailing \r the project file lacks, so `grep -qxF`
# never matches and the entire baseline gets appended, duplicates included. The
# result still *works* — git strips the CR when it reads a pattern — which is what
# makes it easy to miss: the file just quietly grows a second copy of every
# entry the two files share.
BASE=$(mktemp) && tr -d '\r' < .gitignore > "$BASE"

{ echo ""; echo "# ===== added by setup-git-flow ====="; } >> .gitignore
tr -d '\r' < "<skill-path>/templates/.gitignore" | while IFS= read -r line; do
  [ -z "$line" ] && continue
  case "$line" in \#*) continue;; esac
  grep -qxF -- "$line" "$BASE" || echo "$line" >> .gitignore
done

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
# <visibility> is --private or --public, taken from the user's answer to
# prerequisite 5. There is no default here on purpose: if you have not asked yet,
# stop and ask now rather than picking one.
gh repo create <name> <visibility> --source=. --remote=origin
git push -u origin main
```

This is the point of no easy return, which is why prerequisite 5 asks first: on a Free
plan a **private** repo cannot have rulesets, so step 7 will return
`403 Upgrade to GitHub Pro` and the repo ends up with no branch protection, while a
**public** repo publishes the initial commit to anyone the moment it is pushed. Both are
legitimate choices and the user makes them — your job is to have asked before this line
runs, not to discover the consequence at step 7.

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

Only if the repo is public OR the user has a paid plan. If prerequisite 5 settled on a
private repo on a Free plan, skip this step: the `403` is expected, it is not a problem
to work around, and the visibility question is already answered — do not ask it again
here. Carry the skipped rulesets into the closing audit as pending, with the reason.

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

## Closing: audit first, then the summary in Spanish

Two things happen at the end, in this order. The audit comes first, because the summary
must report what the audit *found*, not what the steps were supposed to achieve.

### A. Completion audit — prove nothing is left half-done

**Do not write the summary from memory of the commands you ran.** Ask git and `gh` what
the real state is. A setup that *almost* finished is the worst possible outcome: it
reports success, and whatever was left dangling — a PR still open, a branch never
pushed, a commit that never left the machine — surfaces days later for someone who
trusted the report.

Run all of these and read every answer:

```bash
# 1. Working tree clean: nothing modified, staged or untracked
git status --porcelain

# 2. No local commit that never reached the remote, on ANY local branch.
#    Print the upstream too: `%(upstream:track)` alone is blank both for a branch
#    that is in sync AND for one with no upstream at all, so a branch that was
#    never pushed would read as clean. An empty `upstream=` is the tell.
git for-each-ref --format='%(refname:short) upstream=%(upstream:short) %(upstream:track)' refs/heads

# 3. Both long-lived branches exist on the remote
git ls-remote --heads origin main develop

# 4. develop and main in sync (0 = nothing waiting to be promoted)
git rev-list --count origin/main..origin/develop

# 5. No pull request left open by this setup
gh pr list --state open

# 6. The temporary setup branch is gone, locally and remotely
git branch --list 'chore/git-flow-setup'
git ls-remote --heads origin 'chore/git-flow-setup'

# 7. Every tag created locally has been pushed
git tag -l ; git ls-remote --tags origin
```

A clean result is: (1) empty — (2) every line has a non-empty `upstream=` and no
`[ahead N]` — (3) both refs listed — (4) exactly `0` — (5) empty — (6) both empty
— (7) every local tag also on the remote.

**If every check is clean**, say so in the summary as a verified result, not as an
assumption: *"comprobado: no queda ningún merge, push ni rama pendiente."*

**If anything is outstanding, do not report the setup as complete.** Name exactly what
is left in terms the user can act on, and **ask permission to finish it** — do not
silently stop, and do not press on unasked. For example:

> El PR #2 sigue abierto y `develop` tiene 1 commit sin promocionar a `main`.
> ¿Quieres que lo termine yo?

Wait for the answer. If the user says yes, finish it, then **re-run the audit** before
writing the summary — the second run is what you report.

One case is *expected* to be outstanding and is not a failure: the rulesets on a
private repo on a Free plan. That is a decision the user made at prerequisite 5, so
report it as pending **with its reason**, never as something that went wrong.

### B. The summary, in Spanish

**Write the final summary in Spanish**, always, whatever language this file or the
user's request was in — unless the user explicitly asks for another language. Keep
command names, branch names, file paths and check names in their original form; they
are identifiers, not prose.

Cover every point below. If one does not apply, say so rather than omitting it, so the
shape of the report is the same every run and nothing can quietly go missing:

- **Repositorio**: URL, y su visibilidad — diciendo que la eligió el usuario, no la
  skill.
- **Ramas**: `main` y `develop`, y que ambas existen en el remoto.
- **Qué llevó el commit inicial**: la lista de ficheros, no "los ficheros del
  proyecto".
- **Plantillas y ficheros creados**: `.github/`, `CONTRIBUTING.md`,
  `docs/git-cheatsheet.md`.
- **CI**: que se ejecutó, y qué reportó **cada** check por su nombre
  (`Lint & Type check`, `Python checks`, `Commit messages`). Verdes vacíos en un
  proyecto sin `pyproject.toml` ni `package.json` son lo esperado: dilo.
- **Rulesets**: aplicados, o pendientes con el motivo.
- **Seguridad**: qué quedó activo y qué no está disponible en ese plan.
- **gitleaks**: que se ejecutó y qué devolvió — o, si no estaba instalado, que el
  commit inicial fue **sin escanear**, dicho claramente.
- **Política de merge**: squash hacia `develop`, merge commit de `develop` a `main`.
- **Qué falló, se saltó o necesitó improvisación**: siempre presente. Si no hubo
  nada, decir que no hubo nada.
- **Resultado de la auditoría**: que no queda nada pendiente, o qué queda y qué has
  preguntado sobre ello.

## Customization options to consider

When invoking this skill, the user might want variations. Ask if unclear:
- **Single-dev mode** vs multi-dev: in single-dev, `required_approving_review_count: 0` (default). In team mode, set it to 1+.
- **Strict CI** vs permissive: the rulesets require `Lint & Type check`, `Python checks` and `Commit messages` by default. If the user wants permissive merges, drop the `required_status_checks` rule from the ruleset JSON before applying it. If you rename a job in `ci.yml`, update the matching `context` in both rulesets — the context is the job's `name`, not its id, and a context that never reports blocks every PR.
- **Issue templates language**: default is Spanish (since this template was authored for Spanish-speaking user). Translate to English or other if user prefers.
- **PR template detail level**: default is medium-detail. Some teams prefer minimal.

## Troubleshooting

- **"Upgrade to GitHub Pro"** when applying rulesets → the repo is private on a Free
  plan, which is exactly what prerequisite 5 warned about. Skip the step and record the
  rulesets as pending. Do **not** offer to flip the repo public to get past it: that
  decision was already made, and turning it public publishes every commit already
  pushed. Only revisit it if the user raises it.
- **PR merge fails after applying rulesets** → ensure `bypass_actors` has the admin entry, otherwise even the owner can't merge.
- **CI jobs are green but empty on first push** → expected; there is no `package.json`/`pyproject.toml` yet. The steps are guarded, but every job still runs and reports, so required status checks are satisfied.
- **PR stuck on "Expected — Waiting for status to be reported"** → a required context never ran. Almost always a job-level `if` (the job is skipped, so it reports nothing) or a job renamed without updating the ruleset context.
- **`Commit messages` fails with `Resource not accessible by integration`** → not a
  malformed commit message. `wagoid/commitlint-github-action` asks the API for the list
  of commits in the PR, and the default `GITHUB_TOKEN` is granted `contents` only, so
  the call is refused and the job dies *before* it lints anything. The job in `ci.yml`
  therefore carries an explicit grant:

  ```yaml
  permissions:
    contents: read
    pull-requests: read
  ```

  If you ever see this again, check that block survived, and check the repo's default
  at `gh api repos/$OWNER_REPO/actions/permissions/workflow` — an org or repo set to
  read-only workflow permissions is the usual cause.

  **Why the repo's own `lint-templates.yml` cannot catch this.** actionlint reads the
  workflow as a *document*: syntax, expression validity, runner labels, shellcheck over
  `run:` blocks. A job with no `permissions:` block is perfectly valid YAML and
  perfectly valid GitHub Actions — there is nothing malformed to report. What fails is
  **authorization at run time**, which depends on the token a particular repository
  hands the job, and that exists only once a real PR runs in a real repo. The template
  ships here but never executes here, so a whole class of defect — anything that only
  appears when the workflow actually runs — is invisible to the checks in this repo and
  surfaces in the first project the skill is applied to. Treat the first PR of a fresh
  setup as part of the test surface, and read what the checks actually report rather
  than trusting that green templates imply a green pipeline.
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
