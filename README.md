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

Monta una configuracion completa de Git Flow lite en un proyecto nuevo, sin asumir
ningun stack. La skill esta escrita en espanol; sus instrucciones y el resumen final van
en espanol, pero todo lo que crea en el repositorio (plantillas, documentacion,
commits y PR) va en ingles.

- Ramas `main` + `develop` (rama por defecto) con rulesets cuyo check obligatorio solo
  acepta GitHub Actions, y etiquetas `v*` inmutables
- Ajustes de fusion: squash hacia `develop`, merge commit hacia `main`, el titulo del PR
  como mensaje de commit (sin cuerpo), sin rebase, ramas borradas al fusionar
- Si el repo ya existe con `master`, pregunta si renombrarla a `main` antes de nada
- CI independiente del stack: valida el titulo del PR (y cada commit en los PR hacia
  `main`), el origen de los PR hacia `main` y la ausencia de atribucion de IA
- Plantillas de PR e issues, CODEOWNERS, `.gitattributes`, `.editorconfig` minimo y
  Dependabot solo para las GitHub Actions
- `CONTRIBUTING.md` y `docs/git-cheatsheet.md` con releases y hotfixes
- Secret scanning y Dependabot donde el plan lo permite

Tres cosas que hace siempre, en cada ejecucion:

- **Lee el plan de GitHub y pregunta la visibilidad** antes de crear el repositorio,
  ensenando lo que cada opcion cuesta en ese plan. No hay valor por defecto.
- **Pregunta quien gestionara el repositorio** (Claude Code, otra IA o solo personas)
  y solo entonces anade `CLAUDE.md` + `.claude/settings.json` o `AGENTS.md`.
- **Audita el cierre** antes de dar nada por terminado: que no queden PR abiertos,
  commits sin empujar, ramas sin upstream ni promociones pendientes. Si queda algo, lo
  dice y pide permiso para terminarlo en vez de reportar exito.

**Disparador:** pedirle a Claude *"monta Git Flow"*, *"replica la configuracion de
Git"*, o la forma en ingles *"set up Git Flow"*, en cualquier proyecto nuevo.
