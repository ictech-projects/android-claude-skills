#!/usr/bin/env bash
#
# verify-skills.sh — CI gate for the android-compose-review plugin bundle.
#
# Asserts that every skill the orchestrator (android-compose-code-review) routes
# to actually exists in this plugin's skills/ dir. The required set is DERIVED
# from the orchestrator's routing-table references (`/android-compose-review:<name>`),
# so it stays in sync automatically: add a routing row -> the gate requires that
# skill; no separate manifest to update.
#
# Exit 0 = all routed skills present. Exit 1 = at least one missing (fails the build).
#
# Usage (any cwd):
#   plugins/android-compose-review/scripts/verify-skills.sh
#   "${CLAUDE_PLUGIN_ROOT}/scripts/verify-skills.sh"   # when invoked from an installed plugin

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_DIR="$PLUGIN_ROOT/skills"
ORCHESTRATOR="$SKILLS_DIR/android-compose-code-review/SKILL.md"

fail=0

echo "Verifying plugin skill bundle in: $SKILLS_DIR"
echo

if [[ ! -f "$ORCHESTRATOR" ]]; then
  echo "FAIL: orchestrator skill not found at $ORCHESTRATOR"
  exit 1
fi

# Extract every routed skill name from the orchestrator's namespaced references:
#   /android-compose-review:<name>   (excluding self-references)
required="$(grep -oE '/android-compose-review:[a-z0-9-]+' "$ORCHESTRATOR" \
  | sed -E 's#/android-compose-review:##' \
  | grep -vx 'android-compose-code-review' \
  | sort -u)"

if [[ -z "$required" ]]; then
  echo "FAIL: no routed skills found in orchestrator — routing table may be broken."
  exit 1
fi

count=0
while IFS= read -r name; do
  [[ -z "$name" ]] && continue
  count=$((count + 1))
  if [[ -f "$SKILLS_DIR/$name/SKILL.md" ]]; then
    printf '  ok    %s\n' "$name"
  else
    printf '  MISS  %s   (expected %s/%s/SKILL.md)\n' "$name" "$SKILLS_DIR" "$name"
    fail=1
  fi
done <<< "$required"

echo
if [[ "$fail" -ne 0 ]]; then
  echo "RESULT: FAIL — $count routed skill(s) checked, one or more missing."
  echo "Restore missing skills per plugins/android-compose-review/ATTRIBUTION.md (vendored from chrisbanes/skills)."
  exit 1
fi

echo "RESULT: OK — all $count routed skills present."