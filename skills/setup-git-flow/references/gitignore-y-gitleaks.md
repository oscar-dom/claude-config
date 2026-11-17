# `.gitignore`, `.gitattributes` y gitleaks en el commit inicial

Detalle del paso 1 de `SKILL.md`. Todo esto pasa **antes** del primer `git add -A`,
porque el commit inicial se empuja de inmediato a un remoto nuevo: lo que entre ahí
queda publicado.

## `.gitignore`: copiar o FUSIONAR, nunca sobrescribir

**Si el proyecto no tiene `.gitignore`:** copia `templates/.gitignore`.

**Si ya tiene uno: FUSIONA.** Un `.gitignore` existente suele ser lo único que mantiene
los datos personales fuera del repositorio: conjuntos de datos locales, bases de datos
SQLite, grabaciones, pesos de modelos, contenido descargado. Sobrescribirlo con la base
de la skill vuelve a exponer todo eso en el primer commit. Mantén el fichero del
proyecto como base y añade solo los patrones de la skill que falten:

```bash
# La copia base va FUERA del repositorio: un .gitignore.bak dejado en el árbol lo
# recoge el `git add -A` y acaba commiteado.
#
# El `tr -d '\r'` en AMBOS lados es funcional: si una plantilla está en CRLF y el
# .gitignore del proyecto en LF, cada patrón arrastra un \r final, `grep -qxF` no
# encuentra nunca coincidencia y se añade la base entera, duplicados incluidos.
BASE=$(mktemp) && tr -d '\r' < .gitignore > "$BASE"

{ echo ""; echo "# ===== added by setup-git-flow ====="; } >> .gitignore
tr -d '\r' < ~/.claude/skills/setup-git-flow/templates/.gitignore | while IFS= read -r line; do
  [ -z "$line" ] && continue
  case "$line" in \#*) continue;; esac
  grep -qxF -- "$line" "$BASE" || echo "$line" >> .gitignore
done

rm -f "$BASE"
```

No reescribe ni reordena ninguna línea existente. Dos avisos: si **cualquiera** de los
dos ficheros usa negaciones (`!foo`), el orden decide el resultado y hay que fusionar a
mano; y revisa casi-duplicados (la base trae `Thumbs.db` y el proyecto puede tener
`*.db`): son inofensivos, solo ruido.

**Si el usuario eligió Claude Code como gestor**, añade también (si faltan) los dos
ficheros personales de Claude, que nunca se versionan:

```
.claude/settings.local.json
CLAUDE.local.md
```

Van aquí, antes del commit inicial, y no en el paso de plantillas: si el proyecto ya
tiene un `.claude/settings.local.json` con permisos personales, el `git add -A` del
commit inicial lo publicaría.

La base es independiente del stack: secretos, sistema operativo, ficheros de
intercambio de editores y registros. Si el proyecto ya tiene código, mira qué genera
(dependencias, salidas de compilación, cachés, datos locales) y **pregunta** antes de
añadir esas entradas.

**Verifica con git, no leyendo el fichero:**

```bash
# Deben salir como ignoradas: las rutas sensibles reales del proyecto y los secretos.
git check-ignore -v .env private.pem id_rsa datos/x.db
# Y al revés: lo que DEBE versionarse no imprime nada.
git check-ignore -v README.md .env.example
```

## `.gitattributes` y `.editorconfig`

- **Repositorio sin commits:** copia `templates/.gitattributes` antes del `git add -A`,
  para que el commit inicial ya entre normalizado. `.editorconfig` puede ir aquí también
  o en el PR de plantillas.
- **Repositorio con historial:** van en el PR de plantillas (paso 6). No ejecutes
  `git add --renormalize .`: reescribiría los finales de línea de todo el proyecto en
  un único diff gigante. Los ficheros se normalizan solos cuando se vuelvan a tocar.
- **Si el proyecto ya tiene uno de los dos:** no lo toques. Es una decisión del
  proyecto; dilo en el resumen.

## gitleaks: escanear lo preparado antes del commit

`.gitignore` y gitleaks protegen del mismo accidente desde dos ángulos, y ninguno
cubre al otro:

| | Busca por | Detecta | No ve |
|---|---|---|---|
| `.gitignore` | **nombre / ruta** | `.env`, `*.pem`, `datos/`, `id_rsa` | una clave escrita *dentro* de `config.py` |
| gitleaks | **contenido** | `AWS_SECRET = "AKIA…"` en la línea 40 | nada sobre nombres |

```bash
gitleaks git --staged --redact --verbose
```

`--redact` mantiene el secreto fuera de la terminal y de los registros. Sin
`gitleaks git`, `gitleaks dir . --redact --verbose` escanea el árbol de trabajo.

- **No está instalado:** dilo y **continúa**; nunca abortes el montaje por eso. Pero
  dilo en voz alta aquí y en el resumen: el commit inicial entró **sin escaneo de
  contenido**. Instalación: `winget install gitleaks` (Windows), `brew install gitleaks`
  (macOS/Linux), o un binario de github.com/gitleaks/gitleaks/releases.
- **Encuentra algo: PARA.** No commitees. Enseña el hallazgo (redactado), que el
  usuario quite el secreto y rote la credencial si alguna vez fue real, y vuelve a
  escanear. "No está instalado" es un aviso; "ha encontrado algo" es un alto en seco.

Escaneo retroactivo de todo el historial, si se instala más tarde:
`gitleaks git --redact --verbose`. Si saca algo ya empujado, la solución es rotar la
credencial: reescribir el historial no despublica lo que ya se publicó.

## ⚠️ `git status` después de `git add -A`

Es el último punto de control: lista exactamente lo que el commit inicial va a
publicar. La push protection de GitHub solo detecta formatos de token conocidos: no
para un `.env`, un SQLite con datos personales ni un `.wav`. Si aparece algo sensible o
falta algo esperado, arregla el `.gitignore` y vuelve a comprobarlo **antes** del
commit.
