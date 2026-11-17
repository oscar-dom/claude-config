# Incidencias

- **"Upgrade to GitHub Pro" al aplicar los rulesets** → el repositorio es privado en un
  plan sin rulesets, que es lo que avisaba la comprobación previa 5. `configurar-github.sh`
  lo reporta como `NO DISPONIBLE`; los rulesets van al resumen como pendientes, con su
  motivo. **No** ofrezcas hacer público el repositorio para rodearlo: esa decisión ya
  estaba tomada y publicaría todos los commits empujados. Solo se revisa si lo plantea
  el usuario.

- **`fusionar-pr.sh` dice que GitHub rechazó la fusión por revisión** → el ruleset exige
  aprobaciones (`required_approving_review_count` ≥ 1) y el PR no las tiene. Es el
  comportamiento correcto en modo equipo: pide la revisión. No uses `--admin`.

- **PR atascado en "Expected — Waiting for status to be reported"** → un context
  requerido no se ejecutó nunca. Casi siempre es un `if` a nivel de **job** (el job se
  salta y no reporta nada) o un job renombrado sin actualizar el `context` de los
  rulesets. Los `if` del CI de la skill van a nivel de **paso** a propósito: el job
  `Commit messages` siempre reporta.

- **`Commit messages` falla en `Validate PR title`** → el título no es un Conventional
  Commit, empieza en mayúscula, acaba en punto o pasa de 72 caracteres. Se arregla
  editando el título (`gh pr edit <n> --title "..."`): el evento `edited` vuelve a
  lanzar el CI.

- **`Commit messages` falla en `Check source branch`** → un PR hacia `main` desde una
  rama que no es `develop`, `hotfix/*` ni `release/*`. Cambia la base del PR a
  `develop` (`gh pr edit <n> --base develop`).

- **Un PR de Dependabot falla el CI** → revisa que `.github/dependabot.yml` conserva
  `commit-message.prefix: ci`. Sin él, Dependabot titula "Bump …" y no pasa la
  validación.

- **Defectos que solo aparecen al ejecutar.** El workflow `lint-templates.yml` del
  repositorio `claude-config` pasa actionlint sobre la plantilla de CI y resuelve cada
  `uses:` contra la API. Eso detecta sintaxis, expresiones y referencias que no existen,
  pero no lo que depende del repositorio concreto en tiempo de ejecución (permisos del
  token, ajustes de la organización). La plantilla nunca se ejecuta en `claude-config`,
  así que trata el primer PR de cada montaje nuevo como parte de la prueba y lee lo que
  reportan los checks.

- **`gh: command not found`** → tras instalarlo puede hacer falta una terminal nueva, o
  el PATH explícito: `export PATH="/c/Program Files/GitHub CLI:$PATH"`.

- **`configurar-github.sh` da `FALLO` en "rama por defecto"** → `develop` no existe en
  el remoto todavía. Haz el paso 3 (crear y empujar `develop`) y reejecuta el script.
