#!/usr/bin/env bash
# Grades the Chapter 2 exercise. Exits 0 only if every check passes.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

CLUSTER_NAME="chapter02-exercise"
NODE="${CLUSTER_NAME}-control-plane"
NS="api-exploration"
MANIFEST="/etc/kubernetes/manifests/kube-scheduler.yaml"

PASS=0
FAIL=0

pass() { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

echo "== Task 1: fix kube-scheduler (sections 2.1 & 2.4) =="

if docker exec "${NODE}" grep -q -- "--kubeconfig=/etc/kubernetes/scheduler-typo.conf" "${MANIFEST}" 2>/dev/null; then
  fail "kube-scheduler.yaml still points --kubeconfig at the broken path"
else
  pass "kube-scheduler.yaml's --kubeconfig flag has been fixed"
fi

SCHED_READY="$(kubectl -n kube-system get pods -l component=kube-scheduler \
  -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null || true)"
if [[ "${SCHED_READY}" == "true" ]]; then
  pass "kube-scheduler pod is Running and Ready"
else
  fail "kube-scheduler pod is Running and Ready (found ready=${SCHED_READY:-<none>})"
fi

CANARY_PHASE="$(kubectl -n "${NS}" get pod canary -o jsonpath='{.status.phase}' 2>/dev/null || true)"
CANARY_NODE="$(kubectl -n "${NS}" get pod canary -o jsonpath='{.spec.nodeName}' 2>/dev/null || true)"
if [[ "${CANARY_PHASE}" == "Running" && -n "${CANARY_NODE}" ]]; then
  pass "pod canary is Running, scheduled onto node '${CANARY_NODE}'"
else
  fail "pod canary is Running with a node assigned (phase=${CANARY_PHASE:-<none>}, nodeName=${CANARY_NODE:-<none>})"
fi

echo
echo "== Task 2: confirm it in etcd (sections 2.3.1 & 2.3.2) =="

ETCD_POD="$(kubectl -n kube-system get pod -l component=etcd -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
ETCD_FLAGS="--endpoints=https://127.0.0.1:2379 \
--cacert=/etc/kubernetes/pki/etcd/ca.crt \
--cert=/etc/kubernetes/pki/etcd/server.crt \
--key=/etc/kubernetes/pki/etcd/server.key"

if [[ -z "${ETCD_POD}" ]]; then
  fail "found the etcd static pod"
  fail "etcd endpoint health"
  fail "canary's key is present under /registry/pods/${NS}"
else
  pass "found the etcd static pod (${ETCD_POD})"

  HEALTH="$(kubectl -n kube-system exec "${ETCD_POD}" -- etcdctl ${ETCD_FLAGS} endpoint health 2>/dev/null || true)"
  if [[ "${HEALTH}" == *"healthy"* ]]; then
    pass "etcd reports healthy via 'etcdctl endpoint health'"
  else
    fail "etcd reports healthy via 'etcdctl endpoint health' (got: ${HEALTH:-<none>})"
  fi

  KEYS="$(kubectl -n kube-system exec "${ETCD_POD}" -- \
    etcdctl ${ETCD_FLAGS} get "/registry/pods/${NS}" --prefix --keys-only 2>/dev/null || true)"
  if [[ "${KEYS}" == *"/registry/pods/${NS}/canary"* ]]; then
    pass "canary's key is present under /registry/pods/${NS}"
  else
    fail "canary's key is present under /registry/pods/${NS} (got: ${KEYS:-<none>})"
  fi
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