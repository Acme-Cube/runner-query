#!/usr/bin/env bash
# Inventory self-hosted runner versions so you can catch out-of-date runners
# BEFORE GitHub's minimum-version enforcement deadline.
#
# Best-effort and safe to run anywhere: if the org endpoint isn't accessible
# (e.g. a personal repo, or a token without admin:org), it reports nothing and
# exits 0 so CI stays green.
#
# Requires: gh CLI (preinstalled on GitHub-hosted runners) + a token.
#   GH_ORG   - org login to audit (defaults to the repo owner)
#   GH_TOKEN - token with `admin:org` to read Actions runners
set -uo pipefail

ORG="${GH_ORG:-}"
if [[ -z "$ORG" ]]; then
  echo "No GH_ORG provided; nothing to audit."
  exit 0
fi

echo "🔎 Auditing self-hosted runner versions for org: $ORG"

# Pull the org's self-hosted runners. Tolerate failure (no access / personal acct).
runners_json="$(gh api "orgs/$ORG/actions/runners" --paginate 2>/dev/null || true)"

if [[ -z "$runners_json" ]] || ! echo "$runners_json" | jq -e '.runners' >/dev/null 2>&1; then
  echo "ℹ️  No org-level runners visible (or insufficient permissions). Nothing to report."
  exit 0
fi

count="$(echo "$runners_json" | jq '[.runners[]] | length')"
echo "Found $count self-hosted runner(s)."

# List each runner: name, status, OS. (Agent version is shown in the runner host
# logs / settings UI; use this list to drive an upgrade sweep.)
echo "$runners_json" | jq -r '
  .runners[] | "  • \(.name)  status=\(.status)  os=\(.os)  labels=[\([.labels[].name] | join(","))]"
'

echo ""
echo "➡️  Action: upgrade any runner below the enforced minimum, and enable"
echo "    auto-update on the runner host so this doesn't recur."
