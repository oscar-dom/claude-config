# claude-config

Personal Claude Code configuration — skills, templates, and reusable assets synced across devices.

## What's inside

```
claude-config/
├── skills/                 # Custom skills for Claude Code
│   └── setup-git-flow/    # Sets up Git Flow lite (main+develop+protections)
├── scripts/                # Repo tooling used by CI
├── tests/                  # Tests of the skills' scripts (run by CI)
├── .github/workflows/      # Validates templates and runs the tests
├── install.ps1             # Windows installer
└── install.sh              # macOS/Linux installer
```

## Setup on a new device

### 1. Prerequisites

- `git` installed
- [GitHub CLI](https://cli.github.com/) (`gh`) installed and authenticated (`gh auth login`)
- Claude Code installed

### 2. Clone and install

**Windows (PowerShell):**
```powershell
cd $HOME\Desktop\GitHub
git clone https://github.com/oscar-dom/claude-config.git
cd claude-config
.\install.ps1
```

**macOS/Linux:**
```bash
cd ~/Desktop/GitHub  # or wherever you keep repos
git clone https://github.com/oscar-dom/claude-config.git
cd claude-config
./install.sh
```

The installer copies `skills/*` into `~/.claude/skills/`. Re-run after pulling changes to sync.

## Daily workflow

### Adding/modifying a skill

```bash
# Edit files under skills/
git add .
git commit -m "feat: add skill X"
git push
```

### Pulling changes on another device

```bash
git pull
./install.ps1   # or ./install.sh
```

### Live-linking on your primary machine

The installer *copies*, so `~/.claude/skills/<name>` and `skills/<name>` drift apart
the moment you edit one and forget to re-run it. On the machine where you actually
author skills, replace the copy with a link instead — the copy disappears and so does
the drift:

```powershell
# Windows; junctions do not need admin rights
Remove-Item -Recurse -Force "$HOME\.claude\skills\setup-git-flow"
cmd /c mklink /J "$HOME\.claude\skills\setup-git-flow" "$HOME\Desktop\GitHub\claude-config\skills\setup-git-flow"
```

```bash
# macOS/Linux: remove the copy first, or ln would put the link inside it
rm -rf ~/.claude/skills/setup-git-flow
ln -s ~/Desktop/GitHub/claude-config/skills/setup-git-flow ~/.claude/skills/setup-git-flow
```

Both installers detect a linked destination and skip it, so re-running them is safe.
Keep using the installer on every *other* machine.

## CI

`.github/workflows/lint-templates.yml` runs on every pull request and push to `main`
and `develop`. The skills ship files this repository never runs itself (workflow
templates, scripts that talk to GitHub), so without it they would only be tested
once a skill had already copied them into a real project. This is the repository's
own CI: the projects a skill sets up get their own, much smaller one.

| Job | What it catches |
|---|---|
| **Lint** | syntax errors in the workflow templates (actionlint), `uses:` refs that do not exist (`scripts/check-action-refs.sh`), and the commit convention or the required check's name drifting between `setup-git-flow/scripts/lib.sh`, the CI template and the rulesets (`scripts/check-convention-sync.sh`) |
| **Script tests** (`tests/test-setup-git-flow.sh`), on Ubuntu and Windows (Git Bash) | regressions in `setup-git-flow`'s scripts; see below |

macOS runs the same tests every Monday and on demand (*Actions → Lint templates →
Run workflow*): its hosted runners can queue for a long time, and a queued job would
otherwise hold every pull request.

Run the tests locally with `bash tests/test-setup-git-flow.sh`.

## Available skills

### `setup-git-flow`

Sets up a professional Git Flow lite repository in a new or existing project, without
assuming any stack, and leaves an AI agent able to run the daily git work for you
with one confirmation per operation. Everything it puts in the repository is in
English; Claude talks to you in your language.

**Trigger:** ask Claude to *"set up Git Flow"*, *"configure git for this project"* or
*"monta Git Flow"*.

#### What the setup does

1. **Asks before deciding anything:** the repository's visibility (showing what each
   option costs on your GitHub plan; there is no default), who will manage it (Claude
   Code, another AI or people only) and, only with an AI, whether to forbid AI
   attribution (`Co-Authored-By:` trailers, "Generated with" lines).
