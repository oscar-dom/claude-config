#!/usr/bin/env bash
#
# Resolve every `uses: owner/repo@ref` in the repo against the GitHub API.
#
# actionlint validates the *syntax* of a `uses:` line but never resolves it, so
# a tag that was never published passes lint and only blows up once a real
# project runs the template. That is exactly how `astral-sh/setup-uv@v10`
# shipped: Astral stopped publishing floating major tags after v7, so neither a
# `v10` tag nor a `v10` branch exists.
#
# Needs `gh` authenticated (GH_TOKEN in CI).

set -euo pipefail

mapfile -t refs < <(
  grep -rhoE 'uses:[[:space:]]*[A-Za-z0-9._-]+/[A-Za-z0-9._/-]+@[A-Za-z0-9._-]+' \
    --include='*.yml' --include='*.yaml' . \
  | sed -E 's/^uses:[[:space:]]*//' \
  | sort -u
)

if [ ${#refs[@]} -eq 0 ]; then
  echo "No action refs found."
  exit 0
fi

fail=0
for ref in "${refs[@]}"; do
  spec="${ref%@*}"
  rev="${ref##*@}"
  # `owner/repo/sub/path@ref` points at an action inside owner/repo.
  repo="$(printf '%s' "$spec" | cut -d/ -f1,2)"

  if   gh api "repos/$repo/git/ref/tags/$rev"  >/dev/null 2>&1; then kind="tag"
  elif gh api "repos/$repo/git/ref/heads/$rev" >/dev/null 2>&1; then kind="branch"
  elif gh api "repos/$repo/commits/$rev"       >/dev/null 2>&1; then kind="commit"
  else
    echo "::error::$ref does not resolve — no tag, branch or commit '$rev' in $repo"
    fail=1
    continue
  fi
  printf 'ok  %-50s (%s)\n' "$ref" "$kind"
done

exit "$fail"
