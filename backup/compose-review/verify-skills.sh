#!/usr/bin/env bash
#
# verify-skills.sh — CI gate for the vendored Compose/Kotlin review skills.
#
# Asserts that every skill the orchestrator (android-compose-code-review) routes
# to actually exists on disk. The required set is DERIVED from the orchestrator's
# routing-table links (`../<name>/SKILL.md`), so it stays in sync automatically:
# add a routing row -> the gate requires that skill; no separate manifest to update.
#
# Exit 0 = all routed skills present. Exit 1 = at least one missing (fails the build).
#
# Usage:
#   .claude/skills/verify-skills.sh
#   (run from anywhere; paths resolve relative to this script)

set -euo pipefail

SKILLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORCHESTRATOR="$SKILLS_DIR/android-compose-code-review/SKILL.md"

fail=0

echo "Verifying vendored review skills in: $SKILLS_DIR"
echo

# 1. The orchestrator itself must exist.
if [[ ! -f "$ORCHESTRATOR" ]]; then
  echo "FAIL: orchestrator skill not found at $ORCHESTRATOR"
  exit 1
fi

# 2. Extract every routed skill name from the orchestrator's links:  ../<name>/SKILL.md
#    Sorted + de-duped so each skill is checked once.
required="$(grep -oE '\.\./[a-z0-9-]+/SKILL\.md' "$ORCHESTRATOR" \
  | sed -E 's#\.\./([a-z0-9-]+)/SKILL\.md#\1#' \
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
  echo "Restore missing skills per .claude/skills/ATTRIBUTION.md (vendored from chrisbanes/skills)."
  exit 1
fi

echo "RESULT: OK — all $count routed skills present."