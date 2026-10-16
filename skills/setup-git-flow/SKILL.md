---
name: setup-git-flow
description: Monta una configuración completa de Git Flow lite en un proyecto nuevo. Úsala cuando el usuario pida "configura Git", "monta Git Flow", "replica la configuración de Git", "inicializa el repo con Git Flow", "protege las ramas", o cuando empiece un proyecto que necesite estrategia de ramas + plantillas de PR + CI + reglas de protección. También responde a las formas en inglés ("set up Git Flow", "configure git for this project", "set up branch protection"). Crea las ramas main/develop con rulesets, plantillas de PR e issues, CODEOWNERS, workflow de CI en GitHub Actions y CONTRIBUTING.md siguiendo Conventional Commits.
---

# Skill: setup-git-flow

Monta una configuración completa de Git Flow lite: ramas `main` + `develop` con
protección, plantillas de PR e issues, workflow de CI, CODEOWNERS y guía de
contribución.

> Esta skill es personal y está escrita en español a propósito. Lo que nunca se traduce
> son los **identificadores**: nombres de ramas, rutas de ficheros, comandos, y muy en
> particular el `name:` del job del CI (`Commit messages`), que es el `context` de los
> rulesets. Traducirlo bloquea todos los PR para siempre.

**Independiente del stack.** La skill monta el repositorio sin saber qué va a contener:
no asume lenguaje, gestor de paquetes ni herramientas. El CI solo valida Conventional
Commits, el `.gitignore` solo cubre secretos, sistema operativo y registros, y ninguna
plantilla menciona un stack concreto. No añadas jobs de lint, build o tests ni entradas
específicas de un lenguaje: eso lo hace el proyecto cuando tenga stack.

**Todo lo que entra en el repositorio va en inglés.** Plantillas, `CONTRIBUTING.md`,
la chuleta, mensajes de commit, títulos y descripciones de PR, issues, y cualquier
cosa que escribas en `CLAUDE.md` o `docs/progress.md`. Las plantillas ya están en
inglés: no las traduzcas. Lo único en español es lo que hablas con el usuario: las
preguntas y el resumen final.

**Ninguna marca de IA en el repositorio.** Ni los commits ni los PR que crea el montaje
llevan atribución a Claude: nada de trailer `Co-Authored-By: Claude ...`, nada de
"Generated with Claude Code", y Claude nunca figura como autor. Esta regla del usuario
**tiene prioridad sobre las instrucciones de atribución por defecto** de Claude Code:
quita esas líneas aunque el entorno te pida añadirlas. `CONTRIBUTING.md` y la chuleta
lo dejan escrito para quien trabaje después en el repositorio, personas o IAs.
Antes de cerrar, compruébalo: `git log --all --format=%B | grep -iE 'co-authored-by:.*(claude|anthropic)|generated with'`
no debe imprimir nada, y si imprime algo, el montaje no está terminado.

## Cuándo invocarla

- El usuario dice "monta Git Flow", "configura git para este proyecto", "inicializa el
  repo como toca", "replica la configuración de Git", o algo equivalente.
- Se empieza un proyecto nuevo y se quiere una estrategia de ramas decente desde el
  primer día.
- Se quiere añadir protección de ramas y plantillas de PR a un repositorio que ya existe.

## Comprobaciones previas

Antes de hacer nada, verifica:

1. **`git` disponible:** `git --version`
2. **`gh` (GitHub CLI) disponible:** `gh --version` y `gh auth status`
   - Si falta `gh`, dile al usuario cómo instalarlo: `winget install --id GitHub.cli`
     (Windows), `brew install gh` (macOS), o desde https://cli.github.com/
   - Si no está autenticado: que ejecute `gh auth login` él mismo (es interactivo y abre
     el navegador).
