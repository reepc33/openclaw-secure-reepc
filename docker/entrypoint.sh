#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPENCLAW_USER_ID="${OPENCLAW_USER_ID:-1000}"
OPENCLAW_TOKEN="${OPENCLAW_TOKEN:-}"

log() { echo "[entrypoint] $*"; }

 
if [ "$(id -u)" -eq 0 ]; then
  if command -v su >/dev/null 2>&1; then
    log "Dropping privileges to UID ${OPENCLAW_USER_ID}"
    exec su -s /bin/bash 1000 -c "$0"
  else
    log "su not available to drop privileges"; exit 1
  fi
fi

 
if [ -z "${OPENCLAW_TOKEN}" ]; then
  token=""
  if [ -x "${SCRIPT_DIR}/secure-init.sh" ]; then
    token_out="$("${SCRIPT_DIR}/secure-init.sh" generate-token 2>/dev/null)"
    if [ -n "${token_out}" ]; then
      token="${token_out}"
    fi
  fi
  if [ -n "${token}" ]; then
    OPENCLAW_TOKEN="${token}"
  else
    OPENCLAW_TOKEN="$(head -c 32 /dev/urandom 2>/dev/null | tr -dc 'A-Za-z0-9' | head -c 32)"
  fi
fi
export OPENCLAW_TOKEN

 
if [ -x "${SCRIPT_DIR}/secure-init.sh" ]; then
  log "Running security hardening (secure-init.sh)"
  if ! "${SCRIPT_DIR}/secure-init.sh"; then
    log "secure-init.sh failed"; exit 1
  fi
else
  log "secure-init.sh not found; skipping hardening"
fi

 
OPENCLAW_CMD="${OPENCLAW_CMD:-/usr/local/bin/openclaw-server}"
OPENCLAW_CONFIG="${OPENCLAW_CONFIG:-/etc/openclaw/config.yaml}"

log "Starting OpenClaw service: ${OPENCLAW_CMD} --config ${OPENCLAW_CONFIG}"
if [ -x "${OPENCLAW_CMD}" ]; then
  "${OPENCLAW_CMD}" --config "${OPENCLAW_CONFIG}" >> /proc/1/fd/1 2>&1 &
  OPENCLAW_PID=$!
else
  log "OpenClaw command not found: ${OPENCLAW_CMD}"; exit 1
fi

 
cleanup() {
  log "SIGTERM received, stopping OpenClaw (PID ${OPENCLAW_PID})..."
  if [ -n "${OPENCLAW_PID:-}" ] && kill -0 "${OPENCLAW_PID}" 2>/dev/null; then
    kill "${OPENCLAW_PID}" 2>/dev/null
    wait "${OPENCLAW_PID}" 2>/dev/null || true
  fi
  log "Shutdown complete"
  exit 0
}
trap cleanup TERM

 
tail -f /dev/null &
TAIL_PID=$!

# Wait for OpenClaw
wait "${OPENCLAW_PID}"

log "OpenClaw process exited, terminating entrypoint"
kill -TERM "${TAIL_PID}" 2>/dev/null || true
wait "${TAIL_PID}" 2>/dev/null || true
exit 0
