# Git Cheatsheet

> **Para humanos:** referencia rápida para trabajar con este repo sin abrir 5 pestañas.
> **Para IAs:** descripción autocontenida de la arquitectura Git del proyecto. Léelo antes de ejecutar comandos `git` o `gh` aquí.

---

## TL;DR — el flujo en 30 segundos

```bash
# 1. Empezar algo nuevo
git checkout develop && git pull
git checkout -b feat/lo-que-sea

# 2. Trabajar y commitear (mensajes con Conventional Commits)
git add <archivos>
git commit -m "feat: descripción en imperativo"

# 3. Subir y abrir PR
git push -u origin feat/lo-que-sea
gh pr create --base develop --fill

# 4. Tras merge: limpiar local
git checkout develop && git pull
git branch -d feat/lo-que-sea
```

---

## Arquitectura Git del repo

### Ramas

```
main      ← producción (protegida, squash-only, conversaciones resueltas, historial lineal)
  ↑ PR
develop   ← integración (protegida, PR required)
  ↑ PR
feat/xxx  ← features
fix/xxx   ← bugfixes
chore/xxx ← mantenimiento, deps, configs
docs/xxx  ← solo docs
test/xxx  ← solo tests
refactor/xxx
```

**Reglas técnicas (impuestas por GitHub rulesets):**
- ❌ Push directo a `main` o `develop` está bloqueado.
- ❌ Force push bloqueado.
- ❌ Borrado de ramas bloqueado.
- ✅ Cambios entran solo vía Pull Request.
- ✅ `main`: solo squash merge, conversaciones del PR resueltas, historial lineal.
- ✅ `develop`: squash o merge commit permitidos.

### Protecciones de seguridad activas

- **Secret scanning** — GitHub detecta tokens (Stripe, AWS, etc.) en commits y avisa.
- **Push protection** — bloquea el push si detecta un secreto antes de que llegue al servidor.
- **Dependabot alerts** — avisa de vulnerabilidades en dependencias.
- **Automated security fixes** — abre PRs automáticos para parches de seguridad.

---

## Conventional Commits — cómo escribir mensajes

### Formato

```
<tipo>: <descripción en imperativo, minúscula, sin punto final>

[cuerpo opcional explicando el "por qué"]

[footer opcional con BREAKING CHANGE: o refs a issues]
```

### Tipos válidos

| Tipo       | Cuándo usarlo                                   | Ejemplo                                             |
|------------|--------------------------------------------------|-----------------------------------------------------|
| `feat`     | Funcionalidad nueva visible al usuario           | `feat: añade login con Google`                      |
| `fix`      | Corrección de bug                                | `fix: corrige error 500 en endpoint de pagos`       |
| `chore`    | Mantenimiento, deps, config, scripts             | `chore: actualiza Next.js a 15.1`                   |
| `docs`     | Solo documentación                               | `docs: documenta API de autenticación`              |
| `refactor` | Refactor sin cambio de comportamiento            | `refactor: simplifica utils de validación`          |
| `test`     | Añadir o modificar tests                         | `test: añade tests para login flow`                 |
| `style`    | Formato, espacios, no afecta lógica              | `style: formatea con prettier`                      |
| `perf`     | Mejora de rendimiento                            | `perf: cachea queries pesadas`                      |
| `build`    | Cambios al sistema de build, deps de build       | `build: añade webpack analyzer`                     |
| `ci`       | Cambios en CI/CD                                 | `ci: añade test job a GitHub Actions`               |
| `revert`   | Revertir commit anterior                         | `revert: deshace "feat: añade X"`                   |

### Reglas

1. **Imperativo presente:** "añade", no "añadido" ni "añadiendo".
2. **Minúscula al inicio** de la descripción.
3. **Sin punto final**.
4. **Máximo 72 caracteres** en la primera línea.
5. **Breaking changes:** `feat!:` o `BREAKING CHANGE:` en el footer.

### Ejemplos buenos vs malos

| ❌ Mal                              | ✅ Bien                                           |
|-------------------------------------|---------------------------------------------------|
| `actualizado el login`              | `feat: añade validación de email en login`        |
| `arreglos varios`                   | `fix: corrige error 500 al validar input`         |
| `WIP`                               | `feat: añade primer borrador del dashboard`       |
| `Fix.`                              | `fix: corrige cálculo de total con descuento`     |
| `feat: Add user system.`            | `feat: añade sistema de usuarios`                 |

### Commit con cuerpo (cuando hace falta más contexto)

```
fix: corrige race condition al cerrar transacciones

Cuando dos workers se ejecutaban en paralelo, ambos
intentaban procesar la misma transacción, provocando
duplicados. Ahora usamos un lock con SELECT FOR UPDATE
antes de procesar.

Closes #42
```

### Breaking changes

```
feat!: cambia formato de respuesta de API a JSON:API

BREAKING CHANGE: Las APIs ahora devuelven respuestas
en formato JSON:API. Los clientes consumidores deben
actualizarse para leer la nueva estructura.
```

---

## Flujo de trabajo paso a paso

### Empezar a trabajar en algo nuevo

Siempre desde `develop` actualizada:

```bash
git checkout develop
git pull
git checkout -b feat/nombre-descriptivo
```

