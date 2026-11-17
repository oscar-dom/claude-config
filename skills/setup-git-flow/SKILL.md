---
name: setup-git-flow
description: Monta una configuración completa de Git Flow lite en un proyecto nuevo. Úsala cuando el usuario pida "configura Git", "monta Git Flow", "replica la configuración de Git", "inicializa el repo con Git Flow", "protege las ramas", o cuando empiece un proyecto que necesite estrategia de ramas + plantillas de PR + CI + reglas de protección. También responde a las formas en inglés ("set up Git Flow", "configure git for this project", "set up branch protection"). Crea las ramas main/develop con rulesets, ajustes de fusión, plantillas de PR e issues, CODEOWNERS, CI en GitHub Actions, CONTRIBUTING.md y una chuleta de git siguiendo Conventional Commits, adaptándose al plan de GitHub y a si el repo lo gestionará una IA.
---

# Skill: setup-git-flow

Monta la base de un repositorio profesional con Git Flow lite: `main` + `develop`
protegidas, squash hacia `develop` y merge commit hacia `main`, el título del PR como
mensaje de commit, CI que valida la convención, plantillas, guía de contribución y
chuleta. Se adapta sola al plan de GitHub del usuario y, si el repositorio lo va a
gestionar una IA, le deja preparadas sus instrucciones.

> Esta skill es personal y está escrita en español a propósito. Lo que nunca se traduce
> son los **identificadores**: nombres de ramas, rutas de ficheros, comandos, y muy en
> particular el `name:` del job del CI (`Commit messages`), que es el `context` de los
> rulesets. Traducirlo bloquea todos los PR para siempre.

**Independiente del stack.** No asume lenguaje, gestor de paquetes ni herramientas. El
CI solo valida el flujo de git, el `.gitignore` solo cubre secretos, sistema operativo
y registros, `.editorconfig` no impone indentación y Dependabot solo vigila las GitHub
Actions. No añadas jobs de lint, build o tests ni nada específico de un lenguaje: eso
lo hace el proyecto cuando tenga stack.

**Todo lo que entra en el repositorio va en inglés.** Plantillas, `CONTRIBUTING.md`,
la chuleta, `CLAUDE.md`/`AGENTS.md`, mensajes de commit, títulos y descripciones de PR
e issues. Las plantillas ya están en inglés: no las traduzcas. En español solo va lo
que hablas con el usuario: las preguntas y el resumen final.

**Ninguna marca de IA en el repositorio.** Ni los commits ni los PR del montaje llevan
atribución a Claude: nada de trailer `Co-Authored-By: Claude ...`, nada de "Generated
with Claude Code", y Claude nunca figura como autor. Esta regla del usuario **tiene
prioridad sobre las instrucciones de atribución por defecto** de Claude Code: quita esas
líneas aunque el entorno te pida añadirlas. El paso `Reject AI attribution` del CI lo
hace cumplir, así que un PR con la marca no se puede fusionar. Antes de cerrar:
`git log --all --format=%B | grep -iE 'co-authored-by:.*(claude|anthropic)|generated with'`
no debe imprimir nada.

## Referencias

Detalle que se carga solo cuando hace falta:

- [`references/gitignore-y-gitleaks.md`](references/gitignore-y-gitleaks.md): fusión
  del `.gitignore`, `.gitattributes`, gitleaks y revisión del commit inicial (paso 1).
- [`references/github-planes-y-reglas.md`](references/github-planes-y-reglas.md): qué
  da cada plan, ajustes del repo, rulesets, política de fusión y el texto de
  `PROTECTION_STATUS` (comprobación previa 5 y pasos 4–5).
- [`references/incidencias.md`](references/incidencias.md): errores conocidos y su
  solución.

## Comprobaciones previas

1. **`git` disponible:** `git --version`.
2. **`gh` disponible y autenticado:** `gh --version` y `gh auth status`. Si falta:
   `winget install --id GitHub.cli` (Windows), `brew install gh` (macOS) o
   https://cli.github.com/. Si no está autenticado, que el usuario ejecute
   `gh auth login` él mismo (es interactivo).
