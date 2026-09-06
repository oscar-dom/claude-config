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

Two jobs, because they catch different things:

- **actionlint** — workflow syntax, expressions, runner labels, shellcheck over
  `run:` blocks.
- **Action refs resolve** (`scripts/check-action-refs.sh`) — resolves every
  `uses: owner/repo@ref` against the GitHub API. actionlint checks that a `uses:`
  line is *well-formed*, never that the ref exists; `astral-sh/setup-uv@v10` passes
  actionlint cleanly and still fails at runtime, because Astral stopped publishing
  floating major tags after v7.

## Available skills

### `setup-git-flow`

Sets up a complete Git Flow lite configuration in a new project:
- `main` + `develop` branches with protection rulesets
- PR/issue templates, CODEOWNERS
- GitHub Actions CI (lint, typecheck, build, commitlint)
- `CONTRIBUTING.md` and `docs/git-cheatsheet.md`
- Conventional Commits enforcement
- Secret scanning + Dependabot enabled

**Trigger:** ask Claude to *"set up Git Flow"*, *"replicate the Git config"*, or similar in any new project.
