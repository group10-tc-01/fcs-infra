#!/usr/bin/env bash
set -euo pipefail

K3S_VERSION="${1:?missing K3s version}"
DOMAIN="${2:?missing domain}"
SSH_ALLOWED_CIDRS="${3:?missing SSH allow list}"
DEPLOY_USER="${4:?missing deploy user}"

if [[ $EUID -ne 0 ]]; then
  echo "bootstrap-host must run as root" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends ca-certificates curl docker.io ufw unzip
systemctl enable --now docker

install -d -m 0700 /etc/rancher/k3s
cat > /etc/rancher/k3s/config.yaml <<EOF
write-kubeconfig-mode: "0640"
tls-san:
  - "${DOMAIN}"
disable:
  - traefik
secrets-encryption: true
EOF

if ! command -v k3s >/dev/null 2>&1; then
  curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="$K3S_VERSION" sh -
fi

systemctl enable --now k3s
for _ in $(seq 1 60); do
  kubectl get node >/dev/null 2>&1 && break
  sleep 2
done
kubectl get node >/dev/null

if ! id -u "$DEPLOY_USER" >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash --comment "FCS Kubernetes delivery" "$DEPLOY_USER"
fi
passwd --lock "$DEPLOY_USER" >/dev/null 2>&1 || true
groupadd --force fcs-k3s
usermod -a -G fcs-k3s "$DEPLOY_USER"
install -d -o "$DEPLOY_USER" -g "$DEPLOY_USER" -m 0700 "/home/$DEPLOY_USER/.ssh"
if [[ -f /root/.ssh/authorized_keys ]]; then
  install -o "$DEPLOY_USER" -g "$DEPLOY_USER" -m 0600 /root/.ssh/authorized_keys "/home/$DEPLOY_USER/.ssh/authorized_keys"
fi
chgrp fcs-k3s /etc/rancher/k3s /etc/rancher/k3s/k3s.yaml
chmod 0750 /etc/rancher/k3s
chmod 0640 /etc/rancher/k3s/k3s.yaml

install -d -o root -g root -m 0755 /etc/ssh/sshd_config.d
cat > /etc/ssh/sshd_config.d/90-fcs-hardening.conf <<'EOF'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin prohibit-password
EOF
systemctl restart ssh || systemctl restart sshd

ufw --force reset
ufw default deny incoming
ufw default allow outgoing
IFS=',' read -r -a cidrs <<< "$SSH_ALLOWED_CIDRS"
for cidr in "${cidrs[@]}"; do
  if [[ "$cidr" == "0.0.0.0/0" ]]; then
    # GitHub-hosted runners share dynamic egress. UFW connection limiting can
    # block other runners behind the same address, so SSH remains key-only but
    # is not rate-limited until a runner with fixed egress is available.
    ufw allow 22/tcp
  else
    ufw allow from "$cidr" to any port 22 proto tcp
  fi
done
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

install -d -o root -g root -m 0700 /etc/fcs-infra
echo "FCS VPS bootstrap complete for ${DOMAIN}."
