#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

echo "==> Waiting for the Docker daemon to be ready..."
until docker info >/dev/null 2>&1; do
  sleep 1
done

CLUSTER_NAME="chapter04-exercise"
NS="api-exploration"

if kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
  echo "==> Cluster '${CLUSTER_NAME}' already exists, reusing it."
  kind export kubeconfig --name "${CLUSTER_NAME}"
else
  echo "==> Creating kind cluster '${CLUSTER_NAME}' (control-plane + 2 workers)..."
  kind create cluster --name "${CLUSTER_NAME}" --config kind-config.yaml
fi

echo "==> Waiting for all nodes to register..."
kubectl wait --for=condition=Ready node --all --timeout=120s

kubectl create namespace "${NS}" --dry-run=client -o yaml | kubectl apply -f -

echo "==> Deploying webapp (3 replicas)..."
kubectl create deployment webapp -n "${NS}" --image=nginx:1.30 --replicas=3 \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "${NS}" rollout status deployment/webapp --timeout=120s

echo "==> Simulating a mislabel: relabeling one pod out of the Deployment's selector..."
POD="$(kubectl -n "${NS}" get pods -l app=webapp -o jsonpath='{.items[0].metadata.name}')"
kubectl -n "${NS}" label pod "${POD}" app=webapp-drifted --overwrite
sleep 5

echo
echo "================================================================"
echo " Cluster ready. Deployment 'webapp' in '${NS}'"
echo " reports 3/3 replicas Ready, but something isn't right. Open"
echo " EXERCISE.md and start with Task 1."
echo "================================================================"
echo
echo " This terminal will close automatically, open a new one to run"
echo " commands against the cluster."