**Naming de ramas:**
- Empieza con `feat/`, `fix/`, `chore/`, `docs/`, etc.
- Descripción corta en kebab-case: `feat/login-google`, no `feat/Login_Con_Google`.
- Verbos en infinitivo o sustantivos: `feat/anadir-realtime`, `fix/cierre-transaccion`.

### Hacer commits durante el trabajo

```bash
git add src/components/MyComponent.tsx
git commit -m "feat: implementa componente principal"
```

**Tip:** Commits pequeños y frecuentes > un commit gigante al final. Cada commit debe poder describirse en una sola frase.

### Mantener tu rama al día con `develop`

Si `develop` ha avanzado mientras tú trabajas:

```bash
git checkout develop && git pull
git checkout feat/tu-rama
git rebase develop          # o `git merge develop` si prefieres no reescribir historial
# Si hay conflictos: editarlos, `git add`, `git rebase --continue`
git push --force-with-lease  # solo si rebaseaste y aún no había PR
```

### Subir y abrir PR

```bash
git push -u origin feat/tu-rama
gh pr create --base develop --fill
```

### Recibir feedback y aplicar cambios

```bash
git add <archivos>
git commit -m "fix: aplica feedback del PR sobre validación"
git push  # el PR se actualiza solo
```

### Mergear el PR

Cuando el CI esté en verde y haya aprobación:

```bash
gh pr merge --squash --delete-branch
```

### Limpiar después del merge

```bash
git checkout develop
git pull
git branch -d feat/tu-rama
```

### Release: develop → main

Cuando hay un conjunto de features estables listas para producción:

```bash
gh pr create --base main --head develop --title "release: vX.Y.Z" --fill
gh pr merge --squash
```

---

## Comandos `gh` (GitHub CLI) útiles

```bash
gh pr create --base develop --fill          # Crear PR
gh pr list                                  # Listar PRs abiertos
gh pr view <num>                            # Ver detalles de un PR
gh pr checks                                # Estado del CI del PR actual
gh pr merge <num> --squash --delete-branch  # Mergear y borrar rama
gh pr diff                                  # Ver diff del PR actual

gh issue create                             # Crear issue (usa template)
gh issue list                               # Listar issues abiertos

gh repo view --web                          # Abre el repo en el navegador
gh run list                                 # Últimas ejecuciones de CI
gh run watch                                # Sigue la ejecución actual de CI en vivo
```

---

## Resolución de problemas comunes

### "Estoy en `main` y he hecho cambios sin querer"

```bash
git stash                                   # guarda los cambios temporalmente
git checkout develop && git pull
git checkout -b feat/lo-que-sea
git stash pop                               # restaura los cambios
```

### "Hice push y se me coló un secret"

1. **Acción inmediata:** revoca el token (en el dashboard del proveedor).
2. Quita el archivo del último commit:
   ```bash
   git rm --cached .env
   git commit --amend
   git push --force-with-lease     # SOLO funciona en ramas no protegidas
   ```
3. Si está en `main`/`develop` (ya mergeado), abre PR con la corrección — el historial queda pero el token ya no es válido.

> Nota: GitHub secret scanning te avisará por email. Push protection debería haberlo bloqueado antes de subir.

### "El CI está fallando y no entiendo por qué"

```bash
gh pr checks                # resumen de checks
gh run view --log-failed    # logs del job que falló
```

### "Mi rama está desactualizada con develop"

```bash
git fetch origin
git rebase origin/develop
git push --force-with-lease
```

### "Borré una rama por error"

```bash
git reflog                  # busca el commit hash
git checkout -b nombre-rama <hash>
git push -u origin nombre-rama
```

### "Quiero deshacer mi último commit (aún no pusheado)"

```bash
git reset --soft HEAD~1     # mantiene los cambios en staging
git reset HEAD~1            # mantiene los cambios pero unstaged
git reset --hard HEAD~1     # ⚠️ borra los cambios completamente
```

### "Necesito traer un commit específico de otra rama"

```bash
git cherry-pick <hash-del-commit>
```

---

## Checklist antes de abrir un PR

- [ ] Mi rama parte de `develop` actualizada.
- [ ] Los mensajes de commit siguen Conventional Commits.
- [ ] He probado los cambios en local.
- [ ] He actualizado documentación si era necesario.
- [ ] No hay archivos `.env`, secretos, ni datos personales en el diff.
- [ ] El título del PR sigue Conventional Commits (será el squash commit).

---

## Para IAs / herramientas automatizadas

Si eres una IA trabajando en este repo, esto es lo que necesitas saber:

1. **Nunca pushear directo a `main` o `develop`** — están protegidas. Crea siempre una rama tipo `feat/xxx`.
2. **Conventional Commits es obligatorio** — el CI tiene un job que valida el formato.
3. **CODEOWNERS:** los archivos críticos requieren review del owner del repo.
4. **Secret scanning está activo:** si intentas commitear un token, GitHub bloqueará el push.
5. **PRs siempre a `develop`** salvo que sea una release (`develop → main`).
6. **Usa `gh` CLI** (autenticado) para crear PRs, no la API directamente.
7. **Tras mergear:** ejecuta `git checkout develop && git pull` y borra la rama local con `git branch -d`.
8. **En Windows el path completo de gh suele ser `/c/Program Files/GitHub CLI/gh.exe`** (o `gh` si está en PATH).
