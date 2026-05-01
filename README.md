# claude-config

Personal Claude Code configuration — skills, templates, and reusable assets synced across devices.

## What's inside

```
claude-config/
├── skills/                 # Custom skills for Claude Code
│   └── setup-git-flow/    # Sets up Git Flow lite (main+develop+protections)
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