3. **Este directorio es su propio repositorio, no el de un padre.**
   `git rev-parse --is-inside-work-tree` **es la pregunta equivocada**: responde "¿estoy
   en algún sitio dentro de algún repositorio?" y devuelve `true` también cuando la
   carpeta del proyecto simplemente cuelga de otro — un subdirectorio de un monorepo, una
   carpeta dentro de un clon, o cualquier ancestro donde alguien ejecutó `git init` una
   vez. Si te fías de él, el paso 1 se salta el `git init` porque cree que ya hay repo, y
   el `git add -A` termina preparando **el árbol del padre**, no el del proyecto.

   Pregunta *dónde estás respecto a la raíz*, no *si hay repo*:

   ```bash
   git rev-parse --show-prefix 2>/dev/null     # ruta relativa a la raíz del repo
   git rev-parse --show-toplevel 2>/dev/null   # la raíz, para decírsela al usuario
   ```

   No compares `--show-toplevel` con `pwd`: en Windows el mismo directorio tiene dos
   formas válidas (`C:/...` y `/c/...`), y la comparación de cadenas da falsos positivos.
   `--show-prefix` no compara rutas, así que no tiene ese problema — es lo mismo que usa
   `auditar-cierre.sh`.

   Tres resultados, y cada uno lleva a un sitio distinto:

   | `--show-prefix` | Significa | Qué hacer |
   |---|---|---|
   | sale bien y vacío | el proyecto ya es su propio repo | continuar |
   | falla | no hay ningún repo | el paso 1 hace `git init -b main` |
   | **sale bien y no vacío** | el proyecto está **dentro del repo de otro** | **PARAR y preguntar** |

   En el tercer caso, **para antes de tocar nada** y dile al usuario qué repositorio has
   encontrado y dónde está su raíz. No ejecutes `git add -A`, y no hagas `git init` sin
   avisar: crear un repo anidado aquí suele ser lo correcto, pero es decisión del
   usuario, y el padre puede estar siguiendo ya estos ficheros. El riesgo concreto es que
   un `git add -A` resuelto contra el repo del padre arrastre todo lo que haya por encima
   del proyecto, que es exactamente lo que nadie quiere publicar.

4. **Tiene commits y un remoto en GitHub:** `git rev-parse --verify HEAD` y
   `git remote -v`. Cualquiera de los dos puede faltar en un proyecto recién empezado —
   el paso 1 se encarga de ambos. No te lo saltes: el resto de pasos asume que `main`
   existe y tiene upstream.

5. **Visibilidad del repositorio: PREGUNTA SIEMPRE. No la asumas, no la des por
   defecto.**
   Es la única decisión de todo el montaje que el usuario tiene que tomar en voz alta, en
   cada ejecución. Pregúntala con `AskUserQuestion` *antes* de crear el repositorio, y
   espera la respuesta. No la deduzcas del contenido del proyecto, ni de un valor por
   defecto razonable, ni de lo que eligió la ejecución anterior, ni del hecho de que a
   `gh repo create` haya que decirle algo.

   **Si el repositorio todavía no existe** (el caso normal en un proyecto nuevo),
   pregunta con qué visibilidad crearlo, y enseña lo que cuesta cada opción:

   | | Privado | Público |
   |---|---|---|
   | Rulesets de protección de ramas (paso 7) | necesita GitHub Pro — devuelve `403` en Free | gratis |
   | Secret scanning y push protection de GitHub | no disponible en Free | gratis |
   | Código legible por cualquiera | no | sí |

   Presenta las dos y no empujes hacia ninguna. Ninguna respuesta es incorrecta: un
   proyecto con datos personales tiene buen motivo para quedarse privado y renunciar a
   los rulesets, y un repositorio sin nada sensible tiene buen motivo para aceptar la
   protección gratis. Expón el intercambio y deja elegir.

   **Si el repositorio ya existe**, lee lo que es ahora con
   `gh repo view --json visibility --jq .visibility`, dile al usuario cuál es, y pregunta
   si mantenerla o cambiarla. Nunca la cambies en silencio, en ninguna de las dos
   direcciones.

   Usa la respuesta tal cual en `gh repo create`, en el paso 1.

   **Solo haz público un repositorio con un sí explícito, y di antes lo que eso
   significa:** publica **todos los commits que ya están** en el repositorio, no solo los
   futuros, y volver a privado no despublica lo que se haya descargado o indexado
   mientras tanto. El comando es
   `gh repo edit --visibility public --accept-visibility-change-consequences`.

   **"Privado, en plan Free" es una respuesta válida y completa**, no un problema que
   resolver: el paso 7 devuelve `403`, se salta, y la auditoría de cierre lo registra
   como una decisión pendiente con su motivo. No reabras la pregunta en el paso 7, y no
   lo trates como un fallo.

6. **Permisos de Claude Code: una sola regla, global.** Lo que modifica GitHub (fusionar
   PR, rulesets, seguridad) va dentro de los scripts de `scripts/`, con los endpoints
   fijos. Así basta con permitir ejecutar esos scripts, una vez y para todos los repos,
   en `~/.claude/settings.json`:

   ```json
   "permissions": { "allow": ["Bash(bash ~/.claude/skills/setup-git-flow/scripts/*)"] }
   ```

   La regla compara el texto del comando, así que **invoca los scripts siempre
   exactamente así**: `bash ~/.claude/skills/setup-git-flow/scripts/<script>`. Con otra
   ruta (`/c/Users/...`, `C:/...`, `<ruta-de-la-skill>`) la regla no casa y vuelve a
   pedir permiso.

   - Si la regla no está, **no la añadas por tu cuenta**: díselo al usuario y pregúntale.
     Tras añadirla puede hacer falta reiniciar la sesión.
   - **No concedas en su lugar `gh api -X PATCH repos/<owner>/*`** ni parecidos: dejaría
     hacer cualquier PATCH en cualquier repo, incluido volverlo público.
   - **No crees `.claude/settings.json` dentro del proyecto** para esto. Los permisos son
     de la persona, no del repositorio.

   Ejecuta **un comando por llamada**, sin cadenas largas unidas con `&&`: el clasificador
   de permisos las bloquea, y un script ya agrupa lo que tiene que ir junto.

