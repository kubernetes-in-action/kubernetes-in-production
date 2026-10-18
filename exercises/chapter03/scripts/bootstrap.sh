#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

echo "==> Waiting for the Docker daemon to be ready..."
until docker info >/dev/null 2>&1; do
  sleep 1
done

CLUSTER_NAME="chapter03-exercise"
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

echo "==> Deploying the kiada app (kube-proxy is still healthy for this)..."
kubectl create deployment kiada -n "${NS}" --image=luksa/kiada:0.7 --replicas=2 \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "${NS}" set resources deployment/kiada \
  --requests=cpu=100m,memory=64Mi --limits=cpu=250m,memory=128Mi
kubectl -n "${NS}" rollout status deployment/kiada --timeout=120s

echo "==> Deploying a netcheck client pod..."
kubectl run netcheck -n "${NS}" --image=curlimages/curl:8.10.1 \
  --dry-run=client -o yaml \
  --command -- sleep infinity | kubectl apply -f -
kubectl -n "${NS}" wait --for=condition=Ready pod/netcheck --timeout=60s

echo "==> Breaking kube-proxy's DaemonSet nodeSelector..."
kubectl -n kube-system patch daemonset kube-proxy --type merge \
  -p '{"spec":{"template":{"spec":{"nodeSelector":{"kubernetes.io/os":"bogus-os"}}}}}'

echo "==> Deleting existing kube-proxy pods so none get rescheduled anywhere..."
kubectl -n kube-system delete pods -l k8s-app=kube-proxy --ignore-not-found
sleep 3

echo "==> Exposing the kiada Service now that kube-proxy is down..."
kubectl expose deployment kiada -n "${NS}" --port=80 --target-port=8080 \
  --dry-run=client -o yaml | kubectl apply -f -

echo
echo "================================================================"
echo " Cluster ready. Deployment 'kiada' (2 replicas) is Running/Ready,"
echo " and Service 'kiada' exists in '${NS}'."
echo " kube-proxy never got a chance to program its routing. Open"
echo " EXERCISE.md and start with Task 1."
echo "================================================================"
echo
echo " This terminal will close automatically, open a new one to run"
echo " commands against the cluster."
