#!/usr/bin/env bash
# Fusiona un PR SOLO si su CI ha terminado en verde.
#
# Uso:   bash ~/.claude/skills/setup-git-flow/scripts/fusionar-pr.sh <numero> <squash|merge>
#          squash -> feature hacia develop (borra la rama)
#          merge  -> develop hacia main (merge commit)
#
# Salida: 0 fusionado, 1 no fusionado (CI rojo, sin checks, o error).
#
# Existe como script, y no como dos comandos sueltos, por dos motivos: obliga a
# leer el CI antes de fusionar, y permite conceder UN permiso a los scripts de la
# skill en vez de `gh pr merge` en cualquier repo.

set -u

# Todo va dentro de main(): bash lee la funcion entera antes de ejecutarla. Sin
# esto, al fusionar con --delete-branch gh cambia de rama, el fichero del script
# puede cambiar o desaparecer a mitad de ejecucion y bash leeria basura.
main() {
PR="${1:-}"
MODO="${2:-}"
ESPERA_MAX=300   # segundos esperando a que aparezcan los checks

case "$MODO" in squash|merge) ;; *)
  echo "Uso: fusionar-pr.sh <numero> <squash|merge>"; exit 1;;
esac
[ -n "$PR" ] || { echo "Falta el numero de PR"; exit 1; }

# Justo despues de abrir el PR los checks aun no existen, y "no hay checks" NO
# significa "han terminado". Se cuenta cuantos hay, sin depender del texto.
echo "PR #$PR: esperando a que se registren los checks..."
t=0
while :; do
  # gh sale con 8 mientras hay checks pendientes: no se usa su codigo de salida,
  # solo el numero que imprime (con `|| echo 0` se colaria un "0" extra).
  n=$(gh pr checks "$PR" --json name --jq 'length' 2>/dev/null | head -1 | tr -dc '0-9')
  n=${n:-0}
  [ "$n" -gt 0 ] && break
  if [ "$t" -ge "$ESPERA_MAX" ]; then
    echo "NO FUSIONADO: tras ${ESPERA_MAX}s el PR sigue sin checks."
    echo "Comprueba que .github/workflows/ci.yml existe en la rama."
    exit 1
  fi
  sleep 5; t=$((t + 5))
done

echo "PR #$PR: $n check(s). Esperando a que terminen..."
if ! gh pr checks "$PR" --watch --interval 10 >/dev/null 2>&1; then
  echo "NO FUSIONADO: algun check ha fallado."
  gh pr checks "$PR" 2>/dev/null | sed 's/^/  /'
  echo "Lee el log antes de tocar nada: el fallo puede no ser lo que parece."
  exit 1
fi

echo "Checks del PR #$PR:"
gh pr checks "$PR" --json name,bucket --jq '.[] | "  \(.bucket)\t\(.name)"'

if [ "$MODO" = "squash" ]; then
  gh pr merge "$PR" --squash --admin --delete-branch || { echo "NO FUSIONADO: fallo gh pr merge"; exit 1; }
else
  gh pr merge "$PR" --merge --admin || { echo "NO FUSIONADO: fallo gh pr merge"; exit 1; }
fi

ESTADO=$(gh pr view "$PR" --json state --jq .state 2>/dev/null)
if [ "$ESTADO" = "MERGED" ]; then
  echo "FUSIONADO: PR #$PR ($MODO)"
  exit 0
fi
echo "NO FUSIONADO: el PR #$PR esta en estado $ESTADO"
exit 1
}

main "$@"
