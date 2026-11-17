#!/usr/bin/env bash
# Renombra la rama principal de un repositorio existente (master, trunk...) a
# main, en GitHub y en local. Solo se ejecuta con el permiso del usuario: lo
# decide la comprobacion previa 4 de la skill.
#
# Uso:   bash ~/.claude/skills/setup-git-flow/scripts/renombrar-rama-principal.sh <rama-actual>
#
# Salida: 0 si main queda como rama principal, 1 si no.
#
# En GitHub usa el endpoint de renombrado, no "crear main y borrar master": asi
# GitHub reapunta los PR abiertos, mantiene la proteccion de la rama, la cambia
# de rama por defecto si lo era y redirige las URL antiguas. Los clones de otras
# personas siguen funcionando hasta que hagan `git branch -m` (GitHub se lo
# indica al entrar en el repo).

set -u

ANTIGUA="${1:-}"
[ -n "$ANTIGUA" ] || { echo "Uso: renombrar-rama-principal.sh <rama-actual>"; exit 1; }
[ "$ANTIGUA" != "main" ] || { echo "La rama ya se llama main: nada que hacer"; exit 0; }

# Sin esta comprobacion, un main ya existente se pisaria o el renombrado fallaria
# a medias (renombrada en GitHub, no en local).
if git show-ref --verify --quiet refs/heads/main; then
  echo "NO RENOMBRADA: ya existe una rama main local. Decide con el usuario cual se queda."
  exit 1
fi

if git remote get-url origin >/dev/null 2>&1; then
  REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null)
  [ -n "$REPO" ] || { echo "NO RENOMBRADA: no se pudo determinar el repositorio de origin"; exit 1; }

  if gh api "repos/$REPO/branches/main" --silent >/dev/null 2>&1; then
    echo "NO RENOMBRADA: $REPO ya tiene una rama main en GitHub. Decide con el usuario cual se queda."
    exit 1
  fi

  if gh api "repos/$REPO/branches/$ANTIGUA" --silent >/dev/null 2>&1; then
    if ! SALIDA=$(gh api -X POST "repos/$REPO/branches/$ANTIGUA/rename" -f new_name=main --silent 2>&1); then
      echo "NO RENOMBRADA: GitHub rechazo el renombrado de $ANTIGUA"
      printf '%s\n' "$SALIDA" | head -3 | sed 's/^/  /'
      exit 1
    fi
    echo "  OK    $REPO: $ANTIGUA renombrada a main en GitHub"
  else
    echo "  ?     $ANTIGUA no existe en GitHub: solo se renombra en local"
  fi
  git fetch --quiet --prune origin
fi

if git show-ref --verify --quiet "refs/heads/$ANTIGUA"; then
  git branch -m "$ANTIGUA" main || { echo "NO RENOMBRADA: fallo git branch -m"; exit 1; }
  echo "  OK    $ANTIGUA renombrada a main en local"
fi

if git show-ref --verify --quiet refs/remotes/origin/main; then
  git branch --set-upstream-to=origin/main main >/dev/null
  git remote set-head origin --auto >/dev/null 2>&1
  echo "  OK    main sigue a origin/main"
fi

git show-ref --verify --quiet refs/heads/main || { echo "NO RENOMBRADA: no hay rama main local"; exit 1; }
echo "RENOMBRADA: la rama principal es main"
exit 0
