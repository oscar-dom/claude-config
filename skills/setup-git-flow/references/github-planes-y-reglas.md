# GitHub: planes, ajustes, rulesets y política de fusión

Detalle de la comprobación previa 5 y del paso 4 de `SKILL.md`.

## Qué da cada plan (cuentas personales)

| | Público (cualquier plan) | Privado, Free | Privado, Pro |
|---|---|---|---|
| Ajustes de fusión, rama por defecto `develop`, CI, Dependabot | sí | sí | sí |
| Rulesets (`main`, `develop`, etiquetas `v*`) | sí | **no** (`403 Upgrade to GitHub Pro`) | sí |
| Secret scanning y push protection | sí | **no** | **no** (requiere GitHub Secret Protection, solo organizaciones) |
| Código legible por cualquiera | sí | no | no |

El plan se lee con `gh api user --jq .plan.name` (`free`, `pro`…). Si el repositorio
se va a crear en una **organización**, el plan que cuenta es el de la organización:
`gh api orgs/<org> --jq .plan.name` (necesita ser miembro con permisos; si no
responde, enseña la tabla completa y dilo). En organizaciones, Team equivale a Pro
para los rulesets.

Cómo usarlo al preguntar la visibilidad: enseña **solo la columna que le afecta** a
cada opción. Con Pro, elegir privado no pierde la protección de ramas, y hay que
decirlo. Con Free, privado significa quedarse sin rulesets ni secret scanning: es una
opción válida, no un problema que resolver.

## Lo que impone GitHub en cada caso

Los **ajustes del repositorio** que aplica `configurar-github.sh` funcionan en todos
los planes, y en un privado Free son lo único que GitHub impone:

| Ajuste | Valor | Efecto |
|---|---|---|
| `allow_squash_merge` / `allow_merge_commit` | `true` | los dos métodos de la política |
| `allow_rebase_merge` | `false` | ningún botón fuera de la política |
| `squash_merge_commit_title` / `_message` | `PR_TITLE` / `PR_BODY` | el commit de squash es el título del PR, no el del primer commit |
| `merge_commit_title` / `_message` | `PR_TITLE` / `PR_BODY` | las releases quedan como `chore: release vX.Y.Z`, no `Merge pull request #N` |
| `delete_branch_on_merge` | `true` | la rama remota se borra al fusionar |
| `default_branch` | `develop` | los PR apuntan a `develop` sin `--base` |

Sobre el borrado automático: GitHub no borra la rama por defecto ni una rama protegida.
Por eso `develop` es seguro como cabeza del PR de release. `main` **nunca** debe ser la
cabeza de un PR (en un privado Free no tiene protección y se borraría): para devolver
un hotfix a `develop` se corta una rama `chore/sync-*` desde `main`.

## Rulesets

- `main.json`: solo PR, check `Commit messages` obligatorio, conversaciones resueltas,
  sin force push ni borrado, **solo merge commit**.
- `develop.json`: solo PR, check obligatorio, sin force push ni borrado, squash y merge
  commit (el merge commit hace falta para traer un hotfix desde `chore/sync-*`).
- `tags.json`: las etiquetas `v*` no se pueden borrar ni mover. Sin bypass: una versión
  publicada es inmutable; si está mal, se publica otra.

Los rulesets de rama usan `actor_id: 5` (administrador) con `bypass_mode: pull_request`.
`fusionar-pr.sh` **no** usa `--admin`: si un ruleset exige aprobaciones, el PR espera a
la revisión.

`main` no lleva `required_linear_history`: prohíbe los merge commits, que es justo el
método de las releases.

## Por qué squash hacia `develop` y merge commit hacia `main`

- **Squash hacia `develop`:** la rama de trabajo vive poco y se borra; aplastarla no
  separa ninguna historia y deja un commit por cambio. Por eso el CI valida **el título
  del PR** en estos PR, y no los commits intermedios: es lo único que sobrevive.
- **Merge commit hacia `main`:** `develop` y `main` viven siempre. Un squash entre ellas
  crea en `main` un commit que no existe en `develop`, las historias se separan y cada
  release vuelve a listarlo todo. Con merge commit, los commits de `develop` pasan a
  ser ancestros de `main`. Como entran tal cual, en estos PR el CI valida **cada
  commit** además del título.

## Texto de `PROTECTION_STATUS`

`CONTRIBUTING.md` y `docs/git-cheatsheet.md` tienen una línea `PROTECTION_STATUS`.
Sustitúyela en los dos por el texto que corresponda a lo que `configurar-github.sh`
**aplicó de verdad** (no a lo que se pretendía):

**Rulesets aplicados:**

```markdown
GitHub enforces the rules below through repository rulesets.
```

**Rulesets no disponibles (privado sin plan de pago):**

```markdown
> [!NOTE]
> This repository is private on a plan without rulesets, so GitHub does **not**
> enforce the branch rules below: they are followed by convention, and the CI check
> reports but does not block. GitHub does enforce, on every plan: squash and merge
> commit as the only merge methods, the PR title as the commit message, and the
> deletion of merged branches.
```
