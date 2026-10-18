#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

CLUSTER_NAME="chapter02-exercise"
NODE="${CLUSTER_NAME}-control-plane"
NS="api-exploration"
MANIFEST="/etc/kubernetes/manifests/kube-scheduler.yaml"

echo "==> Deleting the canary pod..."
kubectl -n "${NS}" delete pod canary --ignore-not-found

echo "==> Breaking kube-scheduler's static pod manifest on ${NODE}..."
if docker exec "${NODE}" grep -q -- "--kubeconfig=/etc/kubernetes/scheduler.conf" "${MANIFEST}"; then
  docker exec "${NODE}" sed -i \
    's#--kubeconfig=/etc/kubernetes/scheduler.conf#--kubeconfig=/etc/kubernetes/scheduler-typo.conf#' \
    "${MANIFEST}"
else
  echo "    Already broken, nothing to do."
fi

echo "==> Waiting for kube-scheduler to crash-loop again..."
sleep 5

echo "==> Creating the canary pod..."
kubectl run canary -n "${NS}" \
  --image=luksa/kiada:0.7 \
  --overrides='{"spec":{"containers":[{"name":"kiada","image":"luksa/kiada:0.7","resources":{"requests":{"cpu":"100m","memory":"64Mi"},"limits":{"cpu":"250m","memory":"128Mi"}}}]}}' \
  --dry-run=client -o yaml | kubectl apply -f -

echo "==> Reset complete. Pod 'canary' is Pending again, back to Task 1."