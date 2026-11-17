# Troubleshooting

- **"Upgrade to GitHub Pro" when applying the rulesets** → the repository is private on
  a plan without rulesets, which pre-flight check 5 warned about. `configure-github.sh`
  reports it as `UNAVAILABLE`; the rulesets go to the summary as pending, with their
  reason. Do **not** offer to make the repository public to get around it: that
  decision was already made and would publish every pushed commit. Revisit it only if
  the user brings it up.

- **`merge-pr.sh` says GitHub rejected the merge because of a review** → the ruleset
  requires approvals (`required_approving_review_count` ≥ 1) and the PR has none. That
  is the correct behavior in team mode: ask for the review. Do not use `--admin`.

- **PR stuck on "Expected — Waiting for status to be reported"** → a required context
  never ran. It is almost always a **job**-level `if` (the job is skipped and reports
  nothing) or a renamed job without updating the rulesets' `context`. The skill's CI
  puts its `if`s at **step** level on purpose: the `Commit messages` job always
  reports.

- **PR stuck waiting for `Commit messages` although the CI is green** → the check was
  posted by something other than GitHub Actions, or the ruleset carries an
  `integration_id` other than `15368`. The rulesets only accept the check from Actions.

- **`Commit messages` fails on `Validate PR title`** → the title is not a Conventional
  Commit, starts with a capitalized word (`Add`; acronyms such as `API` are fine), ends
  with a period or is longer than 100 characters. `Revert "…"` titles from GitHub's
  button are accepted as they are. Fix it by editing the title
  (`gh pr edit <n> --title "..."`): the `edited` event runs the CI again.

- **`Commit messages` fails on `Check source branch`** → a PR into `main` from a branch
  that is not `develop` or `hotfix/*`. Change the PR base to `develop`
  (`gh pr edit <n> --base develop`).

- **A Dependabot PR fails the CI** → check that `.github/dependabot.yml` still has
  `commit-message.prefix: ci`. Without it, Dependabot titles "Bump …" and fails the
  validation.

- **The audit reports `ai-attribution` markers left** → `ai-attribution.sh` was not run
  after copying the templates (or a file was copied after it). Run it with the user's
  answer (`keep` or `remove`) from the project root, commit through a PR and audit
  again.

- **The audit reports merge settings that differ** → something reverted them after
  step 4 (another tool, a manual change). Re-run `configure-github.sh`: it is
  idempotent.

- **Defects that only show up at run time.** The `lint-templates.yml` workflow of the
  `claude-config` repository runs actionlint on the CI template and resolves every
  `uses:` against the API. That catches syntax, expressions and references that do not
  exist, but not what depends on the specific repository at run time (token
  permissions, organization settings). The template never runs in `claude-config`, so
  treat the first PR of every new setup as part of the test and read what the checks
  report.

- **`gh: command not found`** → after installing it a new terminal may be needed, or
  the explicit PATH: `export PATH="/c/Program Files/GitHub CLI:$PATH"`.

- **`configure-github.sh` reports `FAILED` on "default branch"** → `develop` does not
  exist on the remote yet. Do step 3 (create and push `develop`) and re-run the script.
