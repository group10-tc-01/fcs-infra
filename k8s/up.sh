#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FASE05_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MANIFEST_DIR="$SCRIPT_DIR/manifests"

CLUSTER_NAME="${CLUSTER_NAME:-fcs-local}"
SQL_PASSWORD="${FCS_LOCAL_SQL_PASSWORD:-Your_password123}"
KEYCLOAK_ADMIN_PASSWORD="${FCS_LOCAL_KEYCLOAK_ADMIN_PASSWORD:-admin}"
MANAGER_PASSWORD="${FCS_LOCAL_MANAGER_PASSWORD:-Gestor123!}"
JWT_SECRET_KEY="${FCS_LOCAL_JWT_SECRET_KEY:-local-development-jwt-secret-key-for-fcs-fase05-1234567890}"
DD_SITE="${DD_SITE:-datadoghq.com}"

require_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Missing required command: $command_name" >&2
    exit 1
  fi
}

wait_for_rollout() {
  local namespace="$1"
  local deployment="$2"
  local timeout="${3:-300s}"

  kubectl -n "$namespace" rollout status "deployment/$deployment" --timeout="$timeout"
}

wait_for_job() {
  local namespace="$1"
  local job="$2"
  local timeout="${3:-300s}"

  if ! kubectl -n "$namespace" wait --for=condition=complete "job/$job" --timeout="$timeout"; then
    echo ""
    echo "Job $job failed or timed out. Recent logs:"
    kubectl -n "$namespace" logs "job/$job" --tail=100 || true
    exit 1
  fi
}

create_secret() {
  local namespace="$1"
  local name="$2"
  shift 2

  kubectl -n "$namespace" create secret generic "$name" "$@" --dry-run=client -o yaml | kubectl apply -f -
}

create_ghcr_secret() {
  local namespace="$1"

  if [ -z "${GHCR_USERNAME:-}" ] || [ -z "${GHCR_TOKEN:-}" ]; then
    return
  fi

  kubectl -n "$namespace" create secret docker-registry ghcr-pull-secret \
    --docker-server=ghcr.io \
    --docker-username="$GHCR_USERNAME" \
    --docker-password="$GHCR_TOKEN" \
    --dry-run=client -o yaml | kubectl apply -f -

  kubectl -n "$namespace" patch serviceaccount default \
    -p '{"imagePullSecrets":[{"name":"ghcr-pull-secret"}]}' >/dev/null
}

require_command docker
require_command kind
require_command kubectl

if [ -z "${DD_API_KEY:-}" ]; then
  echo "DD_API_KEY is required to run the local Datadog observability stack." >&2
  echo "Export DD_API_KEY and DD_SITE before running this script." >&2
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "Docker is not running or is not available from this shell." >&2
  exit 1
fi

if ! kind get clusters 2>/dev/null | grep -Fxq "$CLUSTER_NAME"; then
  echo "Creating Kind cluster: $CLUSTER_NAME"
  kind create cluster --name "$CLUSTER_NAME" --config "$SCRIPT_DIR/kind-cluster-config.yaml"
else
  echo "Kind cluster already exists: $CLUSTER_NAME"
  kubectl config use-context "kind-$CLUSTER_NAME" >/dev/null
fi

echo "Applying namespaces"
kubectl apply -f "$MANIFEST_DIR/00-namespaces.yaml"

echo "Creating local infrastructure secrets"
create_secret fcs-infra sqlserver-local-secret \
  --from-literal=sa-password="$SQL_PASSWORD"

create_secret fcs-infra keycloak-local-secret \
  --from-literal=admin-password="$KEYCLOAK_ADMIN_PASSWORD"

create_secret fcs-infra datadog-local-secret \
  --from-literal=api-key="${DD_API_KEY:-}" \
  --from-literal=site="$DD_SITE"

if [ -f "$FASE05_ROOT/fcs-identity/keycloak/conexao-solidaria-realm.json" ]; then
  kubectl -n fcs-infra create configmap keycloak-realm-config \
    --from-file=conexao-solidaria-realm.json="$FASE05_ROOT/fcs-identity/keycloak/conexao-solidaria-realm.json" \
    --dry-run=client -o yaml | kubectl apply -f -
else
  echo "Missing fcs-identity/keycloak/conexao-solidaria-realm.json." >&2
  echo "Clone fcs-identity beside fcs-infra or create keycloak-realm-config manually." >&2
  exit 1
fi

if [ -n "${GHCR_USERNAME:-}" ] && [ -n "${GHCR_TOKEN:-}" ]; then
  echo "Creating GHCR image pull secrets"
  for namespace in fcs-identity fcs-campaign fcs-donations fcs-donation-worker fcs-audit-logs fcs-web; do
    create_ghcr_secret "$namespace"
  done