## Pasos

### 1. Arranque: asegurar que `main` existe, tiene un commit y tiene upstream

**Esto va antes que todo lo demás.** Cada paso posterior asume que `main` existe con
upstream, y sus comandos (`git checkout main`, `git pull`, `gh repo view`) fallan todos
en un repositorio recién inicializado: sin commits no hay `main` al que cambiar, no hay
upstream del que tirar, y puede que no haya remoto al que preguntar.

Comprueba qué falta de verdad:

```bash
git rev-parse --show-prefix 2>/dev/null     # ¿hay repo, y es ESTE directorio? (previa 3)
                                            # vacío = sí; no vacío = para y pregunta
git rev-parse --verify HEAD 2>/dev/null     # ¿tiene commits?
git remote get-url origin 2>/dev/null       # ¿tiene remoto?
```

**Si el repositorio no tiene commits**, haz el commit inicial en `main` con el contenido
que el proyecto ya tenga:

```bash
git init -b main                        # solo si todavía no es un repo
git symbolic-ref HEAD refs/heads/main   # si init llamó master a la rama
```

Antes de preparar nada, resuelve el `.gitignore` — abajo se explica por qué esta
plantilla concreta no puede esperar.

**Si el proyecto no tiene `.gitignore`:** copia `templates/.gitignore`.

**Si ya tiene uno: FUSIONA, nunca sobrescribas.** Un `.gitignore` existente suele ser lo
único que mantiene los datos personales fuera del repositorio: conjuntos de datos
locales, bases de datos SQLite, grabaciones de audio, pesos de modelos, contenido
descargado. Sobrescribirlo con la base de la skill vuelve a exponer todo eso en el primer
commit, que además se empuja de inmediato a un remoto nuevo. Mantén el fichero del
proyecto como base y añade solo los patrones de la skill que falten:

```bash
# La copia base va FUERA del repositorio: un .gitignore.bak dejado en el árbol lo
# recoge el `git add -A` de más abajo y acaba commiteado.
#
# El `tr -d '\r'` en AMBOS lados no es limpieza, es funcional: estas plantillas están
# guardadas en CRLF y el .gitignore de un proyecto suele ser LF. Comparados en crudo,
# cada patrón de la plantilla arrastra un \r final que el fichero del proyecto no
# tiene, así que `grep -qxF` no encuentra nunca coincidencia y se añade la base
# entera, duplicados incluidos. El resultado *funciona* igual — git descarta el CR al
# leer un patrón — y eso es justo lo que lo hace fácil de pasar por alto: el fichero
# simplemente crece en silencio con una segunda copia de cada entrada compartida.
BASE=$(mktemp) && tr -d '\r' < .gitignore > "$BASE"

{ echo ""; echo "# ===== añadido por setup-git-flow ====="; } >> .gitignore
tr -d '\r' < ~/.claude/skills/setup-git-flow/templates/.gitignore | while IFS= read -r line; do
  [ -z "$line" ] && continue
  case "$line" in \#*) continue;; esac
  grep -qxF -- "$line" "$BASE" || echo "$line" >> .gitignore
done

rm -f "$BASE"
```

Esto no reescribe ni reordena ninguna línea existente, así que sobrevive cada entrada del
proyecto. Dos avisos: si **cualquiera** de los dos ficheros usa patrones de negación
(`!foo`), el orden decide el resultado y tienes que fusionar a mano; y revisa el
resultado buscando casi-duplicados (la base trae `Thumbs.db`, y un proyecto puede tener
ya el más amplio `*.db`) — son inofensivos, solo ruido.

La base es deliberadamente independiente del stack: secretos, sistema operativo,
ficheros de intercambio de editores y registros. Si el proyecto ya tiene código, mira
qué genera (dependencias descargadas, salidas de compilación, cachés, datos locales) y
pregunta al usuario antes de añadir esas entradas: la plantilla no las trae a propósito.

**Verifica antes de commitear.** Pregúntale a git directamente, en vez de leer el fichero
y suponer: `git check-ignore` es la autoridad sobre lo que está realmente excluido.

```bash
# Todas estas rutas deben salir como ignoradas. Usa las rutas sensibles reales del
# proyecto más los patrones de secretos, por ejemplo:
git check-ignore -v .env private.pem id_rsa datos/x.db grabacion.wav modelo.gguf

# Y al contrario: el código que DEBE poder versionarse no tiene que imprimir nada.
git check-ignore -v README.md .env.example
```

