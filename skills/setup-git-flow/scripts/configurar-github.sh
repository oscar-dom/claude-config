#!/usr/bin/env bash
# Configura en GitHub los ajustes, la seguridad y los rulesets del repositorio.
#
# Uso:   bash ~/.claude/skills/setup-git-flow/scripts/configurar-github.sh [owner/repo]
#        (sin argumento, usa el repo del directorio actual)
#
# Salida: 0 si todo lo disponible quedo aplicado, 1 si algo fallo de verdad.
#
# Los endpoints estan fijos aqui dentro. Por eso basta con conceder permiso a los
# scripts de la skill: un permiso generico tipo `gh api -X PATCH repos/<owner>/*`
# permitiria cualquier PATCH en cualquier repo, incluido hacerlo publico.
#
# Lo que el plan no permite (403/422 en privado sin plan de pago) NO es un fallo:
# se informa como "no disponible" y el script sigue.
#
# Se puede reejecutar: los ajustes se reescriben con los mismos valores y un
# ruleset que ya existe se actualiza en su sitio, sin duplicarlo.

set -u
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="${1:-$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null)}"
[ -n "$REPO" ] || { echo "No se pudo determinar el repositorio"; exit 1; }

FALLOS=0
VIS=$(gh repo view "$REPO" --json visibility --jq .visibility 2>/dev/null)
# Sin esto, un nombre de repo equivocado daria 404 en todo y saldria como exito.
[ -n "$VIS" ] || { echo "FALLO: el repositorio $REPO no existe o no es accesible"; exit 1; }
echo "Configurando $REPO (visibilidad: $VIS)"
echo "==================="

# Un error solo cuenta como limite del plan si el repo NO es publico y GitHub lo
# dice con su mensaje de plan. Un 403 o 422 a secas no basta: GitHub devuelve 422
# tambien para un ruleset con JSON invalido, y 403 cuando al token le faltan
# permisos. Clasificar eso como "no disponible" dejaria el repo sin proteccion y
# el resumen culparia al plan.
es_limite_de_plan() {
  [ "$VIS" != "PUBLIC" ] || return 1
  printf '%s' "$1" | grep -qiE 'Upgrade to GitHub Pro|make this repository public|not available for this repository|Advanced Security|Secret Protection'
}

# Ejecuta una llamada y la clasifica: OK, NO DISPONIBLE (plan) o FALLO.
llamar() {
  etiqueta="$1"; shift
  salida=$(gh api "$@" 2>&1); codigo=$?
  if [ $codigo -eq 0 ]; then
    printf '  OK            %s\n' "$etiqueta"
  elif es_limite_de_plan "$salida"; then
    printf '  NO DISPONIBLE %s (el plan o la visibilidad no lo permiten)\n' "$etiqueta"
  else
    printf '  FALLO         %s\n' "$etiqueta"
    printf '%s\n' "$salida" | head -3 | sed 's/^/                /'
    FALLOS=$((FALLOS + 1))
  fi
}

# 1. Ajustes de fusion: funcionan en TODOS los planes, privados gratuitos
#    incluidos, porque son del repositorio y no de los rulesets. En un privado
#    Free son lo unico que GitHub impone de verdad.
#    - Solo squash y merge commit; rebase merge desactivado.
#    - El commit de squash y el merge commit toman el titulo del PR: el titulo
#      convencional que valida el CI es el que queda en el historial, no el
#      primer commit de la rama ni "Merge pull request #N".
#    - El cuerpo va vacio (BLANK). La descripcion del PR sigue la plantilla
#      (casillas, comentarios, "Closes #") y meterla en el commit llenaria el
#      historial de relleno. El contexto sigue en el PR, enlazado por el (#N)
#      que GitHub anade al titulo del squash.
#    - Las ramas se borran solas al fusionar. GitHub nunca borra la rama por
#      defecto (develop) ni una rama protegida.
llamar "ajustes de fusion (squash + merge commit, titulo del PR sin cuerpo, borrar ramas)" \
  -X PATCH "repos/$REPO" --silent \
  -F allow_squash_merge=true \
  -F allow_merge_commit=true \
  -F allow_rebase_merge=false \
  -F delete_branch_on_merge=true \
  -f squash_merge_commit_title=PR_TITLE \
  -f squash_merge_commit_message=BLANK \
  -f merge_commit_title=PR_TITLE \
  -f merge_commit_message=BLANK

# 2. develop como rama por defecto: los PR apuntan ahi sin --base, y nadie abre
#    por error un PR contra main.
if gh api "repos/$REPO/branches/develop" --silent >/dev/null 2>&1; then
  llamar "rama por defecto: develop" -X PATCH "repos/$REPO" --silent -f default_branch=develop
else
  printf '  FALLO         rama por defecto: develop no existe en el remoto\n'
  FALLOS=$((FALLOS + 1))
fi

# 3. Seguridad.
llamar "alertas de vulnerabilidades (Dependabot)" -X PUT "repos/$REPO/vulnerability-alerts" --silent
llamar "parches automaticos (Dependabot)"         -X PUT "repos/$REPO/automated-security-fixes" --silent
llamar "secret scanning y push protection"        -X PATCH "repos/$REPO" --silent \
  -f 'security_and_analysis[secret_scanning][status]=enabled' \
  -f 'security_and_analysis[secret_scanning_push_protection][status]=enabled'

# 4. Rulesets: se crean, o se actualizan si ya existe uno con el mismo nombre.
#    Actualizar (y no saltar) hace que reejecutar el script en un repo montado
#    con una version anterior de la skill le aplique las reglas nuevas.
EXISTENTES=$(gh api "repos/$REPO/rulesets" --jq '.[] | "\(.id)\t\(.name)"' 2>&1); cod=$?
if [ $cod -ne 0 ] && es_limite_de_plan "$EXISTENTES"; then
  echo "  NO DISPONIBLE rulesets de proteccion (necesitan repo publico o plan de pago)"
  echo "                va al resumen como PENDIENTE, con este motivo"
elif [ $cod -ne 0 ]; then
  printf '  FALLO         no se pudieron listar los rulesets\n'
  printf '%s\n' "$EXISTENTES" | head -3 | sed 's/^/                /'
  FALLOS=$((FALLOS + 1))
else
  for f in "$SKILL_DIR"/rulesets/*.json; do
    nombre=$(sed -n 's/.*"name": *"\([^"]*\)".*/\1/p' "$f" | head -1)
    id=$(printf '%s\n' "$EXISTENTES" | awk -F '\t' -v n="$nombre" '$2 == n { print $1; exit }')
    if [ -n "$id" ]; then
      llamar "ruleset \"$nombre\" (actualizado)" -X PUT "repos/$REPO/rulesets/$id" --input "$f" --silent
    else
      llamar "ruleset \"$nombre\"" -X POST "repos/$REPO/rulesets" --input "$f" --silent
    fi
  done
fi

echo "==================="
if [ "$FALLOS" -eq 0 ]; then
  echo "HECHO: todo lo disponible en este plan quedo aplicado."
  exit 0
fi
echo "CON FALLOS: $FALLOS llamada(s) fallaron por un motivo distinto del plan."
exit 1
