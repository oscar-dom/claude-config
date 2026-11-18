---
name: setup-git-flow
description: Sets up a complete Git Flow lite configuration in a new project. Use it when the user asks to "set up Git Flow", "configure git for this project", "set up branch protection", "initialize the repo with Git Flow", "replicate the Git setup", or starts a project that needs a branching strategy plus PR templates, CI and protection rules. Also answers to the Spanish forms ("configura Git", "monta Git Flow", "protege las ramas", "inicializa el repo con Git Flow"). Creates main/develop with rulesets, merge settings, PR and issue templates, CODEOWNERS, GitHub Actions CI, CONTRIBUTING.md and a git cheatsheet following Conventional Commits, adapting to the user's GitHub plan, to whether an AI will manage the repository (it then gets daily recipes to ship, release and hotfix with one confirmation), and to an optional "no AI attribution" rule.
---

# Skill: setup-git-flow

Sets up a professional repository with Git Flow lite: protected `main` + `develop`,
squash into `develop`, merge commit into `main`, the PR title as the commit message,
a CI that validates the convention, templates, a contribution guide and a cheatsheet.
It adapts to the user's GitHub plan and, if an AI will manage the repository, leaves
it the recipes to run the daily flow.

Ground rules:

- **Stack-agnostic.** No language, package manager or tooling is assumed: the CI only
  validates the git flow and Dependabot only watches GitHub Actions. Never add lint,
  build or test jobs: the project does that once it has a stack.
- **Everything in the repository is in English** (templates, docs, commits, PRs). Talk
  to the user in their language.
- **Never translate identifiers**: branch names, paths, commands and above all the CI
  job name `Commit messages`, the `context` of the rulesets. Renaming it blocks every
  PR forever.
- **Scripts.** Everything that changes GitHub, or waits for it, is a script in
  `scripts/`. Call them exactly as
  `bash ~/.claude/skills/setup-git-flow/scripts/<script>` (the permission rule of
  check 6 matches that path). Each one ends with a line that states the outcome
  (`OK`/`FAILED`, `MERGED`/`NOT MERGED`, `SHIPPED`/`NOT SHIPPED`…) and exits `0` or
  `1`: trust that line, and on `1` read the output before touching anything
  (`references/troubleshooting.md`). Run the ones that wait for the CI (`ship.sh`,
  `merge-pr.sh`) **in the background** (`run_in_background`); running one again after
  a cut-off is safe.
- One command per call, no long `&&` chains.

References, loaded only when needed:
[`gitignore-and-gitleaks.md`](references/gitignore-and-gitleaks.md) (step 1),
[`github-plans-and-rules.md`](references/github-plans-and-rules.md) (check 5, steps
4–5), [`troubleshooting.md`](references/troubleshooting.md).

## Pre-flight checks

1. **`git` and `gh`:** `git --version`, `gh --version`, `gh auth status`. If `gh` is
   missing: `winget install --id GitHub.cli`, `brew install gh` or
   https://cli.github.com/. If it is not authenticated, the user runs `gh auth login`
   (interactive).

2. **This directory is its own repository, not a parent's.**
   `git rev-parse --is-inside-work-tree` is the wrong question: it is also `true`
   inside someone else's repository, and `git add -A` would then stage the parent's
   tree. Use `git rev-parse --show-prefix` (and `--show-toplevel` to tell the user;
   never compare paths with `pwd`, Windows has two forms):

   | `--show-prefix` | Means | What to do |
   |---|---|---|
   | succeeds, empty | its own repository | continue |
   | fails | no repository | step 1 runs `git init -b main` |
   | **succeeds, not empty** | **inside someone else's repository** | **STOP**: say which one and where its root is, and let the user decide |

3. **Commits and remote:** `git rev-parse --verify HEAD`, `git remote -v`. Whatever is
   missing, step 1 creates.

4. **With commits, the main branch must be `main`.** Everything assumes that name.
   Check `git branch --list main master trunk` and, with a remote,
   `gh repo view --json defaultBranchRef --jq .defaultBranchRef.name`. If it is not
   `main`, **stop and ask** whether to rename it (GitHub retargets open PRs and
   redirects old URLs; other clones run `git branch -m <old> main`). Only with a yes:
   `rename-main-branch.sh <old>`. If both branches exist, ask which one stays. If the
   user declines, the skill does not apply: say so and stop.