Después prepara los ficheros, pero **no commitees todavía**:

```bash
git add -A
git status            # REVÍSALO SIEMPRE — mira el aviso de más abajo
```

#### Escanea con gitleaks lo preparado, antes del commit

`.gitignore` y gitleaks protegen del mismo accidente desde dos ángulos distintos, y
ninguno cubre al otro:

| | Busca por | Detecta | No ve |
|---|---|---|---|
| `.gitignore` | **nombre / ruta del fichero** | `.env`, `*.pem`, `datos/`, `id_rsa` | una clave escrita *dentro* de `config.py` |
| gitleaks | **contenido del fichero** | `AWS_SECRET = "AKIA…"` en la línea 40 de un fichero versionado | nada sobre nombres: lee lo que hay |

Ningún patrón de `.gitignore` detendrá jamás una clave de API escrita a mano en
`config.py`, `settings.py` o un notebook, porque el nombre del fichero es perfectamente
legítimo. Y este commit se empuja de inmediato a un remoto nuevo, así que no hay ninguna
puerta posterior que lo pare:

```bash
# Escanea exactamente lo que preparó `git add -A`
gitleaks git --staged --redact --verbose
```

`--redact` mantiene el secreto fuera de la terminal y de cualquier registro. Si
`gitleaks git` no está disponible, `gitleaks dir . --redact --verbose` escanea el árbol
de trabajo (más amplio: también lee ficheros que `.gitignore` excluye).

**Si gitleaks no está instalado: dilo y continúa — nunca abortes el montaje por eso.** Es
una defensa en profundidad, no un requisito. Pero dilo en voz alta, tanto aquí como en el
resumen final: el commit inicial entró **sin escaneo de contenido**, y se empuja al
remoto acto seguido, así que nada más va a detectar una clave escrita dentro de un
fichero versionado. Explica cómo conseguirlo — mira la entrada de incidencias sobre
gitleaks sin instalar — y sugiere escanear y rehacer el commit antes de empujar si el
proyecto tiene algún historial de credenciales en el código.

**Si gitleaks se ejecuta y encuentra algo, eso es distinto: para.** No commitees. Un
hallazgo aquí significa que el secreto lo publicaría el siguiente comando. Muéstrale al
usuario qué se encontró (redactado), que lo quite del fichero y rote la credencial si
alguna vez fue real, y vuelve a escanear. "No está instalado" es un aviso; "ha encontrado
algo" es un alto en seco.

Solo cuando el escaneo esté limpio (o se haya saltado explícitamente) commiteas:

```bash
git commit -m "chore: initial commit"
```

**Los mensajes de commit van siempre en inglés**, igual que el resto del contenido del
repositorio: este, los del paso 6 y los títulos de PR. Lo que no vale es mezclar: un
historial con mensajes en dos idiomas es la señal de que cada ejecución decidió por su
cuenta. Escribe la descripción en minúscula y en imperativo (`add`, no `adds` ni
`Added`): la configuración por defecto de commitlint rechaza un asunto que empiece en
mayúscula.

`git status` después de `git add -A` es el último punto de control: lista exactamente lo
que el commit inicial va a publicar. Si aparece algo sensible, o falta algo esperado,
arregla el `.gitignore` y vuelve a comprobarlo antes de commitear, no después.

**Si el repositorio no tiene remoto**, créalo y empuja `main`:

```bash
# <visibilidad> es --private o --public, tomado de la respuesta del usuario a la
# comprobación previa 5. Aquí no hay valor por defecto a propósito: si todavía no has
# preguntado, para y pregunta ahora en vez de elegir tú.
gh repo create <nombre> <visibilidad> --source=. --remote=origin
git push -u origin main
```

Este es el punto sin marcha atrás fácil, y por eso la comprobación previa 5 pregunta
antes: en plan Free un repositorio **privado** no puede tener rulesets, así que el paso 7
devolverá `403 Upgrade to GitHub Pro` y el repositorio se queda sin protección de ramas;
y un repositorio **público** publica el commit inicial a cualquiera en el momento en que
se empuja. Las dos opciones son legítimas y las elige el usuario — tu trabajo es haber
preguntado antes de que esta línea se ejecute, no descubrir la consecuencia en el paso 7.

Si el remoto existe pero `main` no tiene upstream: `git push -u origin main`.

#### ⚠️ Revisa `git status` después de `git add -A` y antes del commit

`git add -A` prepara todo lo que no esté ignorado. Sin `.gitignore`, o con uno que perdió
sus entradas en una sobrescritura, eso puede significar `.env`, `*.pem`, claves privadas,
bases de datos locales, conjuntos de datos, grabaciones o pesos de modelos — y el commit
inicial se empuja a un remoto nuevo de inmediato, así que un secreto commiteado aquí es
un secreto publicado. La push protection de GitHub solo detecta formatos de token
reconocibles: no va a parar un `.env`, un fichero SQLite con datos personales ni un
`.wav`.

