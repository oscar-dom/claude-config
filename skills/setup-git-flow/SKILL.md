---
name: setup-git-flow
description: Sets up a complete Git Flow lite configuration in a new project. Use it when the user asks to "set up Git Flow", "configure git for this project", "set up branch protection", "initialize the repo with Git Flow", "replicate the Git setup", or starts a project that needs a branching strategy plus PR templates, CI and protection rules. Also answers to the Spanish forms ("configura Git", "monta Git Flow", "protege las ramas", "inicializa el repo con Git Flow"). Creates main/develop with rulesets, merge settings, PR and issue templates, CODEOWNERS, GitHub Actions CI, CONTRIBUTING.md and a git cheatsheet following Conventional Commits, adapting to the user's GitHub plan, to whether an AI will manage the repository (it then gets daily recipes to ship, release and hotfix with one confirmation), and to an optional "no AI attribution" rule.
---

# Skill: setup-git-flow

Sets up the base of a professional repository with Git Flow lite: protected `main` +
`develop`, squash into `develop` and merge commit into `main`, the PR title as the
commit message, CI that validates the convention, templates, a contribution guide and
a cheatsheet. It adapts to the user's GitHub plan and, if an AI will manage the
repository, leaves its instructions ready.

> **Never translate identifiers**: branch names, file paths, commands and, above all,
> the CI job `name:` (`Commit messages`), which is the `context` of the rulesets.
> Renaming it blocks every PR forever.

**Stack-agnostic.** It assumes no language, package manager or tooling. The CI only
validates the git flow, `.gitignore` only covers secrets, OS files and logs,
`.editorconfig` does not impose indentation, and Dependabot only watches GitHub
Actions. Do not add lint, build or test jobs or anything language-specific: the
project does that once it has a stack.

**Everything that goes into the repository is in English**: templates,
`CONTRIBUTING.md`, the cheatsheet, `CLAUDE.md`/`AGENTS.md`, commit messages, PR and
issue titles and descriptions. Talk to the user (questions and the final summary) in
the language they use.

## References

Detail loaded only when needed:

- [`references/gitignore-and-gitleaks.md`](references/gitignore-and-gitleaks.md):
  merging `.gitignore`, `.gitattributes`, gitleaks and reviewing the initial commit
  (step 1).
- [`references/github-plans-and-rules.md`](references/github-plans-and-rules.md): what
  each plan includes, repository settings, rulesets, merge policy and the
  `PROTECTION_STATUS` text (pre-flight check 5 and steps 4–5).
- [`references/troubleshooting.md`](references/troubleshooting.md): known errors and
  their fixes.

## Pre-flight checks

1. **`git` available:** `git --version`.
2. **`gh` available and authenticated:** `gh --version` and `gh auth status`. If
   missing: `winget install --id GitHub.cli` (Windows), `brew install gh` (macOS) or
   https://cli.github.com/. If not authenticated, the user runs `gh auth login`
   themselves (it is interactive).
3. **This directory is its own repository, not a parent's.**
   `git rev-parse --is-inside-work-tree` is the wrong question: it also returns `true`
   when the folder hangs from someone else's repository, and then `git add -A` would
   stage **the parent's tree**. Ask where you are relative to the root:

   ```bash
   git rev-parse --show-prefix 2>/dev/null     # path relative to the repository root
   git rev-parse --show-toplevel 2>/dev/null   # the root, to tell the user
   ```

   Do not compare `--show-toplevel` with `pwd`: on Windows the same directory has two
   forms (`C:/...` and `/c/...`).

   | `--show-prefix` | Means | What to do |
   |---|---|---|
   | succeeds, empty | the project is already its own repository | continue |
   | fails | there is no repository | step 1 runs `git init -b main` |
   | **succeeds, not empty** | it is **inside someone else's repository** | **STOP and ask** |

   In the third case, stop before touching anything, say which repository you found
   and where its root is, and let the user decide.

