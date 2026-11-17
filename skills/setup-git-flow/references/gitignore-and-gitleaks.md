# `.gitignore`, `.gitattributes` and gitleaks in the initial commit

Detail of step 1 of `SKILL.md`. All of this happens **before** the first `git add -A`,
because the initial commit is pushed straight to a new remote: whatever goes in is
published.

## `.gitignore`: copy or MERGE, never overwrite

**If the project has no `.gitignore`:** copy `templates/.gitignore`.

**If it already has one: MERGE.** An existing `.gitignore` is often the only thing
keeping personal data out of the repository: local datasets, SQLite databases,
recordings, model weights, downloaded content. Overwriting it with the skill's base
exposes all of that again in the first commit. Keep the project's file as the base and
add only the skill's patterns it is missing:

```bash
# The base copy lives OUTSIDE the repository: a .gitignore.bak left in the tree is
# picked up by `git add -A` and ends up committed.
#
# The `tr -d '\r'` on BOTH sides matters: if a template is CRLF and the project's
# .gitignore is LF, every pattern drags a trailing \r, `grep -qxF` never matches and
# the whole base is appended, duplicates included.
BASE=$(mktemp) && tr -d '\r' < .gitignore > "$BASE"

{ echo ""; echo "# ===== added by setup-git-flow ====="; } >> .gitignore
tr -d '\r' < ~/.claude/skills/setup-git-flow/templates/.gitignore | while IFS= read -r line; do
  [ -z "$line" ] && continue
  case "$line" in \#*) continue;; esac
  grep -qxF -- "$line" "$BASE" || echo "$line" >> .gitignore
done

rm -f "$BASE"
```

It never rewrites or reorders an existing line. Two warnings: if **either** file uses
negations (`!foo`), order decides the result and the merge must be done by hand; and
look out for near-duplicates (the base has `Thumbs.db` and the project may have
`*.db`): harmless, just noise.

**If the user chose Claude Code as the manager**, also add (if missing) Claude's two
personal files, which are never versioned:

```
.claude/settings.local.json
CLAUDE.local.md
```

They go here, before the initial commit, and not in the templates step: if the project
already has a `.claude/settings.local.json` with personal permissions, the initial
commit's `git add -A` would publish it.

The base is stack-agnostic: secrets, operating system, editor swap files and logs. If
the project already has code, look at what it generates (dependencies, build output,
caches, local data) and **ask** before adding those entries.

**Verify with git, not by reading the file:**

```bash
# These must show as ignored: the project's real sensitive paths and the secrets.
git check-ignore -v .env private.pem id_rsa data/x.db
# And the other way round: what MUST be versioned prints nothing.
git check-ignore -v README.md .env.example
```

## `.gitattributes` and `.editorconfig`

- **Repository without commits:** copy `templates/.gitattributes` before `git add -A`,
  so the initial commit is already normalized. `.editorconfig` can go here too or in
  the templates PR.
- **Repository with history:** they go in the templates PR (step 6). Do not run
  `git add --renormalize .`: it would rewrite the line endings of the whole project in
  one giant diff. Files get normalized as they are touched again.
- **If the project already has either one:** do not touch it. It is the project's
  decision; say so in the summary.

## gitleaks: scan what is staged before committing

`.gitignore` and gitleaks guard against the same accident from two angles, and neither
covers the other:

| | Looks at | Catches | Misses |
|---|---|---|---|
| `.gitignore` | **name / path** | `.env`, `*.pem`, `data/`, `id_rsa` | a key written *inside* `config.py` |
| gitleaks | **content** | `AWS_SECRET = "AKIA…"` on line 40 | anything about names |

```bash
gitleaks git --staged --redact --verbose
```

`--redact` keeps the secret out of the terminal and the logs. Without `gitleaks git`,
`gitleaks dir . --redact --verbose` scans the working tree.

- **Not installed:** say so and **carry on**; never abort the setup for it. But say it
  out loud here and in the summary: the initial commit went in **without content
  scanning**. Install: `winget install gitleaks` (Windows), `brew install gitleaks`
  (macOS/Linux), or a binary from github.com/gitleaks/gitleaks/releases.
- **It finds something: STOP.** Do not commit. Show the finding (redacted), have the
  user remove the secret and rotate the credential if it was ever real, and scan
  again. "Not installed" is a warning; "found something" is a hard stop.

Retroactive scan of the whole history, if installed later:
`gitleaks git --redact --verbose`. If it finds something already pushed, the fix is to
rotate the credential: rewriting history does not unpublish what was published.

## ⚠️ `git status` after `git add -A`

It is the last checkpoint: it lists exactly what the initial commit will publish.
GitHub's push protection only detects known token formats: it does not stop a `.env`,
a SQLite with personal data or a `.wav`. If something sensitive shows up or something
expected is missing, fix `.gitignore` and check again **before** committing.
