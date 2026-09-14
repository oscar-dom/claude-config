#!/usr/bin/env bash
# Configura en GitHub la seguridad y los rulesets del repositorio.
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
# Lo que el plan no permite (403/422 en privado con plan Free) NO es un fallo:
# se informa como "no disponible" y el script sigue.

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

# Ejecuta una llamada y la clasifica: OK, NO DISPONIBLE (plan) o FALLO.
llamar() {
  etiqueta="$1"; shift
  salida=$(gh api "$@" 2>&1); codigo=$?
  if [ $codigo -eq 0 ]; then
    printf '  OK            %s\n' "$etiqueta"
  elif printf '%s' "$salida" | grep -qE 'HTTP 403|HTTP 422|Upgrade to GitHub Pro|not available'; then
    printf '  NO DISPONIBLE %s (el plan o la visibilidad no lo permiten)\n' "$etiqueta"
  else
    printf '  FALLO         %s\n' "$etiqueta"
    printf '%s\n' "$salida" | head -3 | sed 's/^/                /'
    FALLOS=$((FALLOS + 1))
  fi
}

llamar "alertas de vulnerabilidades (Dependabot)" -X PUT "repos/$REPO/vulnerability-alerts" --silent
llamar "parches automaticos (Dependabot)"         -X PUT "repos/$REPO/automated-security-fixes" --silent
llamar "secret scanning y push protection"        -X PATCH "repos/$REPO" --silent \
  -f 'security_and_analysis[secret_scanning][status]=enabled' \
  -f 'security_and_analysis[secret_scanning_push_protection][status]=enabled'

# Rulesets: solo se crean si no existe ya uno con el mismo nombre, para que
# reejecutar el script no los duplique.
EXISTENTES=$(gh api "repos/$REPO/rulesets" --jq '.[].name' 2>&1); cod=$?
if [ $cod -ne 0 ] && printf '%s' "$EXISTENTES" | grep -qE 'HTTP 403|Upgrade to GitHub Pro'; then
  echo "  NO DISPONIBLE rulesets de proteccion (necesitan repo publico o GitHub Pro)"
  echo "                va al resumen como PENDIENTE, con este motivo"
else
  for f in "$SKILL_DIR"/rulesets/*.json; do
    nombre=$(sed -n 's/.*"name": *"\([^"]*\)".*/\1/p' "$f" | head -1)
    if printf '%s\n' "$EXISTENTES" | grep -qxF "$nombre"; then
      printf '  OK            ruleset "%s" (ya existia, no se duplica)\n' "$nombre"
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