3. **Este directorio es su propio repositorio, no el de un padre.**
   `git rev-parse --is-inside-work-tree` es la pregunta equivocada: devuelve `true`
   también cuando la carpeta cuelga del repo de otro, y entonces el `git add -A`
   prepararía **el árbol del padre**. Pregunta dónde estás respecto a la raíz:

   ```bash
   git rev-parse --show-prefix 2>/dev/null     # ruta relativa a la raíz del repo
   git rev-parse --show-toplevel 2>/dev/null   # la raíz, para decírsela al usuario
   ```

   No compares `--show-toplevel` con `pwd`: en Windows el mismo directorio tiene dos
   formas (`C:/...` y `/c/...`).

   | `--show-prefix` | Significa | Qué hacer |
   |---|---|---|
   | sale bien y vacío | el proyecto ya es su propio repo | continuar |
   | falla | no hay ningún repo | el paso 1 hace `git init -b main` |
   | **sale bien y no vacío** | está **dentro del repo de otro** | **PARAR y preguntar** |

   En el tercer caso, para antes de tocar nada, di qué repositorio has encontrado y
   dónde está su raíz, y deja decidir al usuario.

4. **Commits y remoto:** `git rev-parse --verify HEAD` y `git remote -v`. Si falta
   alguno, el paso 1 se encarga.

5. **Las dos preguntas del montaje, en UNA sola tarjeta de `AskUserQuestion`.** Son
   las únicas decisiones que el usuario toma en cada ejecución. Pregúntalas antes de
   crear nada y espera la respuesta. No las deduzcas del proyecto, de un valor por
   defecto ni de una ejecución anterior.

   **Antes, lee el plan** para que la pregunta de visibilidad diga las consecuencias
   reales de esa cuenta, sin que el usuario tenga que explicarlas:

   ```bash
   gh api user --jq .plan.name
   ```

   **Pregunta 1, visibilidad.** Si el repositorio no existe, con qué visibilidad
   crearlo; si existe, lee la actual (`gh repo view --json visibility --jq .visibility`),
   dila y pregunta si mantenerla. En la descripción de cada opción pon solo lo que
   cambia **para su plan** (tabla en `references/github-planes-y-reglas.md`):

   - Free: privado = sin protección de ramas por rulesets ni secret scanning;
     público = todo activo y código visible para cualquiera.
   - Pro: privado conserva la protección de ramas (sin secret scanning); público =
     todo activo y código visible.

   No empujes hacia ninguna: las dos son legítimas. **Solo haz público un repositorio
   con un sí explícito**, diciendo antes que publica **todos los commits que ya hay** y
   que volver a privado no despublica lo descargado o indexado. Nunca cambies la
   visibilidad en silencio. "Privado, en plan Free" es una respuesta completa, no un
   problema: no vuelvas a plantearlo más adelante.

   **Pregunta 2, quién gestionará el repositorio.**

   | Respuesta | Qué se añade (paso 5) |
   |---|---|
   | Claude Code | `CLAUDE.md` + `.claude/settings.json` (y los ficheros personales de Claude en `.gitignore`, paso 1) |
   | Otra IA (Codex, Cursor, Copilot…) | `AGENTS.md` |
   | Solo personas | nada más |

6. **Permisos de Claude Code: una sola regla, global.** Lo que modifica GitHub
   (fusionar PR, ajustes, rulesets, seguridad) va dentro de `scripts/`, con los
   endpoints fijos. Basta con permitir esos scripts una vez, en `~/.claude/settings.json`:

   ```json
   "permissions": { "allow": ["Bash(bash ~/.claude/skills/setup-git-flow/scripts/*)"] }
   ```

   **Invoca los scripts siempre exactamente así**:
   `bash ~/.claude/skills/setup-git-flow/scripts/<script>`. Con otra ruta la regla no
   casa y vuelve a pedir permiso.

   - Si la regla no está, **no la añadas por tu cuenta**: díselo al usuario y pregunta.
   - **No concedas `gh api -X PATCH repos/<owner>/*`** ni parecidos: dejaría hacer
     cualquier PATCH en cualquier repo, incluido volverlo público.
   - **Ningún permiso va dentro del proyecto.** El único `.claude/settings.json` que
     crea la skill es el de la pregunta 2, y solo desactiva la atribución: los permisos
     son de cada persona, no del repositorio.

   Ejecuta **un comando por llamada**, sin cadenas largas con `&&`.

