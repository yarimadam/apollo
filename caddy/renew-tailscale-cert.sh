#!/usr/bin/env bash
# Production host only — fetches/renews the real Let's Encrypt cert Tailscale
# issues for PORTAINER_DOMAIN (a *.ts.net MagicDNS name) and reloads Caddy so
# it picks up the renewed files. Run manually once, then on a cron schedule
# (Tailscale/Let's Encrypt certs are ~90 days; a weekly cron is safe — `tailscale
# cert` is a no-op if the existing cert isn't close to expiring).
#
# Not for local dev: local dev uses CADDY_INTERNAL_TLS=tls internal and never
# touches this script.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

set -a
source .env
set +a

if [ -z "${PORTAINER_DOMAIN:-}" ]; then
	echo "PORTAINER_DOMAIN is not set in .env" >&2
	exit 1
fi

CERT_DIR="caddy/tailscale-certs"
mkdir -p "$CERT_DIR"

sudo tailscale cert \
	--cert-file "$CERT_DIR/cert.pem" \
	--key-file "$CERT_DIR/key.pem" \
	"$PORTAINER_DOMAIN"

sudo chmod 644 "$CERT_DIR/cert.pem"
sudo chmod 644 "$CERT_DIR/key.pem"

docker compose --env-file .env -f caddy/compose.yaml exec caddy caddy reload --config /etc/caddy/Caddyfile