2. **Creates the branches:** `main` and `develop` (the default). If the repository
   already exists with `master`, it asks whether to rename it first.
3. **Configures GitHub:** squash into `develop`, merge commit into `main`, the PR title
   as the commit message, no rebase, branches deleted on merge; rulesets so nothing
   reaches `main` or `develop` without a PR and a green CI check (bound to GitHub
   Actions), and `v*` tags that cannot be moved or deleted; Dependabot and secret
   scanning where the plan allows.
4. **Adds the templates:** a stack-agnostic CI that validates the PR title as a
   Conventional Commit (every commit on PRs into `main`) and that only `develop` and
   `hotfix/*` reach `main`; PR and issue templates, CODEOWNERS, `CONTRIBUTING.md`,
   `docs/git-cheatsheet.md`, `.gitattributes`, a minimal `.editorconfig`, Dependabot
   for GitHub Actions only, and `CLAUDE.md` or `AGENTS.md` if an AI manages the repo.
5. **Audits the result:** reads back from GitHub what it applied and refuses to report
   success while anything is pending.

On a private repository on the Free plan, GitHub does not offer rulesets or secret
scanning: the skill says so, applies everything else and does not push you to make
the repository public.

#### Daily use, once it is set up

Tell the agent what you want in plain words; it inspects your changes, proposes one
plan, asks once and runs one script:

| You say | Script | What it does |
|---|---|---|
| "upload today's work", "commit this" | `ship.sh` | branch from `develop` → commit → PR → waits for the CI → squash merge → back on an up-to-date `develop` |
| "publish a version" | `release.sh` | suggests the next SemVer from the commits (and pending Dependabot updates) → release PR → merge commit into `main` → tag → GitHub release |
| "production is broken" | `hotfix.sh` | branch from `main` → fix → PR → merge → patch tag and release → the fix back into `develop` |

The scripts stop with a clear reason instead of improvising (red CI, conflicts,
nothing to ship, a lower version), and running one again after an interruption
continues where it stopped.

#### Requirements

- `git`, and `gh` authenticated (`gh auth login`). Optional: `gitleaks`, to scan the
  initial commit for secrets.
- The skill installed on every machine you work from (see [Setup](#setup-on-a-new-device)).
- For the one-confirmation flow, one rule in `~/.claude/settings.json`; without it
  Claude Code asks permission for each git command. The skill never adds it for you:

  ```json
  "permissions": { "allow": ["Bash(bash ~/.claude/skills/setup-git-flow/scripts/*)"] }
  ```

#### Limits, honestly

- **GitHub only**, and **Git Flow lite only** (`main` + `develop`); not GitHub Flow or
  trunk-based.
- **The CI only checks the git workflow.** Build, lint and test jobs are the project's
  to add, and to mark as required in the rulesets.
- **Tuned for a solo maintainer:** pull requests need no approvals. For a team, raise
  the approvals in the rulesets; `ship.sh` then stops at "needs review" until someone
  approves, and you run it again.
- **Conflicts and red CI are yours** (or the agent's to explain): the scripts detect
  them and stop cleanly, they do not resolve them.
- Each repository's `CLAUDE.md` adds about 100 lines to every agent session there.

#### How it is tested

`tests/test-setup-git-flow.sh` runs the scripts unchanged against a local remote and a
fake `gh` that really merges, on Ubuntu and Windows on every change and on macOS
weekly: 113 checks covering normal
runs, every refusal and resuming after an interruption. They were checked by breaking
the scripts on purpose. What they cannot cover is GitHub itself (the real `gh`
output and API): that is confirmed by using the skill on a real repository.