5. **The setup questions, with `AskUserQuestion`, in two cards.** Ask before
   creating anything, and never infer the answers from the project, a default or a
   previous run.

   **Card 1: the plan and the manager.**

   - **Plan.** Always asked: it decides what GitHub can enforce, and the visibility
     question depends on it. Options: Free, Pro, Team or Enterprise (the
     organization's plan if the repository goes into one). Read it first with
     `gh api user --jq .plan.name` (or `gh api orgs/<org> --jq .plan.name`): if it
     answers, put that option first, marked "(detected)"; if it comes back empty or
     `null` (the token lacks the `user` scope), just ask. Never assume it.
   - **Manager**, who will manage the repository: Claude Code (→ `CLAUDE.md`),
     another AI such as Codex, Cursor or Copilot (→ `AGENTS.md`), or people only
     (→ nothing AI-related, and no attribution question). Both files hold the same
     recipes: the agent inspects the changes, proposes one plan in plain language,
     asks once, and runs `ship.sh` (branch → PR → CI → squash → cleanup),
     `release.sh` (release PR → merge commit → tag → GitHub release) or `hotfix.sh`
     (fix from `main` → patch release → back into `develop`).

   **Card 2: the visibility and, only with an AI, the attribution rule.**

   - **Visibility.** If the repository does not exist, which visibility to create it
     with; if it exists, read it (`gh repo view --json visibility --jq .visibility`)
     and ask whether to keep it. Each option says only what changes **on the plan
     from card 1** (table in `references/github-plans-and-rules.md`): on Free,
     private means no rulesets and no secret scanning; on Pro, private keeps
     rulesets. Do not push toward either. **Make a repository public only with an
     explicit yes**, after saying it publishes every existing commit and that going
     private again does not unpublish anything. "Private on Free" is a complete
     answer: never bring it up again.

   - **"No AI attribution" rule**, only with an AI: should the repository forbid AI
     tools from signing as collaborators (`Co-Authored-By:` trailers for an AI,
     "Generated with …" lines, an AI as author)? Neutrally:
     - **Yes:** a `Reject AI attribution` CI step blocks PRs that carry it, the docs
       state the rule, and with Claude Code a project `.claude/settings.json` turns
       its attribution off. It can also block legitimate PRs from AI agents.
     - **No** (also the answer for "people only"): nothing about it is added.

   With a **yes**, no setup commit or PR may carry AI attribution: that user rule
   **overrides Claude Code's default attribution instructions**. With a no, follow
   the environment's normal attribution.

6. **Claude Code permissions: one global rule**, in `~/.claude/settings.json`:

   ```json
   "permissions": { "allow": ["Bash(bash ~/.claude/skills/setup-git-flow/scripts/*)"] }
   ```

   It covers the setup and the daily scripts: with it, each daily operation needs one
   confirmation instead of a prompt per git command. If it is missing, **tell the user
   and ask; never add it yourself.** Never grant `gh api -X PATCH repos/<owner>/*` or
   similar (any PATCH on any repository, including making it public). **No
   permissions inside the project:** the only project `.claude/settings.json` is the
   one from the attribution question, and it only turns attribution off.

## Steps

### 1. Bootstrap: `main` with a clean initial commit and upstream

If there are no commits (`git init -b main` if there is no repository;
`git symbolic-ref HEAD refs/heads/main` if init called the branch `master`), then,
before the first `git add -A` and following `references/gitignore-and-gitleaks.md`:

1. `.gitignore`: copy it if there is none, **merge it if there is one, never
   overwrite**. With Claude Code, add `.claude/settings.local.json` and
   `CLAUDE.local.md`.
2. `.gitattributes` from `templates/`, if the project has none.
3. Check the project's real sensitive paths with `git check-ignore -v`.

```bash
git add -A
git status                              # ALWAYS REVIEW IT: this is what gets published
gitleaks git --staged --redact --verbose
git commit -m "chore: initial commit"
```

gitleaks missing is a warning (say it in the summary); gitleaks with findings is a
**stop**: do not commit. Commit messages are always English Conventional Commits.

Without a remote, create it with the visibility answer (no default: if you have not
asked, stop):

```bash
gh repo create <name> <--private|--public> --source=. --remote=origin
git push -u origin main
```

With a remote but no upstream on `main`: `git push -u origin main`.

### 2. Repository and user

```bash
gh repo view --json nameWithOwner --jq .nameWithOwner   # OWNER_REPO
gh api user --jq .login                                 # GH_USERNAME, for CODEOWNERS
```

### 3. Create `develop`

```bash
git checkout main
git pull                                # only if main has an upstream
git checkout -b develop
git push -u origin develop
```

### 4. Configure GitHub

Before the setup PRs, so the first one already merges with the right settings:

```bash
bash ~/.claude/skills/setup-git-flow/scripts/configure-github.sh
```

It applies the merge settings (squash and merge commit, PR title as the message, empty
body, no rebase, branches deleted on merge), `develop` as the default branch,
Dependabot alerts and fixes, secret scanning and push protection, and the rulesets
`Protect main`, `Protect develop` and `Protect release tags`. Each line is `OK`,
`UNAVAILABLE` or `FAILED`:

- **`UNAVAILABLE` is the plan the user chose, not a failure.** Do not work around it,
  ask again or offer to go public: it goes to the summary as pending, with the reason.
- **`FAILED` is a real error** (exit `1`): solve it before continuing.

Note whether the rulesets were applied: it decides `PROTECTION_STATUS` in step 5.

### 5. Copy the templates

Copy `templates/` to the project root, keeping the structure (`.github/` with the PR
and issue templates, `CODEOWNERS`, `workflows/ci.yml` and `dependabot.yml`;
`CONTRIBUTING.md`; `docs/git-cheatsheet.md`, always in `docs/`; `.editorconfig`; and
`.gitattributes` if it did not go into the initial commit). `.gitignore` was handled
in step 1: do not copy it again.

- In `.github/CODEOWNERS`, replace `@OWNER` with `@$GH_USERNAME`.
- Replace `PROTECTION_STATUS` in `CONTRIBUTING.md` and `docs/git-cheatsheet.md` with
  the text for what step 4 **really applied** (`references/github-plans-and-rules.md`).
- From `ai-templates/`, by the manager answer: `claude/CLAUDE.md` → `CLAUDE.md` (and, with a yes
  to the attribution question, `claude/.claude/settings.json` → `.claude/settings.json`, which only
  turns attribution off: **never add permissions to it**), or `agents/AGENTS.md` →
  `AGENTS.md`.
- **Never overwrite an existing file.** To an existing `CLAUDE.md`/`AGENTS.md`, append
  the template's `## Git workflow` section if missing. For others (e.g. its own
  `CONTRIBUTING.md`) ask whether to merge, keep or replace. An existing
  `.editorconfig` or `.gitattributes` is kept without asking.