## Pasos

### 1. Arranque: `main` con un commit inicial limpio y upstream

Todo lo demás asume que `main` existe con upstream. Comprueba qué falta:

```bash
git rev-parse --show-prefix 2>/dev/null     # vacío = este directorio es el repo
git rev-parse --verify HEAD 2>/dev/null     # ¿tiene commits?
git remote get-url origin 2>/dev/null       # ¿tiene remoto?
```

**Si no tiene commits:**

```bash
git init -b main                        # solo si todavía no es un repo
git symbolic-ref HEAD refs/heads/main   # si init llamó master a la rama
```

Antes del primer `git add -A`, siguiendo `references/gitignore-y-gitleaks.md`:

1. `.gitignore`: copiar si no hay, **fusionar si ya hay, nunca sobrescribir**. Si la
   respuesta 2 fue Claude Code, añadir `.claude/settings.local.json` y `CLAUDE.local.md`.
2. `.gitattributes` (`templates/.gitattributes`), si el proyecto no tiene uno.
3. Verificar con `git check-ignore -v` las rutas sensibles reales del proyecto.

Después:

```bash
git add -A
git status                              # REVÍSALO SIEMPRE: es lo que se va a publicar
gitleaks git --staged --redact --verbose
git commit -m "chore: initial commit"
```

gitleaks sin instalar es un aviso (se continúa y se dice en el resumen); gitleaks con
hallazgos es un **alto**: no se commitea.

**Mensajes de commit siempre en inglés**, en minúscula e imperativo, en este paso y en
todos.

**Si no tiene remoto**, créalo con la visibilidad que eligió el usuario y empuja `main`:

```bash
# <visibilidad> es --private o --public, de la respuesta 1. Sin valor por defecto a
# propósito: si todavía no has preguntado, para y pregunta.
gh repo create <nombre> <visibilidad> --source=. --remote=origin
git push -u origin main
```

Si el remoto existe pero `main` no tiene upstream: `git push -u origin main`.

### 2. Averiguar el repositorio y el usuario

```bash
gh repo view --json nameWithOwner --jq .nameWithOwner   # OWNER_REPO
gh api user --jq .login                                 # GH_USERNAME, para CODEOWNERS
```

### 3. Crear `develop`

```bash
git checkout main
git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1 && git pull
git checkout -b develop
git push -u origin develop
```

(Solo `git pull` si `main` tiene upstream: sin él falla.)

### 4. Configurar GitHub: ajustes, rama por defecto, seguridad y rulesets

**Va antes de los PR del montaje**, para que el primer squash ya use el título del PR
como mensaje y el PR de `develop` a `main` ya esté limitado a merge commit:

```bash
bash ~/.claude/skills/setup-git-flow/scripts/configurar-github.sh
```

Aplica, en este orden: ajustes de fusión (squash y merge commit con el título y la
descripción del PR, sin rebase, ramas borradas al fusionar), `develop` como rama por
defecto, alertas y parches de Dependabot, secret scanning y push protection, y los
rulesets `Protect main`, `Protect develop` y `Protect release tags` (los crea, o los
actualiza si ya existen). Detalle en `references/github-planes-y-reglas.md`.

Cada línea sale como `OK`, `NO DISPONIBLE` o `FALLO`:

- **`NO DISPONIBLE` no es un fallo**: es el plan que eligió el usuario. No se rodea, no
  se vuelve a preguntar y no se ofrece hacer público el repo. Va al resumen como
  pendiente, con el motivo.
- **`FALLO`** es un error real (repo inexistente, token sin permisos, JSON rechazado).
  Sale con `1`: no sigas sin resolverlo.

**Anota si los rulesets quedaron aplicados o no**: decide el texto de
`PROTECTION_STATUS` en el paso 5.

### 5. Copiar las plantillas

Copia `templates/` a la raíz del proyecto, conservando la estructura:

- `.github/PULL_REQUEST_TEMPLATE.md`
- `.github/ISSUE_TEMPLATE/bug_report.md`, `feature_request.md` y `config.yml` (este
  solo desactiva los issues en blanco; no enlaza a Discussions, que en un repo nuevo
  están desactivadas)
