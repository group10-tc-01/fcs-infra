#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_DIR="$SCRIPT_DIR/manifests"
REALM_SOURCE="${1:?Usage: deploy-infra.sh /path/to/conexao-solidaria-realm.json}"
KUBECTL="${KUBECTL:-kubectl}"
NAMESPACE=fcs-infra

require() { command -v "$1" >/dev/null 2>&1 || { echo "Missing command: $1" >&2; exit 1; }; }
require "$KUBECTL"
require openssl
require python3

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
trap 'rm -f "$realm_rendered"' EXIT
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
"$KUBECTL" apply -f "$MANIFEST_DIR/20-public-ingress.yaml"