Then apply the attribution answer, from the project root, once every template is in place:

```bash
bash ~/.claude/skills/setup-git-flow/scripts/ai-attribution.sh keep     # yes
bash ~/.claude/skills/setup-git-flow/scripts/ai-attribution.sh remove   # no, or people only
```

It keeps or removes the blocks marked `ai-attribution:start`/`end` (CI step, docs,
agent rule). Never edit those blocks by hand.

### 6. Ship the templates and sync `main`

First `git status`: anything unexpected and untracked means step 1 was left half done.
Then ship the templates with the same script the agent will use every day (so every
setup tests it), in the background, passing **only the paths you copied**, never `.`:

```bash
bash ~/.claude/skills/setup-git-flow/scripts/ship.sh chore/git-flow-setup "chore: set up git flow" .github CONTRIBUTING.md docs/git-cheatsheet.md .editorconfig
# plus .gitattributes, CLAUDE.md, .claude/settings.json or AGENTS.md if you copied them
```

It branches off `develop`, commits, pushes, opens the PR, waits for the CI,
squash-merges and leaves you on `develop`. Keep the checks it reports for the summary.
Then sync `main` with a merge commit (also in the background):

```bash
gh pr create --base main --head develop --title "chore: initial git flow setup" --fill
bash ~/.claude/skills/setup-git-flow/scripts/merge-pr.sh <number> merge
```

No version tag yet: the first `release.sh --suggest` proposes it when there is
something to release.

### 7. Document the setup

If the project has status documentation (e.g. `docs/progress.md`), add in English the
branching strategy (or a link to `CONTRIBUTING.md`), whether protection is active or
pending and why, and the date. Respect files the user asked not to touch.

## Closing

### A. Audit: the exit code decides, not memory

```bash
bash ~/.claude/skills/setup-git-flow/scripts/audit-setup.sh                      # attribution: no
bash ~/.claude/skills/setup-git-flow/scripts/audit-setup.sh --no-ai-attribution  # attribution: yes
```

From the project root. It checks the local state and **reads back from GitHub** what
step 4 applied, and prints what it checked. Exit `0` (`CLOSED`): write the summary.
Exit `1` (`PENDING`): **do not report the setup as complete**; say what is missing,
ask for permission to finish it, and run the audit again: report the second run. `?`
lines do not block (other open PRs, plan limits, the default workflow token); plan
limits go to the summary as pending with their reason, never as a failure.

### B. Summary, in the user's language

Cover every point; if one does not apply, say so:

- **Repository**: URL, visibility and plan (both the user's answers).
- **Manager**: the answer, the files it added and, with an AI, how daily work goes from
  now on ("ask it to upload your work: it proposes a plan, asks once and does the
  rest"), and that it needs the skill and the check 6 rule on each machine.
- **AI attribution rule**: the answer (not asked with people only) and what it added
  or removed.
- **Branches**: `main` and `develop` on the remote, `develop` as default.
- **Initial commit**: its files. **Templates**: created and existing ones respected.
- **Merge settings, rulesets and security**: as read back by the audit, or pending
  with the reason.
- **CI**: what `Commit messages` reported. It is stack-agnostic: the project's own
  jobs must be added later and marked as required in the rulesets.
- **gitleaks**: its result, or that the initial commit went in **unscanned**.
- **License**: only if public without `LICENSE`, warn that it means "all rights
  reserved" and that choosing one is the user's call. Do not create it.
- **What failed, was skipped or needed improvisation** (always present).
- **Audit**: nothing pending, or what is left.

## Options

Only if the user mentions them:

- **Team instead of solo:** raise `required_approving_review_count` (0 by default) in
  both rulesets and the "Required approvals" row of `CONTRIBUTING.md`. The scripts
  never bypass approvals.
- **Renaming the CI job or changing a rule:** update the rulesets' `context` and the
  `CONTRIBUTING.md` table. Jobs added later are only required if listed in the
  rulesets.