Por eso el `.gitignore` se resuelve **antes** del commit inicial y viaja dentro de él,
aunque cualquier otra plantilla espere a su propio PR (ver paso 6): es la única que tiene
que estar colocada antes del primer `git add -A` para servir de algo. Y por eso la fusión
de arriba es aditiva: las entradas propias del proyecto están protegiendo datos de los
que la base no sabe nada, así que perderlas es tan grave como no haber tenido base.

### 2. Averiguar el owner/repo de GitHub

```bash
gh repo view --json nameWithOwner --jq .nameWithOwner
```

Guárdalo como `OWNER_REPO` para las llamadas a la API de más adelante.

### 3. Averiguar el usuario de GitHub

```bash
gh api user --jq .login
```

Guárdalo como `GH_USERNAME`. Se usa en CODEOWNERS.

### 4. Crear la rama `develop`

El paso 1 garantiza que `main` existe con un commit. Si `develop` no existe:

```bash
git checkout main
# Solo haz pull si main sigue a un upstream: en un repo arrancado en el paso 1 el
# primer push ya lo dejó puesto, pero `git pull` sin upstream falla directamente.
git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1 && git pull
git checkout -b develop
git push -u origin develop
```

### 5. Copiar las plantillas

Copia el contenido del directorio `templates/` de esta skill a la raíz del proyecto,
conservando la estructura de carpetas. Las plantillas son:

- `.github/PULL_REQUEST_TEMPLATE.md`
- `.github/ISSUE_TEMPLATE/bug_report.md`
- `.github/ISSUE_TEMPLATE/feature_request.md`
- `.github/ISSUE_TEMPLATE/config.yml` — solo desactiva los issues en blanco. No enlaza a
  Discussions a propósito: un repositorio nuevo las tiene desactivadas y el enlace daría
  error
- `.github/CODEOWNERS` — **hay que sustituir el marcador `@OWNER` por `@$GH_USERNAME`**
- `.github/workflows/ci.yml`
- `CONTRIBUTING.md`
- `.gitignore` — **ya resuelto en el paso 1**, que lo copia o lo fusiona antes del commit
  inicial. Aquí no hay nada que hacer; no lo vuelvas a copiar encima del fichero
  fusionado, porque eso tiraría las entradas propias del proyecto.
- `docs/git-cheatsheet.md` — referencia práctica del día a día, para personas y para IAs.
  Va **siempre** en `docs/`: crea la carpeta si no existe. `CONTRIBUTING.md` lo enlaza
  con esa ruta, y el paso 6 la prepara con nombre, así que moverlo rompería las dos
  cosas. Referéncialo también desde `CLAUDE.md` si existe, con una línea en inglés —
  salvo que el usuario haya pedido no tocar ese fichero, o que ya lo enlace.

Si en el proyecto ya existe alguno de estos ficheros (por ejemplo un `CONTRIBUTING.md`
propio), **no lo sobrescribas**: díselo al usuario y pregunta si fusionar, conservar el
suyo o reemplazarlo.

### 6. Commitear y empujar las plantillas vía PR (NO empujes a main directamente)

**El contenido del proyecto y las plantillas de la skill son dos commits separados, en
este orden:**

| Qué | Dónde acaba | Cuándo |
|------|----------------|------|
| El código y los ficheros propios del proyecto | commit inicial en `main` | paso 1 |
| Las plantillas de esta skill (`.github/`, `CONTRIBUTING.md`, `docs/`) | `chore/git-flow-setup` → PR a `develop` | este paso |

Mantenerlos separados es lo que hace que el paso 1 sea obligatorio y no opcional. Este
paso prepara solo rutas con nombre, nunca `git add -A`, así que en un proyecto que ya
tenga código, cualquier fichero no commiteado en el paso 1 se queda sin seguimiento — y
como este paso termina fusionando el PR y borrando la rama, nada saca a la
luz esa omisión. El montaje reporta éxito, el PR está verde, y el código real del
proyecto sigue sin commitear en el árbol de trabajo.

Así que: commitea el contenido del proyecto en el paso 1, y las plantillas aquí. Antes de
abrir este PR, ejecuta `git status` una vez más — cualquier cosa inesperada que siga sin
seguimiento significa que el paso 1 se saltó o quedó a medias.

```bash
git checkout -b chore/git-flow-setup
git add .github CONTRIBUTING.md docs/git-cheatsheet.md
git commit -m "chore: set up Git Flow with PR templates, CI and contributing guide"
git push -u origin chore/git-flow-setup
gh pr create --base develop --title "chore: set up Git Flow" --fill
```

