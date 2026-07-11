#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K3S_MANIFEST_DIR="/var/lib/rancher/k3s/server/manifests"
COOLIFY_DYNAMIC_DIR="/data/coolify/proxy/dynamic"
PUBLIC_IP="179.197.65.69"
REALM_SOURCE="${1:-}"

HOSTS=(
  "fcs-web.flaviojcf.com.br"
  "fcs-bff.flaviojcf.com.br"
  "fcs-identity.flaviojcf.com.br"
  "fcs-campaign.flaviojcf.com.br"
  "fcs-donations.flaviojcf.com.br"
  "fcs-keycloak.flaviojcf.com.br"
  "fcs-kafka.flaviojcf.com.br"
)

usage() {
  echo "Uso: sudo bash up.sh /caminho/conexao-solidaria-realm.json" >&2
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Comando obrigatório não encontrado: $1" >&2
    exit 1
  }
}

if [[ -z "$REALM_SOURCE" || $# -ne 1 ]]; then
  usage
  exit 2
fi

if [[ $EUID -ne 0 ]]; then
  exec sudo -- "$0" "$@"
fi

[[ -f "$REALM_SOURCE" ]] || {
  echo "Arquivo do realm não encontrado: $REALM_SOURCE" >&2
  exit 1
}

for command in kubectl docker getent install; do
  require_command "$command"
done

systemctl is-active --quiet k3s || {
  echo "O serviço k3s não está ativo." >&2
  exit 1
}

[[ "$(docker inspect --format '{{.State.Running}}' coolify-proxy 2>/dev/null || true)" == "true" ]] || {
  echo "O container coolify-proxy não está em execução." >&2
  exit 1
}

if docker ps --format '{{.Image}}' | grep -Eiq 'datadog.*agent'; then
  echo "Aviso: um Datadog Agent Docker foi detectado; valide a duplicidade de métricas do host após ativar o Agent do K3s."
fi

for host in "${HOSTS[@]}"; do
  getent ahostsv4 "$host" | awk '{print $1}' | sort -u | grep -qx "$PUBLIC_IP" || {
    echo "DNS inválido para $host; esperado: $PUBLIC_IP" >&2
    exit 1
  }
done

echo "Instalando Traefik interno no K3s..."
install -D -m 600 \
  "$SCRIPT_DIR/traefik-internal.yaml" \
  "$K3S_MANIFEST_DIR/fcs-traefik-internal.yaml"

for _ in {1..60}; do
  if kubectl -n fcs-platform get deployment fcs-traefik-internal >/dev/null 2>&1; then
    break
  fi
  sleep 5
done

kubectl -n fcs-platform get deployment fcs-traefik-internal >/dev/null 2>&1 || {
  echo "O deployment do Traefik interno não foi criado em até 5 minutos." >&2
  exit 1
}

kubectl -n fcs-platform rollout status deployment/fcs-traefik-internal --timeout=300s

echo "Aplicando a infraestrutura persistente..."
"$SCRIPT_DIR/deploy-infra.sh" "$REALM_SOURCE"

echo "Publicando o roteamento Coolify para o K3s..."
install -d -m 700 "$COOLIFY_DYNAMIC_DIR"
install -o 9999 -g 0 -m 600 \
  "$SCRIPT_DIR/coolify-fcs-k3s.yaml" \
  "$COOLIFY_DYNAMIC_DIR/fcs-k3s.yaml"

echo
echo "Infraestrutura FCS ativa."
kubectl get nodes
kubectl -n fcs-infra get pods,pvc,ingress
