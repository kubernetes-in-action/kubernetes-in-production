#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

echo "==> Waiting for the Docker daemon to be ready..."
until docker info >/dev/null 2>&1; do
  sleep 1
done

CLUSTER_NAME="chapter04"

if kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
  echo "==> Cluster '${CLUSTER_NAME}' already exists, reusing it."
  kind export kubeconfig --name "${CLUSTER_NAME}"
else
  echo "==> Creating kind cluster '${CLUSTER_NAME}' (control-plane + 2 workers)..."
  kind create cluster --name "${CLUSTER_NAME}" --config kind-config.yaml
fi

echo "==> Creating namespace 'quiz-ns'..."
kubectl create namespace quiz-ns --dry-run=client -o yaml | kubectl apply -f - >/dev/null

echo "==> Applying starting manifest (quiz StatefulSet + Service)..."
kubectl apply -f manifests/quiz.yaml

echo "==> Waiting for the quiz StatefulSet to become ready..."
kubectl -n quiz-ns rollout status statefulset/quiz --timeout=120s

echo
echo "================================================================"
echo " Cluster ready, quiz StatefulSet deployed. The rest of this"
echo " chapter's manifests (backoff-demo, migration-check,"
echo " quiz-backoff-demo, quiz-stats-cron) are applied by hand as you"
echo " work through the chapter."
echo "================================================================"
echo
echo " This terminal will close automatically, open a new one to run"
echo " commands against the cluster."
