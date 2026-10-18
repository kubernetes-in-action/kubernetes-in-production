#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

NS="api-exploration"

echo "==> Deleting Service 'kiada' (a Service that predates a broken"
echo "    kube-proxy keeps working, as the rules already programmed into"
echo "    iptables aren't retroactively removed)..."
kubectl -n "${NS}" delete service kiada --ignore-not-found

echo "==> Breaking kube-proxy's DaemonSet nodeSelector again..."
kubectl -n kube-system patch daemonset kube-proxy --type merge \
  -p '{"spec":{"template":{"spec":{"nodeSelector":{"kubernetes.io/os":"bogus-os"}}}}}'

echo "==> Deleting existing kube-proxy pods so none get rescheduled anywhere..."
kubectl -n kube-system delete pods -l k8s-app=kube-proxy --ignore-not-found
sleep 3

echo "==> Exposing the kiada Service now that kube-proxy is down again..."
kubectl expose deployment kiada -n "${NS}" --port=80 --target-port=8080 \
  --dry-run=client -o yaml | kubectl apply -f -

echo
echo "==> Reset complete. Run scripts/verify.sh to confirm it fails again,"
echo "    then re-attempt the fix."