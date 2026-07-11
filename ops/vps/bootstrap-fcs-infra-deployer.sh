#!/usr/bin/env bash
set -euo pipefail

USER_NAME="fcs-infra-deployer"
WRAPPER_TARGET="/usr/local/sbin/fcs-infra-apply"
SUDOERS_TARGET="/etc/sudoers.d/fcs-infra-deployer"
RELEASE_ROOT="/opt/fcs-infra/releases"
SSH_DIR="/home/$USER_NAME/.ssh"
AUTHORIZED_KEYS_TARGET="$SSH_DIR/authorized_keys"

usage() {
  echo "Usage: sudo bash bootstrap-fcs-infra-deployer.sh <wrapper> <sudoers> <public-key>" >&2
}

die() {
  echo "bootstrap-fcs-infra-deployer: $*" >&2
  exit 1
}

[[ "$EUID" -eq 0 ]] || die "must run as root"
[[ "$#" -eq 3 ]] || { usage; exit 2; }

wrapper_source="$1"
sudoers_source="$2"
public_key_source="$3"
[[ -f "$wrapper_source" ]] || die "wrapper source not found"
[[ -f "$sudoers_source" ]] || die "sudoers source not found"
[[ -f "$public_key_source" ]] || die "public key source not found"

for command in install useradd usermod passwd visudo ssh-keygen; do
  command -v "$command" >/dev/null 2>&1 || die "missing command: $command"
done

public_key="$(awk '
  /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
  { if (++count > 1) exit 1; line=$0 }
  END { if (count != 1) exit 1; print line }
' "$public_key_source")" || die "public key file must contain exactly one key"
[[ "$public_key" =~ ^(ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521|ssh-rsa|rsa-sha2-256|rsa-sha2-512)[[:space:]] ]] \
  || die "unsupported public key format"
printf '%s\n' "$public_key" | ssh-keygen -lf - >/dev/null 2>&1 \
  || die "invalid public key"

if ! id -u "$USER_NAME" >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash --comment "FCS infrastructure delivery" "$USER_NAME"
fi
usermod --shell /bin/bash "$USER_NAME"
passwd --lock "$USER_NAME" >/dev/null 2>&1 || true

install -d -o root -g root -m 0755 /opt/fcs-infra
install -d -o "$USER_NAME" -g "$USER_NAME" -m 0750 "$RELEASE_ROOT"
install -o root -g root -m 0755 "$wrapper_source" "$WRAPPER_TARGET"
install -o root -g root -m 0440 "$sudoers_source" "$SUDOERS_TARGET"
visudo -cf "$SUDOERS_TARGET" >/dev/null

install -d -o "$USER_NAME" -g "$USER_NAME" -m 0700 "$SSH_DIR"
printf 'restrict %s\n' "$public_key" | install -o "$USER_NAME" -g "$USER_NAME" -m 0600 /dev/stdin "$AUTHORIZED_KEYS_TARGET"

echo "Configured $USER_NAME with key-only SSH and restricted infrastructure sudo."
