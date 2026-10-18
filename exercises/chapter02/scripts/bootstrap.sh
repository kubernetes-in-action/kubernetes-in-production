#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

echo "==> Waiting for the Docker daemon to be ready..."
until docker info >/dev/null 2>&1; do
  sleep 1
done

CLUSTER_NAME="chapter02-exercise"
NODE="${CLUSTER_NAME}-control-plane"
NS="api-exploration"
MANIFEST="/etc/kubernetes/manifests/kube-scheduler.yaml"

if kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
  echo "==> Cluster '${CLUSTER_NAME}' already exists, reusing it."
  kind export kubeconfig --name "${CLUSTER_NAME}"
else
  echo "==> Creating kind cluster '${CLUSTER_NAME}' (control-plane + 1 worker)..."
  kind create cluster --name "${CLUSTER_NAME}" --config kind-config.yaml
fi

echo "==> Waiting for all nodes to register..."
kubectl wait --for=condition=Ready node --all --timeout=120s

kubectl create namespace "${NS}" --dry-run=client -o yaml | kubectl apply -f -

echo "==> Breaking kube-scheduler's static pod manifest on ${NODE}..."
if docker exec "${NODE}" grep -q -- "--kubeconfig=/etc/kubernetes/scheduler.conf" "${MANIFEST}"; then
  docker exec "${NODE}" sed -i \
    's#--kubeconfig=/etc/kubernetes/scheduler.conf#--kubeconfig=/etc/kubernetes/scheduler-typo.conf#' \
    "${MANIFEST}"
  echo "    Done. kubelet is watching ${MANIFEST} and will restart the"
  echo "    kube-scheduler static pod against the new, broken flag shortly."
else
  echo "    Already broken (or bootstrap.sh has run before), leaving it as-is."
fi

echo "==> Deploying the canary pod that should get scheduled..."
kubectl run canary -n "${NS}" \
  --image=luksa/kiada:0.7 \
  --overrides='{"spec":{"containers":[{"name":"kiada","image":"luksa/kiada:0.7","resources":{"requests":{"cpu":"100m","memory":"64Mi"},"limits":{"cpu":"250m","memory":"128Mi"}}}]}}' \
  --dry-run=client -o yaml | kubectl apply -f -

echo
echo "================================================================"
echo " Cluster ready. Pod 'canary' has been created in '${NS}'"
echo " but kube-scheduler is broken, so it will sit Pending"
echo " until you fix it. Open EXERCISE.md and start with Task 1."
echo "================================================================"
echo
echo " This terminal will close automatically, open a new one to run"
echo " commands against the cluster."
