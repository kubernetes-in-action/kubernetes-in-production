#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

echo "==> Waiting for the Docker daemon to be ready..."
until docker info >/dev/null 2>&1; do
  sleep 1
done

CLUSTER_NAME="chapter02"

if kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
  echo "==> Cluster '${CLUSTER_NAME}' already exists, reusing it."
  kind export kubeconfig --name "${CLUSTER_NAME}"
else
  echo "==> Creating kind cluster '${CLUSTER_NAME}' (control-plane + 2 workers)..."
  kind create cluster --name "${CLUSTER_NAME}" --config kind-config.yaml
fi

echo
echo "================================================================"
echo " Cluster ready. This chapter is about exploring the components"
echo " created by kind (API server, scheduler, controller manager,"
echo " etcd). Follow the book from here."
echo "================================================================"
echo
echo " This terminal will close automatically, open a new one to run"
echo " commands against the cluster."