- `.github/CODEOWNERS`: **sustituye `@OWNER` por `@$GH_USERNAME`**
- `.github/workflows/ci.yml`
- `.github/dependabot.yml`
- `CONTRIBUTING.md`
- `docs/git-cheatsheet.md`: **siempre** en `docs/` (lo enlazan `CONTRIBUTING.md`,
  `CLAUDE.md` y `AGENTS.md`)
- `.editorconfig`, y `.gitattributes` si no entró en el commit inicial
- `.gitignore`: **ya resuelto en el paso 1**; no lo vuelvas a copiar encima

**Sustituye `PROTECTION_STATUS`** en `CONTRIBUTING.md` y en `docs/git-cheatsheet.md`
por el texto que corresponda a lo que el paso 4 **aplicó de verdad** (los dos textos
están en `references/github-planes-y-reglas.md`). No dejes el marcador.

**Según la respuesta 2**, copia además desde `ai-templates/`:

| Respuesta | Ficheros |
|---|---|
| Claude Code | `ai-templates/claude/CLAUDE.md` → `CLAUDE.md`; `ai-templates/claude/.claude/settings.json` → `.claude/settings.json` |
| Otra IA | `ai-templates/agents/AGENTS.md` → `AGENTS.md` |
| Solo personas | nada |

`.claude/settings.json` solo desactiva la atribución de Claude en commits y PR, y así
la regla de no dejar marca se cumple desde el origen. **Nunca le añadas permisos.**

**Si un fichero ya existe en el proyecto, no lo sobrescribas.** Para `CLAUDE.md` o
`AGENTS.md` existentes, añade al final la sección `## Git workflow` de la plantilla
(si no la tiene ya). Para el resto (por ejemplo un `CONTRIBUTING.md` propio), díselo
al usuario y pregunta si fusionar, conservar el suyo o reemplazarlo. Un
`.editorconfig` o `.gitattributes` existente se respeta sin preguntar.

### 6. Commitear las plantillas vía PR y sincronizar `main`

El contenido del proyecto entró en el commit inicial (paso 1); las plantillas entran
ahora por PR. Antes, `git status`: algo inesperado sin seguimiento significa que el
paso 1 quedó a medias.

Prepara **solo las rutas que copiaste**, nunca `git add -A` ni carpetas enteras:

```bash
git checkout -b chore/git-flow-setup
git add .github CONTRIBUTING.md docs/git-cheatsheet.md .editorconfig
# más .gitattributes, CLAUDE.md, .claude/settings.json o AGENTS.md si los copiaste
git commit -m "chore: set up git flow with ci, templates and contributing guide"
git push -u origin chore/git-flow-setup
gh pr create --base develop --title "chore: set up git flow" --fill
```

**El título del PR es el mensaje del commit** que quedará en `develop`, y el CI lo
valida: Conventional Commit, minúscula al empezar, sin punto final, como mucho 72
caracteres.

Fusiona **siempre con el script**, que espera a que los checks se registren y terminen
y solo fusiona en verde, sin saltarse reglas:

```bash
bash ~/.claude/skills/setup-git-flow/scripts/fusionar-pr.sh <numero> squash
```

Imprime `FUSIONADO` (sale con `0`) o `NO FUSIONADO` y el motivo (sale con `1`). Con
`1`, **lee el log antes de tocar nada** (`references/incidencias.md`). Quédate con los
checks que imprime: van al resumen.

Después, la primera release `develop → main`, con **merge commit**:

```bash
git checkout develop
git pull --prune
gh pr create --base main --head develop --title "chore: initial git flow setup" --fill
bash ~/.claude/skills/setup-git-flow/scripts/fusionar-pr.sh <numero> merge
```

Y limpia la rama local del montaje (con squash, `-d` no la reconoce como fusionada):

```bash
git branch -D chore/git-flow-setup
```

No se crea etiqueta de versión: la primera versión la decide el proyecto cuando tenga
algo que publicar (procedimiento en la chuleta).

### 7. Documentar el montaje

