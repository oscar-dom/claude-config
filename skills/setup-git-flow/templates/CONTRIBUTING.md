# Guía de Contribución

Esta guía explica cómo trabajar en el repositorio.

---

## Estrategia de ramas (Git Flow ligero)

```
main      ← producción, intocable, protegida
  ↑ PR (con review)
develop   ← integración, protegida
  ↑ PR (con review)
feat/<descripcion>   ← una rama por feature
fix/<descripcion>    ← una rama por bugfix
chore/<descripcion>  ← mantenimiento, deps, configuración
docs/<descripcion>   ← cambios en documentación
```

### Reglas
- **Nunca** se hace push directo a `main` o `develop`. Siempre vía Pull Request.
- Cada cambio se desarrolla en su propia rama, partiendo de `develop`.
- Los PRs se mergean a `develop`. Cuando hay un conjunto estable, se hace PR `develop → main` para release.

---

## Flujo de trabajo paso a paso

### 1. Empezar a trabajar en algo nuevo

```bash
git checkout develop
git pull
git checkout -b feat/nombre-descriptivo
```

### 2. Hacer cambios y commits

```bash
git add <archivos>
git commit -m "feat: descripción del cambio"
```

(Ver [Convención de commits](#convención-de-commits) más abajo.)

### 3. Subir la rama y abrir PR

```bash
git push -u origin feat/nombre-descriptivo
gh pr create --base develop --fill
```

### 4. Resolver feedback y mergear

- Espera a que CI pase (verde) y a que recibas review.
- Si te piden cambios: haces commits adicionales en la misma rama y pusheas. El PR se actualiza solo.
- Cuando todo esté aprobado: usa "Squash and merge" para mantener el historial limpio.

### 5. Limpiar después del merge

```bash
git checkout develop
git pull
git branch -d feat/nombre-descriptivo
```

---

## Convención de commits

Usamos [Conventional Commits](https://www.conventionalcommits.org/).

### Formato

```
<tipo>: <descripción corta en imperativo>

[cuerpo opcional con más contexto]

[footer opcional con BREAKING CHANGE, refs a issues, etc.]
```

### Tipos

| Tipo | Cuándo usar | Ejemplo |
|------|-------------|---------|
| `feat` | Nueva funcionalidad para el usuario | `feat: añade login con Google` |
| `fix` | Corrección de bug | `fix: corrige error en validación` |
| `chore` | Mantenimiento, deps, build, configs | `chore: actualiza dependencias` |
| `docs` | Solo cambios en documentación | `docs: documenta API de pagos` |
| `refactor` | Refactor sin cambio de comportamiento | `refactor: simplifica utils` |
| `test` | Añadir o modificar tests | `test: añade tests de auth` |
| `style` | Formato, espacios (no afecta lógica) | `style: formatea con prettier` |
| `perf` | Mejora de rendimiento | `perf: cachea queries pesadas` |

### Reglas

- Descripción en **imperativo, presente** ("añade", no "añadido").
- **Minúscula** al inicio.
- **Sin punto final**.
- **Máx 72 caracteres** en la primera línea.
- Si hay breaking change: `feat!:` o añadir `BREAKING CHANGE:` en el footer.

---

## Pull Requests

### Antes de abrir un PR

- [ ] La rama está actualizada con `develop`.
- [ ] Has probado los cambios en local.
- [ ] CI pasa en local (lint, typecheck, build).
- [ ] Has actualizado documentación si era necesario.

### Al abrir un PR

- Usa la plantilla auto-rellenada.
- Título en formato Conventional Commits (será el squash commit).
- Asigna labels relevantes (`bug`, `enhancement`, `docs`, etc.).
- Vincula issues: `Closes #123`.

### Revisión

- Mínimo **1 aprobación** antes de mergear (configurable según tamaño del equipo).
- Todos los **checks de CI deben pasar**.
- Resolver todas las conversaciones antes de mergear.

---

## Configuración local recomendada

### Hooks de Git (commitlint + husky)

Una vez exista `package.json`, instalar husky para validar mensajes de commit:

```bash
pnpm add -D husky @commitlint/cli @commitlint/config-conventional
pnpm exec husky init
echo "pnpm exec commitlint --edit \$1" > .husky/commit-msg
```

Crear `commitlint.config.cjs`:
```js
module.exports = { extends: ['@commitlint/config-conventional'] };
```

### Editor

Recomendado: VS Code con extensiones:
- ESLint
- Prettier
- GitLens
- Conventional Commits

---

## Preguntas frecuentes

**¿Y si meto la pata y commiteo en `main` por error?**
No pasa nada — `main` está protegida y rechazará el push. Mueves los commits a una rama nueva: `git branch fix/lo-que-sea && git reset --hard origin/main`.

**¿Squash, merge o rebase?**
Squash and merge para PRs (un commit limpio por feature en `develop` y `main`). Rebase para mantener tu rama al día con `develop`.

**¿Qué hago si el CI falla?**
Lee los logs en la pestaña "Checks" del PR. Si falla `lint` → corre `pnpm lint --fix`. Si falla `typecheck` → corre `pnpm typecheck`. Si es algo confuso, pregunta.
