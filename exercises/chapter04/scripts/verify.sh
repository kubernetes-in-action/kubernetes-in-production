#!/usr/bin/env bash
# Grades the Chapter 4 exercise. Exits 0 only if every check passes.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

NS="api-exploration"

PASS=0
FAIL=0

pass() { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

echo "== Task 1/2: no leftover orphan pods in the namespace (section 4.2.1) =="

TOTAL="$(kubectl -n "${NS}" get pods --no-headers 2>/dev/null | wc -l | tr -d ' ')"
MATCHING="$(kubectl -n "${NS}" get pods -l app=webapp --no-headers 2>/dev/null | wc -l | tr -d ' ')"

if [[ "${TOTAL}" == "3" && "${MATCHING}" == "3" ]]; then
  pass "namespace '${NS}' has exactly 3 pods, all matching app=webapp"
else
  fail "namespace '${NS}' has exactly 3 pods, all matching app=webapp (total=${TOTAL:-<none>}, matching=${MATCHING:-<none>})"
fi

echo
echo "== Task 3: every remaining pod is actually owned by the ReplicaSet =="

ORPHAN_COUNT=0
for p in $(kubectl -n "${NS}" get pods -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
  OWNER="$(kubectl -n "${NS}" get pod "${p}" -o jsonpath='{.metadata.ownerReferences[0].kind}' 2>/dev/null || true)"
  if [[ -z "${OWNER}" ]]; then
    ORPHAN_COUNT=$((ORPHAN_COUNT + 1))
  fi
done
if [[ "${ORPHAN_COUNT}" -eq 0 ]]; then
  pass "no orphaned (ownerReferences-less) pods remain in '${NS}'"
else
  fail "no orphaned (ownerReferences-less) pods remain in '${NS}' (found ${ORPHAN_COUNT})"
fi

READY="$(kubectl -n "${NS}" get deployment webapp -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)"
if [[ "${READY}" == "3" ]]; then
  pass "Deployment 'webapp' reports 3/3 ready replicas"
else
  fail "Deployment 'webapp' reports 3/3 ready replicas (found: ${READY:-<none>})"
fi

echo
echo "================================================================"
if [[ "${FAIL}" -eq 0 ]]; then
  echo " All ${PASS} checks passed."
  exit 0
else
  echo " ${FAIL} check(s) failed, ${PASS} passed. See EXERCISE.md and try again."
  echo " Stuck? cat solution/SOLUTION.md"
  exit 1
fi