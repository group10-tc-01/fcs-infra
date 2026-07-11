#!/usr/bin/env bash
set -euo pipefail

K3S_MANIFEST="/var/lib/rancher/k3s/server/manifests/fcs-traefik-internal.yaml"
COOLIFY_DYNAMIC_CONFIG="/data/coolify/proxy/dynamic/fcs-k3s.yaml"

usage() {
  cat >&2 <<'EOF'
Uso: sudo bash down.sh --purge PURGE_FCS

O purge remove permanentemente os recursos FCS desta fase, incluindo os PVCs
local-path e seus dados: SQL Server, Kafka e MongoDB.

Nao remove o K3s base, Coolify, Docker, DNS, configuracoes de outros projetos
nem namespaces que nao pertencem a plataforma FCS.
EOF
}

if [[ $# -ne 2 || "$1" != "--purge" || "$2" != "PURGE_FCS" ]]; then
  usage
  exit 2
fi

if [[ $EUID -ne 0 ]]; then
  exec sudo -- "$0" "$@"
fi

command -v kubectl >/dev/null 2>&1 || {
  echo "Comando obrigatorio nao encontrado: kubectl" >&2
  exit 1
}

systemctl is-active --quiet k3s || {
  echo "O servico k3s nao esta ativo." >&2
  exit 1
}

echo "Removendo o roteamento FCS do Coolify..."
rm -f "$COOLIFY_DYNAMIC_CONFIG"

echo "Removendo a infraestrutura persistente e seus volumes..."
kubectl delete namespace fcs-identity --ignore-not-found --wait=true --timeout=300s
kubectl delete namespace fcs-infra --ignore-not-found --wait=true --timeout=300s

echo "Removendo o Traefik interno da plataforma FCS..."
rm -f "$K3S_MANIFEST"
kubectl -n kube-system delete helmchart fcs-traefik-internal --ignore-not-found
kubectl delete namespace fcs-platform --ignore-not-found --wait=true --timeout=300s

echo
echo "Purge concluido. K3s base e Coolify foram preservados."
