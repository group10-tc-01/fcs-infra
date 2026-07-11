#!/usr/bin/env bash
set -euo pipefail

K3S_MANIFEST="/var/lib/rancher/k3s/server/manifests/fcs-traefik-internal.yaml"
COOLIFY_DYNAMIC_CONFIG="/data/coolify/proxy/dynamic/fcs-k3s.yaml"

usage() {
  cat >&2 <<'EOF'
Uso: sudo bash down.sh --purge

--purge remove permanentemente os recursos FCS da fase 2, incluindo os PVCs
local-path e seus dados: SQL Server, Kafka e MongoDB.

Não remove o K3s base, Coolify, Docker, DNS, configurações de outros projetos
nem namespaces que não pertencem à plataforma FCS.
EOF
}

if [[ $# -ne 1 || "$1" != "--purge" ]]; then
  usage
  exit 2
fi

if [[ $EUID -ne 0 ]]; then
  exec sudo -- "$0" "$@"
fi

command -v kubectl >/dev/null 2>&1 || {
  echo "Comando obrigatório não encontrado: kubectl" >&2
  exit 1
}

systemctl is-active --quiet k3s || {
  echo "O serviço k3s não está ativo." >&2
  exit 1
}

echo "Removendo o roteamento FCS do Coolify..."
rm -f "$COOLIFY_DYNAMIC_CONFIG"

echo "Removendo a infraestrutura persistente e seus volumes..."
kubectl delete namespace fcs-infra --ignore-not-found --wait=true --timeout=300s

echo "Removendo o Traefik interno da plataforma FCS..."
rm -f "$K3S_MANIFEST"
kubectl -n kube-system delete helmchart fcs-traefik-internal --ignore-not-found
kubectl delete namespace fcs-platform --ignore-not-found --wait=true --timeout=300s

echo
echo "Purge concluído. K3s base e Coolify foram preservados."
