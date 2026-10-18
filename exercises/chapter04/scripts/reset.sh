#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

NS="api-exploration"

echo "==> Recreating the mislabel: relabeling one pod out of the Deployment's selector..."
POD="$(kubectl -n "${NS}" get pods -l app=webapp -o jsonpath='{.items[0].metadata.name}')"
kubectl -n "${NS}" label pod "${POD}" app=webapp-drifted --overwrite
sleep 5

echo
echo "==> Reset complete. Run scripts/verify.sh to confirm it fails again,"
echo "    then re-attempt the fix."