4. **Commits and remote:** `git rev-parse --verify HEAD` and `git remote -v`. If either
   is missing, step 1 handles it.

   **If there are commits, the main branch must be called `main`.** Everything else
   (rulesets, CI, templates, scripts) assumes that name: with `master`, step 3 fails
   and the rulesets would protect a `main` nobody uses. Check the current branch and,
   with a remote, GitHub's default branch:

   ```bash
   git branch --list main master trunk
   gh repo view --json defaultBranchRef --jq .defaultBranchRef.name   # only with a remote
   ```

   If the main branch is not `main`, **stop and ask** whether to rename it. Explain
   that GitHub retargets open PRs and redirects old URLs, and that anyone with a clone
   will have to run `git branch -m <old> main` (GitHub tells them). With a yes, and
   never without one:

   ```bash
   bash ~/.claude/skills/setup-git-flow/scripts/rename-main-branch.sh <old>
   ```

   It prints `RENAMED` (exit `0`) or `NOT RENAMED` and the reason (exit `1`). If both
   branches already exist, do not choose: ask which one stays. If the user prefers not
   to rename, the skill does not apply as is: say so and stop.

5. **The setup questions, asked with `AskUserQuestion`.** Questions 1 and 2 go in ONE
   card; question 3 only exists when answer 2 is an AI, and goes in a second card right
   after. They are the only decisions the user makes. Ask them before creating
   anything and wait for the answers. Do not infer them from the project, a default or
   a previous run.

   **First read the plan**, so the visibility question states the real consequences
   for that account without the user having to explain them:

   ```bash
   gh api user --jq .plan.name
   ```

   **Question 1, visibility.** If the repository does not exist, which visibility to
   create it with; if it exists, read the current one
   (`gh repo view --json visibility --jq .visibility`), say it and ask whether to keep
   it. In each option's description put only what changes **for their plan** (table in
   `references/github-plans-and-rules.md`):

   - Free: private = no branch protection through rulesets and no secret scanning;
     public = everything active and code visible to anyone.
   - Pro: private keeps branch protection (no secret scanning); public = everything
     active and code visible.

   Do not push toward either: both are legitimate. **Only make a repository public
   with an explicit yes**, saying first that it publishes **every commit already
   there** and that switching back to private does not unpublish what was downloaded
   or indexed. Never change visibility silently. "Private, on the Free plan" is a
   complete answer, not a problem: do not bring it up again later.

   **Question 2, who will manage the repository.**

   | Answer | What is added (step 5) |
   |---|---|
   | Claude Code | `CLAUDE.md` with the daily git recipes (+ Claude's personal files in `.gitignore`, step 1) |
   | Another AI (Codex, Cursor, Copilot…) | `AGENTS.md` with the same recipes |
   | People only | nothing AI-related, and question 3 is **not** asked |

   With an AI, the recipes let it run the whole daily flow for a user who may know no
   git: it inspects the changes, proposes one plan in plain language, asks once and
   then ships it with `ship.sh` (branch, commit, PR, CI, merge, cleanup), releases it
   with `release.sh` (release PR, CI, merge commit, tag, GitHub release) or fixes
   production with `hotfix.sh` (branch from `main`, PR, CI, patch tag, release, and
   the fix back into `develop`). Tell the user, in the summary, that this needs the
   skill installed and the permission rule of check 6 on each machine they work from.

   **Question 3, only if answer 2 is an AI: "no AI attribution" rule.** With "people
   only" do not ask it: it is a **no**, and step 5 removes the rule's blocks. Should
   the repository forbid AI tools from leaving their mark as collaborators
   (`Co-Authored-By:` trailers for an AI, "Generated with …" lines, an AI as author or
   committer)? Describe both options neutrally:

   - **Yes:** a `Reject AI attribution` step in the required CI check blocks any PR
     that carries it, `CONTRIBUTING.md` and the agent instructions state the rule,
     and with Claude Code a project `.claude/settings.json` turns its attribution off
     at the source. It can also block legitimate PRs from AI agents (e.g. Copilot's)
     if the team uses them.
   - **No:** nothing about AI attribution is added; tools behave as they are
     configured.

   The answer decides what `ai-attribution.sh` does in step 5 and, if it is **yes**,
   that **no setup commit or PR carries AI attribution**: no
   `Co-Authored-By: Claude ...` trailer, no "Generated with Claude Code", Claude never
   as author. That user rule **takes precedence over Claude Code's default attribution
   instructions**: drop those lines even if the environment asks for them. If the
   answer is **no**, follow the environment's normal attribution.

6. **Claude Code permissions: one global rule.** Everything that changes GitHub
   (merging PRs, settings, rulesets, security) lives in `scripts/`, with fixed
   endpoints. Allowing those scripts once, in `~/.claude/settings.json`, is enough:

   ```json
   "permissions": { "allow": ["Bash(bash ~/.claude/skills/setup-git-flow/scripts/*)"] }
   ```

   **Always invoke the scripts exactly like this**:
   `bash ~/.claude/skills/setup-git-flow/scripts/<script>`. With another path the rule
   does not match and the permission prompt comes back.

   The same rule covers `ship.sh`, `release.sh` and `hotfix.sh`, which the AI uses
   every day in the repository (question 2): with it, daily work needs one
   confirmation per operation instead of a permission prompt per git command.

   - If the rule is missing, **do not add it yourself**: tell the user and ask.
   - **Never grant `gh api -X PATCH repos/<owner>/*`** or similar: it would allow any
     PATCH on any repository, including making it public.
   - **No permissions inside the project.** The only `.claude/settings.json` the skill
     creates is the one from question 3, and it only turns attribution off:
     permissions belong to each person, not to the repository.

   Run **one command per call**, no long `&&` chains.

## Steps

### 1. Bootstrap: `main` with a clean initial commit and upstream

Everything else assumes `main` exists with an upstream. Check what is missing:

```bash
git rev-parse --show-prefix 2>/dev/null     # empty = this directory is the repository
git rev-parse --verify HEAD 2>/dev/null     # any commits?
git remote get-url origin 2>/dev/null       # any remote?
```

**If there are no commits:**

```bash
git init -b main                        # only if it is not a repository yet
git symbolic-ref HEAD refs/heads/main   # if init called the branch master
```

Before the first `git add -A`, following `references/gitignore-and-gitleaks.md`:

1. `.gitignore`: copy it if there is none, **merge if there is one, never
   overwrite**. If answer 2 was Claude Code, add `.claude/settings.local.json` and
   `CLAUDE.local.md`.
2. `.gitattributes` (`templates/.gitattributes`), if the project has none.
3. Verify the project's real sensitive paths with `git check-ignore -v`.

Then:

```bash
git add -A
git status                              # ALWAYS REVIEW IT: this is what gets published
gitleaks git --staged --redact --verbose
git commit -m "chore: initial commit"
```

gitleaks not installed is a warning (carry on and say so in the summary); gitleaks
with findings is a **stop**: do not commit.

**Commit messages always in English**, as Conventional Commits, in this step and in
every other.

**If there is no remote**, create it with the visibility the user chose and push
`main`:

```bash
# <visibility> is --private or --public, from answer 1. No default on purpose: if
# you have not asked yet, stop and ask.
gh repo create <name> <visibility> --source=. --remote=origin
git push -u origin main
```

If the remote exists but `main` has no upstream: `git push -u origin main`.

### 2. Find the repository and the user

```bash
gh repo view --json nameWithOwner --jq .nameWithOwner   # OWNER_REPO
gh api user --jq .login                                 # GH_USERNAME, for CODEOWNERS
```

### 3. Create `develop`

```bash
git checkout main
git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1 && git pull
git checkout -b develop
git push -u origin develop
```

(Only `git pull` if `main` has an upstream: without one it fails.)

### 4. Configure GitHub: settings, default branch, security and rulesets

**It runs before the setup PRs**, so the first squash already uses the PR title as
the message and the `develop` → `main` PR is already limited to a merge commit:

```bash
bash ~/.claude/skills/setup-git-flow/scripts/configure-github.sh
```

It applies, in this order: merge settings (squash and merge commit with the PR title
as the message and an empty body, no rebase, branches deleted on merge), `develop` as
the default branch, Dependabot alerts and security fixes, secret scanning and push
protection, and the rulesets `Protect main`, `Protect develop` and
`Protect release tags` (created, or updated if they exist). Detail in
`references/github-plans-and-rules.md`.

Each line prints `OK`, `UNAVAILABLE` or `FAILED`:

- **`UNAVAILABLE` is not a failure**: it is the plan the user chose. Do not work
  around it, do not ask again and do not offer to make the repository public. It goes
  to the summary as pending, with its reason.
- **`FAILED`** is a real error (repository missing, token without scopes, rejected
  JSON). Exit `1`: do not continue until it is solved.

**Note whether the rulesets were applied or not**: it decides the
`PROTECTION_STATUS` text in step 5.

### 5. Copy the templates

Copy `templates/` to the project root, keeping the structure:

- `.github/PULL_REQUEST_TEMPLATE.md`
- `.github/ISSUE_TEMPLATE/bug_report.md`, `feature_request.md` and `config.yml` (the
  latter only disables blank issues; it does not link to Discussions, which are off
  in a new repository)
- `.github/CODEOWNERS`: **replace `@OWNER` with `@$GH_USERNAME`**
- `.github/workflows/ci.yml`
- `.github/dependabot.yml`
- `CONTRIBUTING.md`
- `docs/git-cheatsheet.md`: **always** in `docs/` (linked from `CONTRIBUTING.md`,
  `CLAUDE.md` and `AGENTS.md`)
- `.editorconfig`, and `.gitattributes` if it did not go into the initial commit
- `.gitignore`: **already handled in step 1**; do not copy it over again

**Replace `PROTECTION_STATUS`** in `CONTRIBUTING.md` and `docs/git-cheatsheet.md` with
the text matching what step 4 **really applied** (both texts are in
`references/github-plans-and-rules.md`). Do not leave the placeholder.

**According to answer 2**, also copy from `ai-templates/`:

| Answer | Files |
|---|---|
| Claude Code | `ai-templates/claude/CLAUDE.md` → `CLAUDE.md`; with a **yes** to question 3, also `ai-templates/claude/.claude/settings.json` → `.claude/settings.json` |
| Another AI | `ai-templates/agents/AGENTS.md` → `AGENTS.md` |
| People only | nothing |

`.claude/settings.json` only turns Claude's attribution off in commits and PRs, so the
rule is met at the source. **Never add permissions to it.**

**Apply answer 3** from the project root, once every template is in place:

```bash
bash ~/.claude/skills/setup-git-flow/scripts/ai-attribution.sh keep     # answer: yes
bash ~/.claude/skills/setup-git-flow/scripts/ai-attribution.sh remove   # answer: no, or people only
```

The templates wrap everything about the rule between `ai-attribution:start` /
`ai-attribution:end` markers: `keep` drops only the markers, `remove` drops the whole
blocks (the CI step, the `CONTRIBUTING.md` section, the agent instruction). Never edit
those blocks by hand; the audit fails if a marker is left.

**If a file already exists in the project, do not overwrite it.** For an existing
`CLAUDE.md` or `AGENTS.md`, append the template's `## Git workflow` section at the end
(if it does not have it yet), then run `ai-attribution.sh`. For the rest (e.g. its own
`CONTRIBUTING.md`), tell the user and ask whether to merge, keep theirs or replace it.
An existing `.editorconfig` or `.gitattributes` is respected without asking.

### 6. Commit the templates through a PR and sync `main`

The project content went into the initial commit (step 1); the templates go in now
through a PR. First `git status`: anything unexpected and untracked means step 1 was
left half done.

Ship them with `ship.sh`, the same script the AI will use every day (so every setup
also tests it). Pass **only the paths you copied**, never `.`: the initial commit
already holds the rest of the project.

```bash
bash ~/.claude/skills/setup-git-flow/scripts/ship.sh chore/git-flow-setup "chore: set up git flow" .github CONTRIBUTING.md docs/git-cheatsheet.md .editorconfig
# plus .gitattributes, CLAUDE.md, .claude/settings.json or AGENTS.md if you copied them
```

Run it **in the background** (`run_in_background`): it waits for the CI, which can
outlast a command timeout. It creates the branch from `develop`, commits, pushes,
opens the PR, waits for the checks, squash-merges without bypassing any rule and
leaves you on an up-to-date `develop` with the branch deleted. The PR title is the
commit that lands on `develop`, and the CI validates it.

Its last line is `SHIPPED` (exit `0`) or `NOT SHIPPED` and the reason (exit `1`). With
`1`, **read the output before touching anything** (`references/troubleshooting.md`);
running the same command again is safe. Keep the checks it reports: they go to the
summary.

Then sync `main` with a **merge commit** (also in the background):

```bash
gh pr create --base main --head develop --title "chore: initial git flow setup" --fill
bash ~/.claude/skills/setup-git-flow/scripts/merge-pr.sh <number> merge
```

It prints `MERGED` (exit `0`) or `NOT MERGED` and the reason (exit `1`).

No version tag is created: the project decides its first version when it has
something to release (`release.sh --suggest` proposes it).

### 7. Document the setup

If the project has `docs/progress.md` or other status documentation, add **in
English**: the branching strategy (or a link to `CONTRIBUTING.md`), whether
protection is active or pending and why, and the date. If the user asked not to touch
some file, respect it and say so in the summary. With no documentation,
`CONTRIBUTING.md` is the source of truth.

## Closing: audit first, then the summary

### A. Audit

**Do not write the summary from memory.** The script's exit code decides:

```bash
bash ~/.claude/skills/setup-git-flow/scripts/audit-setup.sh                      # answer 3: no
bash ~/.claude/skills/setup-git-flow/scripts/audit-setup.sh --no-ai-attribution  # answer 3: yes
```

| Exit | Means | What to do |
|---|---|---|
| `0` | `CLOSED` | write the summary |
| `1` | `PENDING` and what is missing | **do not report the setup as complete** |

Run it from the project root (otherwise it refuses). It runs `git fetch --prune`
itself. It checks the local state (clean tree, no unpushed branch, `main` and
`develop` on the remote and in sync, no setup PR open, the temporary branch deleted,
every tag pushed, the CI and no `ai-attribution` markers on `develop`) and **reads
back from GitHub** what step 4 applied: `develop` as the default branch, the merge
settings, the three rulesets active, the pull request rule and the `Commit messages`
check (bound to GitHub Actions) in effect on `main` and `develop`, and secret
scanning. With `--no-ai-attribution` it also checks that no commit carries AI
attribution.

`?` lines are warnings that do not block: other open PRs (Dependabot's, for example),
rulesets or secret scanning unavailable on the plan, and the default workflow token
permissions (hardening, not part of the setup). Plan limits go to the summary as
pending **with their reason**, never as a failure.

**If it exits `1`**, say exactly what is missing and **ask for permission to finish
it**. If granted, finish it and **run the script again**: what you report is the
second run.

### B. Summary, in the user's language

Identifiers (commands, branches, paths, checks) in their original form. Cover
**every** point; if one does not apply, say so instead of omitting it:

- **Repository**: URL, visibility (chosen by the user) and detected plan.
- **Manager**: answer 2 and which files were created because of it. With an AI, how
  daily work goes from now on ("tell it to upload your work: it proposes a plan, asks
  once and does the rest"), and that it needs the skill and the permission rule of
  check 6 on each machine.
- **AI attribution rule**: answer 3 and what it added or removed (with "people only":
  not asked, removed); with a yes, that no commit or PR carries it (audit check 15).
- **Branches**: `main` and `develop` on the remote; `develop` as the default branch.
- **Initial commit**: the list of files it included.
- **Templates and files created**, and the existing ones that were respected.
- **Merge settings**: as read back by the audit.
- **CI**: what `Commit messages` reported on each PR. Remind the user it is
  stack-agnostic: once the project has code, its jobs must be added and marked as
  required in the rulesets.
- **Rulesets**: active (read back by the audit), or pending with the reason.
- **Security**: what is active and what is unavailable on that plan; the default
  workflow token if the audit warned about it.
- **gitleaks**: what it returned, or that the initial commit went in **unscanned**.
- **Merge policy**: squash into `develop`, merge commit into `main`, PR title as the
  message.
- **License**: only if the repository is public and has no `LICENSE`, warn that
  without a license the code is "all rights reserved" and that choosing one is the
  user's decision. Do not create it.
- **What failed, was skipped or needed improvisation**: always present; if nothing,
  say so.
- **Audit**: nothing pending, or what is left and what you asked.

## Options worth considering

Ask only if the user mentions it or it is unclear:

- **Solo developer or team**: `required_approving_review_count: 0` by default. For a
  team, raise it to 1 or more in both rulesets and change the "Required approvals" row
  of the `CONTRIBUTING.md` table. `merge-pr.sh` never bypasses approvals.
- **CI jobs**: if you rename the job in `ci.yml`, update the `context` in both
  rulesets. Jobs the project adds later are only required if listed in the rulesets.
- **Changing a ruleset rule**: change the `CONTRIBUTING.md` table too.
