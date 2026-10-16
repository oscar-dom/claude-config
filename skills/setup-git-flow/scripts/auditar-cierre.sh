#!/usr/bin/env bash
# Auditoria de cierre de setup-git-flow.
#
# Comprueba que no queda nada a medias: ni commits sin empujar, ni ramas sin
# upstream, ni PR abiertos, ni promociones pendientes, ni etiquetas sin subir.
#
# Uso:   bash auditar-cierre.sh [rama-temporal]
#        (rama-temporal por defecto: chore/git-flow-setup)
#
# Salida: 0 si todo esta cerrado, 1 si queda algo. Lo que importa es el codigo
# de salida: un 1 no se puede narrar como exito.

set -u

TEMPORAL="${1:-chore/git-flow-setup}"
FALLOS=0

ok()    { printf '  OK    %s\n' "$1"; }
falta() { printf '  FALTA %s\n' "$1"; FALLOS=$((FALLOS + 1)); }
aviso() { printf '  ?     %s\n' "$1"; }

echo "Auditoria de cierre"
echo "==================="

# Tiene que ser un repo, y la raiz tiene que ser este directorio.
RAIZ=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "  FALTA esto no es un repositorio git"
  exit 1
}
# No se comparan rutas: en Windows el mismo directorio puede tener dos formas
# validas (C:/... frente a /c/..., y el temp aparece tambien como /tmp), asi que
# comparar cadenas da falsos positivos. --show-prefix devuelve la ruta relativa a
# la raiz del repo: vacia significa "estoy en la raiz", y no vacia cubre los dos
# casos malos a la vez, estar en un subdirectorio y estar dentro del repo de otro.
PREFIJO=$(git rev-parse --show-prefix 2>/dev/null)
if [ -n "$PREFIJO" ]; then
  echo "  FALTA la auditoria debe ejecutarse en la raiz del repositorio"
  echo "        raiz del repo:   $RAIZ"
  echo "        estas dentro de: $PREFIJO"
  echo "        si no esperabas esa raiz, este proyecto cuelga del repo de otro"
  exit 1
fi

# Sin esto, las refs remotas estan viejas y los checks 3, 4, 6 y 7 mienten.
git fetch --quiet --prune 2>/dev/null || aviso "no se pudo hacer fetch: las refs remotas pueden estar viejas"

# 1. Arbol de trabajo limpio
if [ -z "$(git status --porcelain)" ]; then
  ok "1. arbol de trabajo limpio"
else
  falta "1. hay cambios sin commitear:"
  git status --short | sed 's/^/        /'
fi

# 2. Ningun commit local sin empujar, en NINGUNA rama.
#    Se mira tambien el upstream: %(upstream:track) sale vacio tanto para una
#    rama sincronizada como para una que no tiene upstream, asi que una rama
#    nunca empujada se colaria como limpia.
PROBLEMAS=""
while IFS='|' read -r rama upstream track; do
  [ -z "$rama" ] && continue
  if [ -z "$upstream" ]; then
    PROBLEMAS="${PROBLEMAS}        $rama: sin upstream, nunca se ha empujado\n"
  elif printf '%s' "$track" | grep -q 'ahead'; then
    PROBLEMAS="${PROBLEMAS}        $rama: $track\n"
  fi
done <<< "$(git for-each-ref --format='%(refname:short)|%(upstream:short)|%(upstream:track)' refs/heads)"
if [ -z "$PROBLEMAS" ]; then
  ok "2. ninguna rama con commits sin empujar"
else
  falta "2. hay commits que no han llegado al remoto:"
  printf '%b' "$PROBLEMAS"
fi

# 3. main y develop existen en el remoto
for r in main develop; do
  if git ls-remote --exit-code --heads origin "$r" >/dev/null 2>&1; then
    ok "3. $r existe en el remoto"
  else
    falta "3. $r NO existe en el remoto"
  fi
done