else
  echo "Skipping GHCR image pull secrets. Set GHCR_USERNAME and GHCR_TOKEN if packages are private."
fi

echo "Creating local application secrets"
create_secret fcs-identity fcs-identity-local-secret \
  --from-literal=sqlserver-connection-string="Server=sqlserver-service.fcs-infra.svc.cluster.local,1433;Database=IdentityDb;User Id=sa;Password=$SQL_PASSWORD;TrustServerCertificate=True;Encrypt=False;" \
  --from-literal=manager-password="$MANAGER_PASSWORD"

create_secret fcs-identity keycloak-client-secret \
  --from-literal=admin-password="$KEYCLOAK_ADMIN_PASSWORD"

create_secret fcs-campaign fcs-campaign-local-secret \
  --from-literal=sqlserver-connection-string="Server=sqlserver-service.fcs-infra.svc.cluster.local,1433;Database=CampaignsDb;User Id=sa;Password=$SQL_PASSWORD;TrustServerCertificate=True;"

create_secret fcs-donations fcs-donations-local-secret \
  --from-literal=sqlserver-connection-string="Server=sqlserver-service.fcs-infra.svc.cluster.local,1433;Database=DonationsDb;User Id=sa;Password=$SQL_PASSWORD;TrustServerCertificate=True;" \
  --from-literal=jwt-secret-key="$JWT_SECRET_KEY"

create_secret fcs-donation-worker fcs-donation-worker-local-secret \
  --from-literal=sqlserver-connection-string="Server=sqlserver-service.fcs-infra.svc.cluster.local,1433;Database=DonationsDb;User Id=sa;Password=$SQL_PASSWORD;TrustServerCertificate=True"

echo "Applying infrastructure"
kubectl apply -f "$MANIFEST_DIR/infra/01-sqlserver.yaml"
wait_for_rollout fcs-infra sqlserver 300s

kubectl -n fcs-infra delete job sqlserver-init --ignore-not-found=true
kubectl apply -f "$MANIFEST_DIR/infra/02-sqlserver-init-job.yaml"
wait_for_job fcs-infra sqlserver-init 300s

kubectl apply -f "$MANIFEST_DIR/infra/03-keycloak.yaml"
kubectl apply -f "$MANIFEST_DIR/infra/04-kafka.yaml"
kubectl apply -f "$MANIFEST_DIR/infra/07-mongodb.yaml"
kubectl apply -f "$MANIFEST_DIR/infra/08-otel-collector.yaml"

wait_for_rollout fcs-infra keycloak 300s
wait_for_rollout fcs-infra kafka 300s
wait_for_rollout fcs-infra mongodb 300s
wait_for_rollout fcs-infra otel-collector 180s

kubectl -n fcs-infra delete job kafka-topics-init --ignore-not-found=true
kubectl apply -f "$MANIFEST_DIR/infra/05-kafka-topics-job.yaml"
wait_for_job fcs-infra kafka-topics-init 300s

kubectl apply -f "$MANIFEST_DIR/infra/06-kafka-ui.yaml"
wait_for_rollout fcs-infra kafka-ui 180s

echo "Applying applications"
kubectl apply -f "$MANIFEST_DIR/apps/fcs-identity"
kubectl apply -f "$MANIFEST_DIR/apps/fcs-campaign"
kubectl apply -f "$MANIFEST_DIR/apps/fcs-donations"
kubectl apply -f "$MANIFEST_DIR/apps/fcs-donation-worker"
kubectl apply -f "$MANIFEST_DIR/apps/fcs-audit-logs"
kubectl apply -f "$MANIFEST_DIR/apps/fcs-web"

wait_for_rollout fcs-identity fcs-identity 300s
wait_for_rollout fcs-campaign fcs-campaign 300s
wait_for_rollout fcs-donations fcs-donations 300s
wait_for_rollout fcs-donation-worker fcs-donation-worker 300s
wait_for_rollout fcs-audit-logs fcs-audit-logs 300s
wait_for_rollout fcs-web fcs-web 180s

echo ""
echo "FCS local Kubernetes is ready."
echo ""
echo "Applications:"
echo "  Web:       http://localhost:4200"
echo "  Identity:  http://localhost:64534"
echo "  Campaign:  http://localhost:55904"
echo "  Donations: http://localhost:5003"
echo ""
echo "Tools:"
echo "  Keycloak: http://localhost:8081"
echo "  Kafka UI: http://localhost:8082"
echo ""
echo "Useful checks:"
echo "  kubectl get pods --all-namespaces"
echo "  curl http://localhost:64534/health"
echo "  curl http://localhost:55904/health"
echo "  curl http://localhost:5003/health"
