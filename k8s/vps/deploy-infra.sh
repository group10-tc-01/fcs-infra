#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_DIR="$SCRIPT_DIR/manifests"
REALM_SOURCE="${1:?Usage: deploy-infra.sh /path/to/conexao-solidaria-realm.json}"
KUBECTL="${KUBECTL:-kubectl}"
NAMESPACE=fcs-infra
IDENTITY_MANIFEST_DIR="$SCRIPT_DIR/apps/fcs-identity"
DATADOG_MANIFEST_SOURCE="$MANIFEST_DIR/30-datadog.yaml"
DATADOG_API_KEY_FILE="${DATADOG_API_KEY_FILE:-/etc/fcs-infra/datadog-api-key}"
DATADOG_SITE_FILE="${DATADOG_SITE_FILE:-/etc/fcs-infra/datadog-site}"
DATADOG_SECRET_NAME=fcs-datadog-api-key
TEMP_FILES=()

require() { command -v "$1" >/dev/null 2>&1 || { echo "Missing command: $1" >&2; exit 1; }; }
require "$KUBECTL"
require openssl
require python3
require stat

cleanup() {
  local file
  for file in "${TEMP_FILES[@]}"; do
    rm -f "$file"
  done
}
trap cleanup EXIT

die() {
  echo "deploy-infra: $*" >&2
  exit 1
}

configure_datadog() {
  local datadog_site datadog_manifest_rendered

  [[ -S /run/k3s/containerd/containerd.sock ]] \
    || die "K3s containerd socket not found at /run/k3s/containerd/containerd.sock"

  if [[ -r "$DATADOG_API_KEY_FILE" ]]; then
    [[ "$(stat -c '%u' "$DATADOG_API_KEY_FILE")" == "0" ]] \
      || die "Datadog API key file must be owned by root: $DATADOG_API_KEY_FILE"
    [[ "$(stat -c '%a' "$DATADOG_API_KEY_FILE")" == "600" ]] \
      || die "Datadog API key file must have mode 0600: $DATADOG_API_KEY_FILE"
    if [[ "$(wc -l < "$DATADOG_API_KEY_FILE")" -ne 0 ]] \
      || grep -q '[[:space:]]' "$DATADOG_API_KEY_FILE"; then
      die "Datadog API key file must not contain whitespace or a trailing newline"
    fi
    [[ -s "$DATADOG_API_KEY_FILE" ]] || die "Datadog API key file is empty"

    # Read the key from a root-only file. The value never appears in the
    # process arguments or in workflow output.
    "$KUBECTL" -n "$NAMESPACE" create secret generic "$DATADOG_SECRET_NAME" \
      --from-file=api-key="$DATADOG_API_KEY_FILE" \
      --dry-run=client -o yaml | "$KUBECTL" apply -f -
  elif ! "$KUBECTL" -n "$NAMESPACE" get secret "$DATADOG_SECRET_NAME" >/dev/null 2>&1; then
    die "Datadog API key is not configured. Run ops/vps/bootstrap-datadog.sh on the VPS first."
  else
    echo "Using the existing Kubernetes Secret $NAMESPACE/$DATADOG_SECRET_NAME."
  fi

  datadog_site=datadoghq.com
  if [[ -r "$DATADOG_SITE_FILE" ]]; then
    datadog_site="$(tr -d '\r\n' < "$DATADOG_SITE_FILE")"
  fi
  [[ "$datadog_site" =~ ^[a-z0-9]+([.-][a-z0-9]+)*$ ]] \
    || die "Invalid Datadog site in $DATADOG_SITE_FILE"

  datadog_manifest_rendered="$(mktemp)"
  TEMP_FILES+=("$datadog_manifest_rendered")
  sed "s/__DATADOG_SITE__/$datadog_site/g" \
    "$DATADOG_MANIFEST_SOURCE" > "$datadog_manifest_rendered"
  "$KUBECTL" apply -f "$datadog_manifest_rendered"

  for _ in {1..120}; do
    if "$KUBECTL" -n "$NAMESPACE" get daemonset/fcs-datadog >/dev/null 2>&1 \
      && "$KUBECTL" -n "$NAMESPACE" get deployment/fcs-datadog-cluster-agent >/dev/null 2>&1; then
      break
    fi
    sleep 5
  done

  "$KUBECTL" -n "$NAMESPACE" get daemonset/fcs-datadog >/dev/null 2>&1 \
    || die "Datadog Agent DaemonSet was not created by the K3s Helm controller"
  "$KUBECTL" -n "$NAMESPACE" get deployment/fcs-datadog-cluster-agent >/dev/null 2>&1 \
    || die "Datadog Cluster Agent Deployment was not created by the K3s Helm controller"
  "$KUBECTL" -n "$NAMESPACE" rollout status daemonset/fcs-datadog --timeout=600s
  "$KUBECTL" -n "$NAMESPACE" rollout status deployment/fcs-datadog-cluster-agent --timeout=600s
}

"$KUBECTL" apply -f "$MANIFEST_DIR/00-namespace.yaml"

if ! "$KUBECTL" -n "$NAMESPACE" get secret fcs-infra-runtime >/dev/null 2>&1; then
  sql_password="$(openssl rand -base64 36 | tr -d '\n' | tr '/+' 'Az' | cut -c1-32)"
  keycloak_password="$(openssl rand -base64 36 | tr -d '\n' | tr '/+' 'Bx' | cut -c1-32)"
  manager_password="$(openssl rand -base64 36 | tr -d '\n' | tr '/+' 'Cy' | cut -c1-32)"
  jwt_secret="$(openssl rand -hex 48)"
  kafka_ui_password="$(openssl rand -base64 30 | tr -d '\n' | tr '/+' 'Dz' | cut -c1-24)"
  "$KUBECTL" -n "$NAMESPACE" create secret generic fcs-infra-runtime \
    --from-literal=sql-sa-password="$sql_password" \
    --from-literal=keycloak-admin-password="$keycloak_password" \
    --from-literal=manager-password="$manager_password" \
    --from-literal=jwt-secret-key="$jwt_secret" \
    --from-literal=kafka-ui-password="$kafka_ui_password"