Se preparan las rutas exactas que copió el paso 5, y nada más: `docs/git-cheatsheet.md`
y no `docs/`, para no arrastrar otros ficheros sin seguimiento que el proyecto tuviera
en esa carpeta. Sin esa ruta, la chuleta se quedaría sin seguimiento y no llegaría
nunca al repositorio.

#### Fusionar: siempre con el script, que espera al CI

Este es el primer PR del proyecto, y por tanto la primera vez que el CI se ejecuta de
verdad. **No fusiones con `gh pr merge` a mano.** Usa el script, que espera a que los
checks se registren, espera a que terminen, y solo fusiona si están en verde:

```bash
bash ~/.claude/skills/setup-git-flow/scripts/fusionar-pr.sh <numero> squash
```

Imprime `FUSIONADO` y sale con `0`, o `NO FUSIONADO` con el motivo y sale con `1`. Con
`1` no sigas: si algún check falló, **lee el log antes de tocar nada**, porque puede
fallar por algo que no es lo que parece (ver la entrada de incidencias sobre
`Resource not accessible by integration`).

El script imprime cada check con su resultado: quédate con eso, va al resumen. El CI
solo tiene un check, `Commit messages`.

Después sincroniza develop con main. Fíjate en el método: los PR hacia `develop` van con
squash, pero `develop → main` va con **merge commit** — ver la política de fusión en el
paso 7. Un comando por llamada:

```bash
git checkout develop
git pull
gh pr create --base main --head develop --title "chore: initial Git Flow setup" --fill
bash ~/.claude/skills/setup-git-flow/scripts/fusionar-pr.sh <numero> merge
```

### 7. Configurar GitHub: rulesets y seguridad

Un único script aplica los rulesets de `main` y `develop` y activa Dependabot y el secret
scanning. Lee él mismo la visibilidad del repositorio:

```bash
bash ~/.claude/skills/setup-git-flow/scripts/configurar-github.sh
```

Cada línea sale como `OK`, `NO DISPONIBLE` o `FALLO`:

- **`NO DISPONIBLE` no es un fallo.** En un repositorio privado con plan Free, los
  rulesets devuelven `403` y el secret scanning `422`. Es consecuencia de la visibilidad
  que eligió el usuario en la comprobación previa 5: no se rodea, no se vuelve a preguntar
  y no se ofrece hacer público el repositorio. Los rulesets van al resumen como
  **pendientes, con ese motivo**, y gitleaks en local es la compensación del escaneo.
- **`FALLO`** es un error de verdad: el repositorio no existe, al token le faltan
  permisos, o GitHub rechazó el JSON de un ruleset. Sale con `1`: no sigas sin
  resolverlo. El script solo clasifica un error como `NO DISPONIBLE` si el repositorio
  no es público **y** GitHub responde con su mensaje de plan; un `403` o `422` a secas
  es `FALLO`, para que un problema real no se disfrace de limitación del plan.

Se puede reejecutar sin miedo: si un ruleset con el mismo nombre ya existe, no lo
duplica.

Los rulesets usan `actor_id: 5` (rol de administrador) con `bypass_mode: pull_request`:
los administradores siguen pasando por PR, pero pueden fusionar ellos mismos.

**Política de fusión (los dos rulesets permiten squash y merge commit, así que la regla
es una convención, no algo impuesto — `CONTRIBUTING.md` es la fuente de verdad):**

| PR | Método |
|----|--------|
| `feat/*`, `fix/*`, `chore/*`, `docs/*` → `develop` | `fusionar-pr.sh <n> squash` |
| `develop` → `main` (release) | `fusionar-pr.sh <n> merge` |

`main` deliberadamente **no** tiene la regla `required_linear_history`: esa regla prohíbe
los merge commits, así que mantenerla permitiendo a la vez el método merge sería
contradictorio — GitHub mostraría el botón y después rechazaría la fusión. Los releases
entran como merge commits para que los commits de `develop` pasen a ser ancestros de
`main`; hacer squash de `develop → main` separa las dos historias y hace que cada PR de
release posterior vuelva a listar todo lo anterior.

### 8. Documentar el montaje

Si el proyecto tiene `CLAUDE.md` y/o `docs/progress.md`, actualízalos, **en inglés**, con:
- Un resumen de la estrategia de ramas (o una referencia a `CONTRIBUTING.md`).
- Que la protección de ramas está activa en `main` y `develop`, o pendiente y por qué.
- La fecha del montaje.

Si el usuario ha pedido no tocar alguno de esos ficheros, respétalo y no lo edites: deja
constancia en otro sitio (un issue sirve, y persiste sin añadir ficheros al árbol) y dilo
en el resumen. Si no hay documentación ninguna, deja `CONTRIBUTING.md` como fuente de
verdad.

## Cierre: primero la auditoría, después el resumen

