# claude-config

Personal Claude Code configuration — skills, templates, and reusable assets synced across devices.

## What's inside

```
claude-config/
├── skills/                 # Custom skills for Claude Code
│   └── setup-git-flow/    # Sets up Git Flow lite (main+develop+protections)
├── scripts/                # Repo tooling used by CI
├── .github/workflows/      # Validates the skills' workflow templates
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
# macOS/Linux
ln -sfn ~/Desktop/GitHub/claude-config/skills/setup-git-flow ~/.claude/skills/setup-git-flow
```

Both installers detect a linked destination and skip it, so re-running them is safe.
Keep using the installer on every *other* machine.

## CI

`.github/workflows/lint-templates.yml` validates the workflow templates the skills
ship. They live under `skills/*/templates/.github/workflows/` and this repo never
runs them, so without this they would only be validated once a skill had already
copied them into a real project.

Three jobs, because they catch different things:

- **actionlint** — workflow syntax, expressions, runner labels, shellcheck over
  `run:` blocks.
- **Action refs resolve** (`scripts/check-action-refs.sh`) — resolves every
  `uses: owner/repo@ref` against the GitHub API. actionlint checks that a `uses:`
  line is *well-formed*, never that the ref exists; `astral-sh/setup-uv@v10` passes
  actionlint cleanly and still fails at runtime, because Astral stopped publishing
  floating major tags after v7.
- **Commit convention in sync** (`scripts/check-convention-sync.sh`) — the commit
  convention lives both in `setup-git-flow/scripts/lib.sh` (used by `ship.sh` and
  `hotfix.sh`) and in the CI template, which runs in the user's repository and
  cannot read the skill. If the two drift, the agent would ship titles the CI
  rejects; this job fails first.

## Available skills

### `setup-git-flow`

Sets up a complete Git Flow lite configuration in a new project, without assuming any
stack. The skill, its scripts and everything it creates in the repository (templates,
documentation, commits and PRs) are in English; Claude talks to you in your language.

- `main` + `develop` (default branch) with rulesets whose required check only accepts
  GitHub Actions, and immutable `v*` tags
- Merge settings: squash into `develop`, merge commit into `main`, the PR title as the
  commit message (no body), no rebase, branches deleted on merge
- If the repository already exists with `master`, asks whether to rename it to `main`
  first
- Stack-agnostic CI: validates the PR title (and every commit on PRs into `main`) and
  the source of PRs into `main`
- PR and issue templates, CODEOWNERS, `.gitattributes`, a minimal `.editorconfig` and
  Dependabot for GitHub Actions only
- `CONTRIBUTING.md` and `docs/git-cheatsheet.md` with releases and hotfixes
- Secret scanning and Dependabot where the plan allows them

What it always does, on every run:

- **Reads the GitHub plan and asks for the visibility** before creating the repository,
  showing what each option costs on that plan. There is no default.
- **Asks who will manage the repository** (Claude Code, another AI or people only).
  With an AI it adds `CLAUDE.md` or `AGENTS.md` with daily recipes: the agent looks
  at your changes, proposes one plan in plain language, asks once and ships it with
  `ship.sh` (branch, commit, PR, CI, merge, cleanup), releases it with `release.sh`
  (release PR, CI, merge commit, tag, GitHub release) or fixes production with
  `hotfix.sh` (patch release from `main`, then the fix back into `develop`).
- **Only with an AI, asks whether to forbid AI attribution** (`Co-Authored-By:`
  trailers, "Generated with" lines). With a yes, a CI step blocks PRs that carry it
  and, with Claude Code, a project `.claude/settings.json` turns it off at the source.
  With a no, or with people only, nothing about it is added.
- **Audits the close** before declaring anything done: no open PRs, unpushed commits,
  branches without upstream or pending promotions, and it reads back from GitHub the
  merge settings, rulesets and required check it applied. If something is missing, it
  says so and asks for permission to finish instead of reporting success.

**Trigger:** ask Claude to *"set up Git Flow"*, *"configure git for this project"*, or
the Spanish *"monta Git Flow"*, in any new project.
