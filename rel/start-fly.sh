#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${TS_AUTHKEY:-}" ]]; then
  printf 'starting tailscaled\n'
  /usr/local/bin/tailscaled \
    --state=mem: \
    --socket=/var/run/tailscale/tailscaled.sock \
    --tun=tailscale0 \
    >/var/log/tailscaled.log 2>&1 &

  for _ in 1 2 3 4 5 6 7 8 9 10; do
    [[ -S /var/run/tailscale/tailscaled.sock ]] && break
    sleep 0.5
  done

  printf 'authenticating with tailnet\n'
  /usr/local/bin/tailscale up \
    --authkey="${TS_AUTHKEY}" \
    --hostname="fly-droodotfoo-${FLY_MACHINE_ID:-unknown}" \
    --accept-dns=false \
    --ephemeral

  printf 'tailscale ip: %s\n' "$(/usr/local/bin/tailscale ip -4 2>/dev/null || printf 'unknown')"
else
  printf 'TS_AUTHKEY not set, skipping tailscale (wiki sync will no-op)\n'
fi

exec /app/bin/server