Al final pasan dos cosas, en este orden. La auditoría va primera, porque el resumen tiene
que reportar lo que la auditoría **encontró**, no lo que los pasos pretendían conseguir.

### A. Auditoría de cierre: demostrar que nada quedó a medias

**No escribas el resumen de memoria, a partir de los comandos que ejecutaste.** Un
montaje que *casi* termina es el peor resultado posible: reporta éxito, y lo que quedó
colgando —un PR todavía abierto, una rama nunca empujada, un commit que no salió de la
máquina— aparece días después delante de alguien que se fió del informe.

Esto no se comprueba a ojo. Hay un script que lo hace, y lo que manda es su **código de
salida**:

```bash
bash ~/.claude/skills/setup-git-flow/scripts/auditar-cierre.sh
```

| Código | Significa | Qué hacer |
|---|---|---|
| `0` | imprime `CERRADO` | puedes escribir el resumen |
| `1` | imprime `PENDIENTE` y qué falta | **no reportes el montaje como completo** |

Ejecútalo desde la raíz del proyecto; si lo lanzas desde un subdirectorio se niega y te
dice por qué. Hace `git fetch --prune` él mismo, porque con refs remotas viejas la mitad
de las comprobaciones mienten.

Comprueba siete cosas: árbol de trabajo limpio, ninguna rama con commits sin empujar ni
sin upstream, `main` y `develop` en el remoto, `develop` sincronizada con `main`, ningún
PR del montaje abierto, la rama temporal del montaje eliminada en local y en remoto, y
todas las etiquetas locales subidas.

"PR del montaje" son los que salen de `chore/git-flow-setup` y el de `develop` hacia
`main`. Los demás PR abiertos (los de Dependabot, que el paso 7 activa, o los que ya
tuviera un repositorio existente) salen como aviso `?` y no bloquean el cierre:
menciónalos en el resumen, pero no son trabajo a medias.

**Si sale `1`, no te calles y no sigas por tu cuenta.** Di exactamente qué falta —el
script ya lo lista— y **pide permiso para terminarlo**:

> El PR #2 sigue abierto y `develop` tiene 1 commit sin promocionar a `main`.
> ¿Quieres que lo termine yo?

Si el usuario dice que sí, termínalo y **vuelve a ejecutar el script** antes de escribir
el resumen: lo que reportas es la segunda pasada, no la primera.

Hay un caso que el script no cubre a propósito, porque no es estado de git: los rulesets
saltados en un repositorio privado con plan Free. Eso es una decisión que el usuario tomó
en la comprobación previa 5, así que va al resumen como pendiente **con su motivo**,
nunca como algo que salió mal.

### B. El resumen, en español

**Escribe el resumen final en español**, siempre, salvo que el usuario pida
explícitamente otro idioma. Mantén en su forma original los nombres de comandos, de
ramas, las rutas de ficheros y los nombres de los checks: son identificadores, no prosa.

Cubre todos los puntos de abajo. Si alguno no aplica, dilo en vez de omitirlo, para que
la forma del informe sea la misma en cada ejecución y nada pueda desaparecer sin que se
note:

- **Repositorio**: URL, y su visibilidad — diciendo que la eligió el usuario, no la
  skill.
- **Ramas**: `main` y `develop`, y que las dos existen en el remoto.
- **Qué llevó el commit inicial**: la lista de ficheros, no "los ficheros del proyecto".
- **Plantillas y ficheros creados**: `.github/`, `CONTRIBUTING.md`,
  `docs/git-cheatsheet.md`.
- **CI**: que se ejecutó, y qué reportó `Commit messages` en cada PR. Recuerda que el CI
  es independiente del stack a propósito: cuando el proyecto tenga código, habrá que
  añadirle sus propios jobs y marcarlos como requeridos en los rulesets.
- **Rulesets**: aplicados, o pendientes con el motivo.
- **Seguridad**: qué quedó activo y qué no está disponible en ese plan.
- **gitleaks**: que se ejecutó y qué devolvió — o, si no estaba instalado, que el commit
  inicial fue **sin escanear**, dicho claramente.
- **Política de fusión**: squash hacia `develop`, merge commit de `develop` a `main`.
- **Atribución de IA**: que ningún commit ni PR lleva marca de Claude, comprobado con el
  `git log` de la sección inicial.
- **Qué falló, se saltó o necesitó improvisación**: siempre presente. Si no hubo nada,
  decir que no hubo nada.
- **Resultado de la auditoría**: que no queda nada pendiente, o qué queda y qué has
  preguntado sobre ello.

## Opciones que conviene considerar

Al invocar esta skill el usuario puede querer variaciones. Pregunta si no está claro:
- **Modo de un solo desarrollador** frente a equipo: con una sola persona,
  `required_approving_review_count: 0` (el valor por defecto). En equipo, ponlo a 1 o
  más.
