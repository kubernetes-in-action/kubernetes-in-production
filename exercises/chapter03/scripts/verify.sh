#!/usr/bin/env bash
# Grades the Chapter 3 exercise. Exits 0 only if every check passes.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

NS="api-exploration"

PASS=0
FAIL=0

pass() { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

echo "== Task 1: fix kube-proxy's DaemonSet (section 3.4) =="

SELECTOR="$(kubectl -n kube-system get daemonset kube-proxy \
  -o jsonpath='{.spec.template.spec.nodeSelector.kubernetes\.io/os}' 2>/dev/null || true)"
if [[ "${SELECTOR}" == "linux" ]]; then
  pass "kube-proxy DaemonSet's nodeSelector is back to kubernetes.io/os=linux"
else
  fail "kube-proxy DaemonSet's nodeSelector is back to kubernetes.io/os=linux (found: ${SELECTOR:-<none>})"
fi

DESIRED="$(kubectl -n kube-system get daemonset kube-proxy -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || true)"
READY="$(kubectl -n kube-system get daemonset kube-proxy -o jsonpath='{.status.numberReady}' 2>/dev/null || true)"
NODE_COUNT="$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')"
if [[ -n "${READY}" && "${READY}" == "${DESIRED}" && "${DESIRED}" == "${NODE_COUNT}" && "${DESIRED}" != "0" ]]; then
  pass "kube-proxy DaemonSet is fully scheduled and Ready on all ${NODE_COUNT} nodes"
else
  fail "kube-proxy DaemonSet is fully scheduled and Ready on all nodes (desired=${DESIRED:-<none>}, ready=${READY:-<none>}, nodes=${NODE_COUNT:-<none>})"
fi

echo
echo "== Task 2: confirm the kiada Service actually routes traffic (section 3.4.2) =="

CODE="$(kubectl -n "${NS}" exec netcheck -- \
  curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://kiada 2>/dev/null || true)"
if [[ "${CODE}" == "200" ]]; then
  pass "curl from pod 'netcheck' to http://kiada returns 200"
else
  fail "curl from pod 'netcheck' to http://kiada returns 200 (got: ${CODE:-<none>})"
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