Si el proyecto tiene `docs/progress.md` u otra documentación de estado, añade **en
inglés**: la estrategia de ramas (o un enlace a `CONTRIBUTING.md`), si la protección
está activa o pendiente y por qué, y la fecha. Si el usuario pidió no tocar algún
fichero, respétalo y dilo en el resumen. Si no hay documentación, `CONTRIBUTING.md` es
la fuente de verdad.

## Cierre: primero la auditoría, después el resumen

### A. Auditoría

**No escribas el resumen de memoria.** Lo que manda es el código de salida del script:

```bash
bash ~/.claude/skills/setup-git-flow/scripts/auditar-cierre.sh
```

| Código | Significa | Qué hacer |
|---|---|---|
| `0` | `CERRADO` | escribe el resumen |
| `1` | `PENDIENTE` y qué falta | **no reportes el montaje como completo** |

Ejecútalo desde la raíz del proyecto (si no, se niega). Hace `git fetch --prune` él
mismo. Comprueba ocho cosas: árbol limpio, ninguna rama sin empujar ni sin upstream,
`main` y `develop` en el remoto, `develop` sincronizada con `main`, ningún PR del
montaje abierto, la rama temporal borrada en local y en remoto, todas las etiquetas
subidas, y `develop` como rama por defecto. Otros PR abiertos (los de Dependabot, por
ejemplo) salen como aviso `?` y no bloquean.

**Si sale `1`**, di exactamente qué falta y **pide permiso para terminarlo**. Si te lo
da, termínalo y **vuelve a ejecutar el script**: lo que reportas es la segunda pasada.

Lo que el script no cubre a propósito: rulesets o secret scanning `NO DISPONIBLE` por
el plan. Van al resumen como pendientes **con su motivo**, nunca como fallo.

### B. Resumen, en español

En español salvo que el usuario pida otro idioma; los identificadores (comandos, ramas,
rutas, checks) en su forma original. Cubre **todos** los puntos; si alguno no aplica,
dilo en vez de omitirlo:

- **Repositorio**: URL, visibilidad (elegida por el usuario) y plan detectado.
- **Gestor**: la respuesta 2 y qué ficheros se crearon por ella.
- **Ramas**: `main` y `develop` en el remoto; `develop` como rama por defecto.
- **Commit inicial**: la lista de ficheros que llevó.
- **Plantillas y ficheros creados**, y los que ya existían y se respetaron.
- **Ajustes de fusión**: aplicados o no.
- **CI**: qué reportó `Commit messages` en cada PR. Recuerda que es independiente del
  stack: cuando el proyecto tenga código, habrá que añadirle sus jobs y marcarlos como
  requeridos en los rulesets.
- **Rulesets**: aplicados, o pendientes con el motivo.
- **Seguridad**: qué quedó activo y qué no está disponible en ese plan.
- **gitleaks**: qué devolvió, o que el commit inicial fue **sin escanear**.
- **Política de fusión**: squash hacia `develop`, merge commit hacia `main`, título del
  PR como mensaje.
- **Atribución de IA**: ningún commit ni PR la lleva (comprobado con el `git log` de
  arriba).
- **Licencia**: solo si el repo es público y no tiene `LICENSE`, avisa de que sin
  licencia el código es "todos los derechos reservados" y que elegirla es decisión del
  usuario. No la crees.
- **Qué falló, se saltó o necesitó improvisación**: siempre presente; si nada, dilo.
- **Auditoría**: nada pendiente, o qué queda y qué has preguntado.

## Opciones que conviene considerar

Pregunta solo si el usuario lo menciona o no está claro:

- **Un solo desarrollador o equipo**: por defecto `required_approving_review_count: 0`.
  En equipo, súbelo a 1 o más en los dos rulesets y cambia la fila "Required approvals"
  de la tabla de `CONTRIBUTING.md`. `fusionar-pr.sh` no se salta las aprobaciones.
- **Jobs del CI**: si renombras el job en `ci.yml`, actualiza el `context` en los dos
  rulesets. Los jobs que añada el proyecto más adelante solo son obligatorios si se
  listan en los rulesets.
- **Cambiar una regla de un ruleset**: cambia también la tabla de `CONTRIBUTING.md`.