- **CI estricto** frente a permisivo: los rulesets exigen por defecto `Commit messages`.
  Si el usuario quiere fusiones permisivas, quita la regla `required_status_checks` del
  JSON del ruleset antes de aplicarlo. Si renombras el job en `ci.yml`, actualiza el
  `context` en los dos rulesets: el context es el `name` del job, no su id, y un context
  que nunca reporta bloquea todos los PR. Lo mismo vale para los jobs que el proyecto
  añada más adelante: no basta con crearlos, hay que listarlos en los rulesets si
  tienen que ser obligatorios.
- **Revisión en `main`**: el ruleset de `main` exige resolver las conversaciones del PR
  y el de `develop` no. `CONTRIBUTING.md` lo documenta en una tabla: si cambias una
  regla de un ruleset, cambia también esa tabla.
- **Nivel de detalle de la plantilla de PR**: por defecto es intermedio. Algunos equipos
  prefieren algo mínimo.

## Incidencias

- **"Upgrade to GitHub Pro"** al aplicar los rulesets → el repositorio es privado con
  plan Free, que es exactamente lo que avisaba la comprobación previa 5. Salta el paso y
  registra los rulesets como pendientes. **No** ofrezcas volver el repositorio público
  para pasar por encima: esa decisión ya estaba tomada, y hacerlo público publica todos
  los commits ya empujados. Solo se revisa si lo plantea el usuario.
- **La fusión del PR falla después de aplicar los rulesets** → asegúrate de que
  `bypass_actors` tiene la entrada de administrador; si no, ni el propio dueño puede
  fusionar.
- **PR atascado en "Expected — Waiting for status to be reported"** → un context
  requerido no se ejecutó nunca. Casi siempre es un `if` a nivel de job (el job se salta,
  así que no reporta nada) o un job renombrado sin actualizar el context del ruleset.
- **`Commit messages` falla con `Resource not accessible by integration`** → no es un
  mensaje de commit mal formado. `wagoid/commitlint-github-action` pide a la API la lista
  de commits del PR, y el `GITHUB_TOKEN` por defecto solo trae `contents`, así que la
  llamada se rechaza y el job muere *antes* de validar nada. Por eso el job de `ci.yml`
  lleva un permiso explícito:

  ```yaml
  permissions:
    contents: read
    pull-requests: read
  ```

  Si lo vuelves a ver, comprueba que ese bloque sigue ahí, y mira el valor por defecto
  del repositorio con `gh api repos/$OWNER_REPO/actions/permissions/workflow`: una
  organización o un repositorio con permisos de workflow en solo lectura es la causa
  habitual.

  **Por qué el `lint-templates.yml` de este repositorio no puede detectarlo.** actionlint
  lee el workflow como *documento*: sintaxis, validez de las expresiones, etiquetas de
  runner, shellcheck sobre los bloques `run:`. Un job sin bloque `permissions:` es YAML
  perfectamente válido y Actions perfectamente válido — no hay nada malformado que
  reportar. Lo que falla es la **autorización en tiempo de ejecución**, que depende del
  token que un repositorio concreto entrega al job, y eso solo existe cuando un PR real
  se ejecuta en un repositorio real. La plantilla viaja en este repositorio pero nunca se
  ejecuta aquí, así que toda una clase de defectos —cualquiera que solo aparezca al
  ejecutar— es invisible a los checks de este repo y sale en el primer proyecto donde se
  aplica la skill. Trata el primer PR de un montaje nuevo como parte de la superficie de
  prueba, y lee lo que los checks reportan de verdad en vez de dar por hecho que unas
  plantillas verdes implican una tubería verde.
- **`gh: command not found`** → después de instalarlo puede hacer falta una sesión nueva
  de terminal, o el PATH explícito:
  `export PATH="/c/Program Files/GitHub CLI:$PATH"`.
- **gitleaks sin instalar** → el commit inicial del paso 1 entra **sin escaneo de
  contenido**, y el `.gitignore` no cubre ese hueco: ningún patrón de nombre detiene una
  clave de API escrita dentro de un `config.py` de nombre legítimo. Esto nunca aborta el
  montaje, pero hay que decirlo en voz alta en vez de pasarlo por alto.

  Instálalo como binario de release: es un único ejecutable estático, sin cadena de
  compilación y sin pasos de construcción.

  ```bash
  brew install gitleaks        # macOS / Linuxbrew
  winget install gitleaks      # Windows
  # o baja un binario de github.com/gitleaks/gitleaks/releases y ponlo en el PATH
  ```

  Confírmalo con `gitleaks version` y después escanea de forma retroactiva:

  ```bash
  gitleaks git --redact --verbose    # todo el historial, no solo lo preparado
  ```

  Si eso saca algo ya commiteado, la solución es rotar la credencial: reescribir el
  historial no despublica lo que ya se empujó.
