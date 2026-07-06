#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-fcs-local}"
DELETE_CLUSTER="false"

for arg in "$@"; do
  case "$arg" in
    --cluster)
      DELETE_CLUSTER="true"
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      echo "Usage: bash down.sh [--cluster]" >&2
      exit 1
      ;;
  esac
done

if [ "$DELETE_CLUSTER" = "true" ]; then
  echo "Deleting Kind cluster: $CLUSTER_NAME"
  kind delete cluster --name "$CLUSTER_NAME"
  exit 0
fi

echo "Deleting local FCS namespaces"
kubectl delete namespace fcs-web --ignore-not-found=true
kubectl delete namespace fcs-audit-logs --ignore-not-found=true
kubectl delete namespace fcs-donation-worker --ignore-not-found=true
kubectl delete namespace fcs-donations --ignore-not-found=true
kubectl delete namespace fcs-campaign --ignore-not-found=true
kubectl delete namespace fcs-identity --ignore-not-found=true
kubectl delete namespace fcs-infra --ignore-not-found=true

echo ""
echo "Namespaces removed. The Kind cluster was kept."
echo "To delete the cluster too, run: bash down.sh --cluster"