# 4. develop sin promocionar a main
if git rev-parse --verify --quiet origin/main >/dev/null && git rev-parse --verify --quiet origin/develop >/dev/null; then
  N=$(git rev-list --count origin/main..origin/develop)
  if [ "$N" = "0" ]; then
    ok "4. develop y main sincronizadas"
  else
    falta "4. develop tiene $N commit(s) sin promocionar a main"
    git log --oneline origin/main..origin/develop | sed 's/^/        /'
  fi
else
  aviso "4. no se puede comparar: falta origin/main o origin/develop"
fi

# 5. Ningun PR del montaje abierto.
#    Solo cuentan los PR que abre el montaje: desde la rama temporal, y el de
#    develop hacia main. Los demas (Dependabot, que el paso 7 activa y puede
#    abrir PR enseguida, o PR que ya existian en el repo) no son trabajo a medias
#    del montaje: se listan como aviso, pero no lo dejan PENDIENTE para siempre.
if command -v gh >/dev/null 2>&1; then
  if ! TODOS=$(gh pr list --state open --json number,title,headRefName,baseRefName \
      --jq '.[] | "#\(.number)|\(.headRefName)|\(.baseRefName)|\(.title)"' 2>/dev/null); then
    falta "5. no se pudo consultar la lista de pull requests"
  else
    PROPIOS=""; AJENOS=""
    while IFS='|' read -r num cabeza base titulo; do
      [ -z "$num" ] && continue
      linea="        $num $cabeza -> $base: $titulo\n"
      if [ "$cabeza" = "$TEMPORAL" ] || { [ "$cabeza" = "develop" ] && [ "$base" = "main" ]; }; then
        PROPIOS="${PROPIOS}${linea}"
      else
        AJENOS="${AJENOS}${linea}"
      fi
    done <<< "$TODOS"
    if [ -z "$PROPIOS" ]; then
      ok "5. ningun pull request del montaje abierto"
    else
      falta "5. hay pull requests del montaje abiertos:"
      printf '%b' "$PROPIOS"
    fi
    if [ -n "$AJENOS" ]; then
      aviso "5. otros pull requests abiertos, ajenos al montaje (no bloquean):"
      printf '%b' "$AJENOS"
    fi
  fi
else
  aviso "5. gh no esta instalado: no se puede comprobar si hay PR abiertos"
fi

# 6. La rama temporal del montaje ya no esta
if [ -n "$(git branch --list "$TEMPORAL")" ]; then
  falta "6. la rama temporal $TEMPORAL sigue en local"
else
  ok "6. la rama temporal $TEMPORAL no esta en local"
fi
if git ls-remote --exit-code --heads origin "$TEMPORAL" >/dev/null 2>&1; then
  falta "6. la rama temporal $TEMPORAL sigue en el remoto"
else
  ok "6. la rama temporal $TEMPORAL no esta en el remoto"
fi

# 7. Toda etiqueta local esta empujada
LOCALES=$(git tag -l)
if [ -z "$LOCALES" ]; then
  ok "7. no hay etiquetas locales que empujar"
else
  SIN_SUBIR=""
  for t in $LOCALES; do
    git ls-remote --exit-code --tags origin "refs/tags/$t" >/dev/null 2>&1 || SIN_SUBIR="$SIN_SUBIR $t"
  done
  if [ -z "$SIN_SUBIR" ]; then
    ok "7. todas las etiquetas estan en el remoto"
  else
    falta "7. etiquetas sin empujar:$SIN_SUBIR"
  fi
fi

echo "==================="
if [ "$FALLOS" -eq 0 ]; then
  echo "CERRADO: no queda ningun merge, push ni rama pendiente."
  exit 0
fi
echo "PENDIENTE: $FALLOS comprobacion(es) sin cerrar."
echo "No reportes el montaje como completo. Di al usuario que falta"
echo "y pidele permiso para terminarlo."
exit 1
