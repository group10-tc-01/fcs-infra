#!/usr/bin/env bash
set -euo pipefail

DEST_DIR="/etc/fcs-infra"
API_KEY_FILE="$DEST_DIR/datadog-api-key"
SITE_FILE="$DEST_DIR/datadog-site"
DEFAULT_SITE="us5.datadoghq.com"

usage() {
  echo "Usage: sudo bash bootstrap-datadog.sh [datadog-site]" >&2
}

die() {
  echo "bootstrap-datadog: $*" >&2
  exit 1
}

[[ "$EUID" -eq 0 ]] || die "must run as root"
[[ "$#" -le 1 ]] || { usage; exit 2; }

command -v install >/dev/null 2>&1 || die "missing command: install"

site="${1:-$DEFAULT_SITE}"
[[ "$site" =~ ^[a-z0-9]+([.-][a-z0-9]+)*$ ]] || die "invalid Datadog site"

install -d -o root -g root -m 0700 "$DEST_DIR"

if [[ -e "$API_KEY_FILE" ]]; then
  die "$API_KEY_FILE already exists; remove it explicitly before rotating the key"
fi

printf 'Datadog API key (input hidden): '
IFS= read -r -s api_key
printf '\n'
[[ -n "$api_key" ]] || die "API key cannot be empty"
[[ "$api_key" != *[[:space:]]* ]] || die "API key must not contain whitespace"

umask 077
printf '%s' "$api_key" > "$API_KEY_FILE"
unset api_key
printf '%s\n' "$site" > "$SITE_FILE"

chown root:root "$API_KEY_FILE" "$SITE_FILE"
chmod 0600 "$API_KEY_FILE" "$SITE_FILE"

echo "Datadog credentials stored with root-only permissions in $DEST_DIR."
