# claude-config

Personal Claude Code configuration, synced across devices.

## What's inside

```
claude-config/
├── skills/        # Personal skills, installed into ~/.claude/skills/
├── install.ps1    # Windows installer
└── install.sh     # macOS/Linux installer
```

## Setup on a new device

Prerequisites: `git`, the [GitHub CLI](https://cli.github.com/) authenticated
(`gh auth login`) and Claude Code.

**Windows (PowerShell):**
```powershell
cd $HOME\Desktop\GitHub
git clone https://github.com/oscar-dom/claude-config.git
cd claude-config
.\install.ps1
```

**macOS/Linux:**
```bash
cd ~/Desktop/GitHub
git clone https://github.com/oscar-dom/claude-config.git
cd claude-config
./install.sh
```

The installer copies `skills/*` into `~/.claude/skills/`. Re-run it after `git pull`.
A skill that is a link (junction or symlink) into this repository is left alone:
on the machine where you author skills, link instead of copying so the two never
drift.

## Published plugins

`setup-git-flow` moved to its own public repository,
[oscar-dom/setup-git-flow](https://github.com/oscar-dom/setup-git-flow), and is
installed as a Claude Code plugin on every machine:

```
/plugin marketplace add oscar-dom/setup-git-flow
/plugin install setup-git-flow@oscar-dom
```

If a machine still has the old copy in `~/.claude/skills/setup-git-flow` (copied or
linked by an earlier installer), remove it after installing the plugin, so Claude Code
does not load two skills with the same name.