fi

manager_password="$($KUBECTL -n "$NAMESPACE" get secret fcs-infra-runtime -o jsonpath='{.data.manager-password}' | base64 --decode)"
kafka_ui_password="$($KUBECTL -n "$NAMESPACE" get secret fcs-infra-runtime -o jsonpath='{.data.kafka-ui-password}' | base64 --decode)"
realm_rendered="$(mktemp)"
TEMP_FILES+=("$realm_rendered")
MANAGER_PASSWORD="$manager_password" python3 - "$REALM_SOURCE" "$realm_rendered" <<'PY'
import json
import os
import sys

source, target = sys.argv[1:]
with open(source, encoding="utf-8") as stream:
    realm = json.load(stream)
realm["clients"][0]["redirectUris"] = ["https://fcs-web.flaviojcf.com.br/*"]
realm["clients"][0]["webOrigins"] = ["https://fcs-web.flaviojcf.com.br"]
for user in realm.get("users", []):
    if user.get("username") == "gestor@ong.test":
        user["credentials"] = [{"type": "password", "value": os.environ["MANAGER_PASSWORD"], "temporary": False}]
with open(target, "w", encoding="utf-8") as stream:
    json.dump(realm, stream)
PY

"$KUBECTL" -n "$NAMESPACE" create configmap keycloak-realm-config \
  --from-file=conexao-solidaria-realm.json="$realm_rendered" \
  --dry-run=client -o yaml | "$KUBECTL" apply -f -

htpasswd="banca:$(openssl passwd -apr1 "$kafka_ui_password")"
"$KUBECTL" -n "$NAMESPACE" create secret generic kafka-ui-basic-auth \
  --from-literal=users="$htpasswd" \
  --dry-run=client -o yaml | "$KUBECTL" apply -f -

"$KUBECTL" -n "$NAMESPACE" delete job sqlserver-init kafka-topics-init --ignore-not-found
"$KUBECTL" apply -f "$MANIFEST_DIR/10-infra.yaml"
"$KUBECTL" -n "$NAMESPACE" rollout status statefulset/sqlserver --timeout=300s
"$KUBECTL" -n "$NAMESPACE" wait --for=condition=complete job/sqlserver-init --timeout=300s
"$KUBECTL" -n "$NAMESPACE" rollout status statefulset/kafka --timeout=300s
"$KUBECTL" -n "$NAMESPACE" wait --for=condition=complete job/kafka-topics-init --timeout=300s
"$KUBECTL" -n "$NAMESPACE" rollout status statefulset/mongodb --timeout=300s
"$KUBECTL" -n "$NAMESPACE" rollout status deployment/keycloak --timeout=300s
"$KUBECTL" -n "$NAMESPACE" rollout status deployment/kafka-ui --timeout=300s
"$KUBECTL" -n "$NAMESPACE" rollout status deployment/otel-collector --timeout=300s
echo "Applying Datadog Agent and Cluster Agent..."
configure_datadog
"$KUBECTL" apply -f "$MANIFEST_DIR/20-public-ingress.yaml"

echo "Applying static resources for fcs-identity..."
"$KUBECTL" apply -f "$IDENTITY_MANIFEST_DIR/namespace.yaml"

if ! "$KUBECTL" -n fcs-identity get secret identity-runtime >/dev/null 2>&1; then
  sql_sa_password="$($KUBECTL -n "$NAMESPACE" get secret fcs-infra-runtime -o jsonpath='{.data.sql-sa-password}' | base64 --decode)"
  keycloak_admin_password="$($KUBECTL -n "$NAMESPACE" get secret fcs-infra-runtime -o jsonpath='{.data.keycloak-admin-password}' | base64 --decode)"
  manager_password="$($KUBECTL -n "$NAMESPACE" get secret fcs-infra-runtime -o jsonpath='{.data.manager-password}' | base64 --decode)"
  identity_connection="Server=sqlserver-service.fcs-infra.svc.cluster.local,1433;Database=IdentityDb;User Id=sa;Password=${sql_sa_password};Encrypt=False;TrustServerCertificate=True"

  "$KUBECTL" -n fcs-identity create secret generic identity-runtime \
    --from-literal=ConnectionStrings__SqlServer="$identity_connection" \
    --from-literal=Keycloak__AdminPassword="$keycloak_admin_password" \
    --from-literal=ManagerSeed__Password="$manager_password"
fi

if ! "$KUBECTL" -n fcs-identity get secret identity-swagger-basic-auth >/dev/null 2>&1; then
  swagger_users="$($KUBECTL -n "$NAMESPACE" get secret kafka-ui-basic-auth -o jsonpath='{.data.users}' | base64 --decode)"
  "$KUBECTL" -n fcs-identity create secret generic identity-swagger-basic-auth \
    --from-literal=users="$swagger_users"
fi

# Remove the legacy combined Ingress from the manual/app repository setup. The
# split resources above intentionally keep /swagger behind Basic Auth.
"$KUBECTL" -n fcs-identity delete ingress fcs-identity --ignore-not-found

for manifest in configmap.yaml service.yaml rbac.yaml middleware.yaml ingress-api.yaml ingress-swagger.yaml; do
  "$KUBECTL" apply -f "$IDENTITY_MANIFEST_DIR/$manifest"
done
