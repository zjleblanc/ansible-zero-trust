#!/usr/bin/env bash
# vault_podman_status.sh — status dashboard for Vault deployed via
# playbooks/pb_setup_vault_podman.yml (demo.zero_trust.vault / install_podman).
#
# Run on the Vault host. Defaults match role defaults in
# roles/vault/defaults/main/{common,podman}.yml
#
# Usage:
#   ./scripts/vault_podman_status.sh
#   VAULT_PODMAN_USER=vault VAULT_CONTAINER_NAME=vault ./scripts/vault_podman_status.sh
#   ./scripts/vault_podman_status.sh --json   # machine-readable summary
#
set -euo pipefail

# ── defaults (override via env) ──────────────────────────────────────────────
CONTAINER_NAME="${VAULT_CONTAINER_NAME:-vault}"
PODMAN_USER="${VAULT_PODMAN_USER:-}"
STORAGE_PATH="${VAULT_STORAGE_PATH:-/opt/vault/data}"
CONFIG_PATH="${VAULT_CONFIG_PATH:-/opt/vault/config}"
TLS_DIR="${VAULT_TLS_DIR:-/opt/vault/tls}"
PORT="${VAULT_PORT:-8200}"
NETWORK="${VAULT_PODMAN_NETWORK:-}"
JSON_MODE=0

for _arg in "$@"; do
  case "${_arg}" in
    --json|-j) JSON_MODE=1 ;;
    -h|--help)
      sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
  esac
done

# ── colors / symbols (disabled when not a TTY or in --json) ──────────────────
if [[ "${JSON_MODE}" -eq 0 && -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  C_DIM=$'\033[2m'
  C_RED=$'\033[31m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[34m'
  C_CYAN=$'\033[36m'
  C_GRAY=$'\033[90m'
else
  C_RESET= C_BOLD= C_DIM= C_RED= C_GREEN= C_YELLOW= C_BLUE= C_CYAN= C_GRAY=
fi

OK="${C_GREEN}✓${C_RESET}"
BAD="${C_RED}✗${C_RESET}"
WARN="${C_YELLOW}!${C_RESET}"
INFO="${C_CYAN}•${C_RESET}"
NA="${C_GRAY}–${C_RESET}"

# ── helpers ──────────────────────────────────────────────────────────────────
section() {
  [[ "${JSON_MODE}" -eq 1 ]] && return 0
  printf '\n%s%s%s\n' "${C_BOLD}${C_BLUE}" "$1" "${C_RESET}"
  printf '%s\n' "${C_GRAY}$(printf '─%.0s' {1..56})${C_RESET}"
}

kv() {
  # kv "label" "value" [status_symbol]
  local label="$1" value="$2" mark="${3:-}"
  [[ "${JSON_MODE}" -eq 1 ]] && return 0
  if [[ -n "${mark}" ]]; then
    printf '  %s %-22s %s\n' "${mark}" "${label}" "${value}"
  else
    printf '  %s %-22s %s\n' "${INFO}" "${label}" "${value}"
  fi
}

have() { command -v "$1" >/dev/null 2>&1; }

# Run a command as the Podman owner (rootless) or as root (rootful).
run_pm() {
  if [[ "${ROOTLESS}" -eq 1 ]]; then
    if [[ "$(id -un)" == "${PODMAN_USER}" ]]; then
      env XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" "$@"
    else
      # Prefer machinectl / runuser so user systemd + rootless podman see the right bus.
      if have runuser; then
        runuser -u "${PODMAN_USER}" -- env XDG_RUNTIME_DIR="/run/user/$(id -u "${PODMAN_USER}")" "$@"
      else
        sudo -u "${PODMAN_USER}" -- env XDG_RUNTIME_DIR="/run/user/$(id -u "${PODMAN_USER}")" "$@"
      fi
    fi
  else
    if [[ "$(id -u)" -eq 0 ]]; then
      "$@"
    else
      sudo "$@"
    fi
  fi
}

systemctl_pm() {
  if [[ "${ROOTLESS}" -eq 1 ]]; then
    run_pm systemctl --user "$@"
  else
    if [[ "$(id -u)" -eq 0 ]]; then
      systemctl "$@"
    else
      sudo systemctl "$@"
    fi
  fi
}

mark_bool() {
  # mark_bool <0|1> → OK/BAD
  [[ "$1" -eq 1 ]] && printf '%s' "${OK}" || printf '%s' "${BAD}"
}

mark_tri() {
  # mark_tri good_value actual_value [warn_value]
  # good → OK, warn_value → WARN, unknown/empty → NA, else → BAD/WARN
  local good="$1" actual="$2" warn="${3:-}"
  if [[ "${actual}" == "${good}" ]]; then
    printf '%s' "${OK}"
  elif [[ "${actual}" == "unknown" || -z "${actual}" ]]; then
    printf '%s' "${NA}"
  elif [[ -n "${warn}" && "${actual}" == "${warn}" ]]; then
    printf '%s' "${WARN}"
  else
    printf '%s' "${WARN}"
  fi
}

# ── detect rootless vs rootful ───────────────────────────────────────────────
detect_mode() {
  local home quadlet_user quadlet_system
  ROOTLESS=0
  QUADLET_PATH=""

  if [[ -z "${PODMAN_USER}" ]]; then
    # Prefer the invoking user when a user Quadlet exists, else try common owners.
    for candidate in "${SUDO_USER:-}" "$(id -un)" vault; do
      [[ -z "${candidate}" || "${candidate}" == "root" ]] && continue
      home="$(getent passwd "${candidate}" 2>/dev/null | cut -d: -f6 || true)"
      [[ -z "${home}" ]] && continue
      if [[ -f "${home}/.config/containers/systemd/${CONTAINER_NAME}.container" ]]; then
        PODMAN_USER="${candidate}"
        break
      fi
    done
  fi

  if [[ -n "${PODMAN_USER}" ]]; then
    home="$(getent passwd "${PODMAN_USER}" 2>/dev/null | cut -d: -f6 || true)"
    quadlet_user="${home}/.config/containers/systemd/${CONTAINER_NAME}.container"
    if [[ -n "${home}" && -f "${quadlet_user}" ]]; then
      ROOTLESS=1
      QUADLET_PATH="${quadlet_user}"
      return 0
    fi
  fi

  quadlet_system="/etc/containers/systemd/${CONTAINER_NAME}.container"
  if [[ -f "${quadlet_system}" ]]; then
    ROOTLESS=0
    QUADLET_PATH="${quadlet_system}"
    PODMAN_USER="${PODMAN_USER:-root}"
    return 0
  fi

  # Fall back: if a user unit is active, treat as rootless.
  if [[ -n "${PODMAN_USER}" ]] && \
     runuser -u "${PODMAN_USER}" -- env XDG_RUNTIME_DIR="/run/user/$(id -u "${PODMAN_USER}" 2>/dev/null || echo 0)" \
       systemctl --user is-active "${CONTAINER_NAME}.service" >/dev/null 2>&1; then
    ROOTLESS=1
    home="$(getent passwd "${PODMAN_USER}" | cut -d: -f6)"
    QUADLET_PATH="${home}/.config/containers/systemd/${CONTAINER_NAME}.container"
    return 0
  fi

  # Last resort defaults (assume role defaults: rootless under current/non-root user)
  if [[ -z "${PODMAN_USER}" || "${PODMAN_USER}" == "root" ]]; then
    PODMAN_USER="$(id -un)"
    [[ "${PODMAN_USER}" == "root" && -n "${SUDO_USER:-}" ]] && PODMAN_USER="${SUDO_USER}"
  fi
  home="$(getent passwd "${PODMAN_USER}" 2>/dev/null | cut -d: -f6 || echo "/home/${PODMAN_USER}")"
  ROOTLESS=1
  QUADLET_PATH="${home}/.config/containers/systemd/${CONTAINER_NAME}.container"
}

# ── collect status ───────────────────────────────────────────────────────────
detect_mode

UNIT="${CONTAINER_NAME}.service"
SCOPE_LABEL="$([[ "${ROOTLESS}" -eq 1 ]] && echo "user (${PODMAN_USER})" || echo "system")"

# Quadlet
QUADLET_EXISTS=0
[[ -f "${QUADLET_PATH}" ]] && QUADLET_EXISTS=1
QUADLET_IMAGE=""
QUADLET_PUBLISH=""
QUADLET_NETWORK=""
if [[ "${QUADLET_EXISTS}" -eq 1 ]]; then
  QUADLET_IMAGE="$(grep -E '^Image=' "${QUADLET_PATH}" 2>/dev/null | head -1 | cut -d= -f2- || true)"
  QUADLET_PUBLISH="$(grep -E '^PublishPort=' "${QUADLET_PATH}" 2>/dev/null | head -1 | cut -d= -f2- || true)"
  QUADLET_NETWORK="$(grep -E '^Network=' "${QUADLET_PATH}" 2>/dev/null | head -1 | cut -d= -f2- || true)"
  [[ -n "${QUADLET_NETWORK}" && -z "${NETWORK}" ]] && NETWORK="${QUADLET_NETWORK}"
fi

# Linger (rootless)
LINGER=0
LINGER_LABEL="n/a (rootful)"
if [[ "${ROOTLESS}" -eq 1 ]]; then
  if [[ -e "/var/lib/systemd/linger/${PODMAN_USER}" ]]; then
    LINGER=1
    LINGER_LABEL="enabled"
  else
    LINGER_LABEL="disabled"
  fi
fi

# systemd unit
UNIT_LOAD="unknown"
UNIT_ACTIVE="unknown"
UNIT_SUB="unknown"
UNIT_ENABLED="unknown"
if UNIT_SHOW="$(systemctl_pm show "${UNIT}" -p LoadState -p ActiveState -p SubState -p UnitFileState 2>/dev/null)"; then
  UNIT_LOAD="$(printf '%s\n' "${UNIT_SHOW}" | awk -F= '/^LoadState=/{print $2}')"
  UNIT_ACTIVE="$(printf '%s\n' "${UNIT_SHOW}" | awk -F= '/^ActiveState=/{print $2}')"
  UNIT_SUB="$(printf '%s\n' "${UNIT_SHOW}" | awk -F= '/^SubState=/{print $2}')"
  UNIT_ENABLED="$(printf '%s\n' "${UNIT_SHOW}" | awk -F= '/^UnitFileState=/{print $2}')"
fi
UNIT_OK=0
[[ "${UNIT_ACTIVE}" == "active" && "${UNIT_SUB}" == "running" ]] && UNIT_OK=1

# Podman container
CTR_EXISTS=0
CTR_STATUS="missing"
CTR_ID=""
CTR_IMAGE=""
CTR_STARTED=""
CTR_HEALTH=""
CTR_PORTS=""
if run_pm podman container exists "${CONTAINER_NAME}" 2>/dev/null; then
  CTR_EXISTS=1
  CTR_STATUS="$(run_pm podman inspect "${CONTAINER_NAME}" --format '{{.State.Status}}' 2>/dev/null || echo unknown)"
  CTR_ID="$(run_pm podman inspect "${CONTAINER_NAME}" --format '{{.Id}}' 2>/dev/null | cut -c1-12 || true)"
  CTR_IMAGE="$(run_pm podman inspect "${CONTAINER_NAME}" --format '{{.Config.Image}}' 2>/dev/null || true)"
  CTR_STARTED="$(run_pm podman inspect "${CONTAINER_NAME}" --format '{{.State.StartedAt}}' 2>/dev/null || true)"
  CTR_HEALTH="$(run_pm podman inspect "${CONTAINER_NAME}" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}n/a{{end}}' 2>/dev/null || echo n/a)"
  CTR_PORTS="$(run_pm podman port "${CONTAINER_NAME}" 2>/dev/null | tr '\n' ' ' | sed 's/[[:space:]]*$//' || true)"
fi
CTR_OK=0
[[ "${CTR_STATUS}" == "running" ]] && CTR_OK=1

# Image present?
IMAGE_REF="${CTR_IMAGE:-${QUADLET_IMAGE:-}}"
IMAGE_PRESENT=0
IMAGE_ID=""
if [[ -n "${IMAGE_REF}" ]] && run_pm podman image exists "${IMAGE_REF}" 2>/dev/null; then
  IMAGE_PRESENT=1
  IMAGE_ID="$(run_pm podman image inspect "${IMAGE_REF}" --format '{{.Id}}' 2>/dev/null | cut -c1-12 || true)"
fi

# Network
NET_EXISTS=0
if [[ -n "${NETWORK}" ]] && run_pm podman network exists "${NETWORK}" 2>/dev/null; then
  NET_EXISTS=1
fi

# Host paths
path_detail() {
  local p="$1"
  if [[ -d "$p" ]]; then
    local owner mode
    owner="$(stat -c '%U:%G' "$p" 2>/dev/null || stat -f '%Su:%Sg' "$p" 2>/dev/null || echo '?')"
    mode="$(stat -c '%a' "$p" 2>/dev/null || stat -f '%Lp' "$p" 2>/dev/null || echo '?')"
    printf 'present (%s mode %s)' "${owner}" "${mode}"
    return 0
  fi
  printf 'missing'
  return 1
}

STORAGE_OK=0 CONFIG_OK=0 TLS_OK=0 CONFIG_FILE_OK=0
[[ -d "${STORAGE_PATH}" ]] && STORAGE_OK=1
[[ -d "${CONFIG_PATH}" ]] && CONFIG_OK=1
[[ -d "${TLS_DIR}" ]] && TLS_OK=1
[[ -f "${CONFIG_PATH}/vault.hcl" ]] && CONFIG_FILE_OK=1
STORAGE_DETAIL="$(path_detail "${STORAGE_PATH}" || true)"
CONFIG_DETAIL="$(path_detail "${CONFIG_PATH}" || true)"
TLS_DETAIL="$(path_detail "${TLS_DIR}" || true)"

# Listening port
PORT_LISTEN=0
if have ss; then
  ss -lnt "( sport = :${PORT} )" 2>/dev/null | grep -q ":${PORT}" && PORT_LISTEN=1 || true
elif have lsof; then
  lsof -iTCP:"${PORT}" -sTCP:LISTEN >/dev/null 2>&1 && PORT_LISTEN=1 || true
fi

# Vault status (seal / initialized) via podman exec — best effort.
# `vault status` exits non-zero when sealed; capture stdout anyway.
VAULT_INIT="unknown"
VAULT_SEALED="unknown"
VAULT_VERSION="unknown"
VAULT_CLUSTER="unknown"
if [[ "${CTR_OK}" -eq 1 ]]; then
  VS_OUT="$(run_pm podman exec \
    -e VAULT_ADDR="https://127.0.0.1:${PORT}" \
    -e VAULT_SKIP_VERIFY=1 \
    "${CONTAINER_NAME}" vault status -format=json 2>/dev/null || true)"
  if [[ -z "${VS_OUT}" ]]; then
    VS_OUT="$(run_pm podman exec \
      -e VAULT_ADDR="http://127.0.0.1:${PORT}" \
      -e VAULT_SKIP_VERIFY=1 \
      "${CONTAINER_NAME}" vault status -format=json 2>/dev/null || true)"
  fi
  if [[ -n "${VS_OUT}" ]] && have python3; then
    eval "$(printf '%s' "${VS_OUT}" | python3 -c '
import json,sys
try:
    d=json.load(sys.stdin)
except Exception:
    sys.exit(0)
def b(k):
    v=d.get(k)
    if v is True: return "true"
    if v is False: return "false"
    return "unknown"
print(f"VAULT_INIT={b(\"initialized\")}")
print(f"VAULT_SEALED={b(\"sealed\")}")
print(f"VAULT_VERSION={d.get(\"version\") or \"unknown\"}")
print(f"VAULT_CLUSTER={d.get(\"cluster_name\") or \"n/a\"}")
' 2>/dev/null || true)"
  elif [[ -n "${VS_OUT}" ]]; then
    VAULT_INIT="$(printf '%s' "${VS_OUT}" | sed -n 's/.*"initialized"[[:space:]]*:[[:space:]]*\(true\|false\).*/\1/p' | head -1)"
    VAULT_SEALED="$(printf '%s' "${VS_OUT}" | sed -n 's/.*"sealed"[[:space:]]*:[[:space:]]*\(true\|false\).*/\1/p' | head -1)"
    VAULT_VERSION="$(printf '%s' "${VS_OUT}" | sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
    VAULT_INIT="${VAULT_INIT:-unknown}"
    VAULT_SEALED="${VAULT_SEALED:-unknown}"
    VAULT_VERSION="${VAULT_VERSION:-unknown}"
  fi
fi

VAULT_HEALTH_OK=0
[[ "${VAULT_INIT}" == "true" && "${VAULT_SEALED}" == "false" ]] && VAULT_HEALTH_OK=1

# Overall
OVERALL_OK=0
if [[ "${QUADLET_EXISTS}" -eq 1 && "${UNIT_OK}" -eq 1 && "${CTR_OK}" -eq 1 ]]; then
  OVERALL_OK=1
fi

# ── JSON output ──────────────────────────────────────────────────────────────
if [[ "${JSON_MODE}" -eq 1 ]]; then
  python3 - <<PY
import json
print(json.dumps({
  "overall_ok": bool(${OVERALL_OK}),
  "mode": "rootless" if ${ROOTLESS} else "rootful",
  "podman_user": "${PODMAN_USER}",
  "container_name": "${CONTAINER_NAME}",
  "quadlet": {"path": "${QUADLET_PATH}", "exists": bool(${QUADLET_EXISTS}), "image": "${QUADLET_IMAGE}", "network": "${NETWORK}"},
  "linger": {"applicable": bool(${ROOTLESS}), "enabled": bool(${LINGER})},
  "systemd": {"unit": "${UNIT}", "scope": "${SCOPE_LABEL}", "load": "${UNIT_LOAD}", "active": "${UNIT_ACTIVE}", "sub": "${UNIT_SUB}", "enabled": "${UNIT_ENABLED}", "ok": bool(${UNIT_OK})},
  "container": {"exists": bool(${CTR_EXISTS}), "status": "${CTR_STATUS}", "id": "${CTR_ID}", "image": "${CTR_IMAGE}", "started_at": "${CTR_STARTED}", "ports": "${CTR_PORTS}", "ok": bool(${CTR_OK})},
  "image": {"ref": "${IMAGE_REF}", "present": bool(${IMAGE_PRESENT}), "id": "${IMAGE_ID}"},
  "network": {"name": "${NETWORK}", "exists": bool(${NET_EXISTS})},
  "paths": {
    "storage": {"path": "${STORAGE_PATH}", "ok": bool(${STORAGE_OK})},
    "config": {"path": "${CONFIG_PATH}", "ok": bool(${CONFIG_OK}), "vault_hcl": bool(${CONFIG_FILE_OK})},
    "tls": {"path": "${TLS_DIR}", "ok": bool(${TLS_OK})},
  },
  "port": {"port": ${PORT}, "listening": bool(${PORT_LISTEN})},
  "vault": {"initialized": "${VAULT_INIT}", "sealed": "${VAULT_SEALED}", "version": "${VAULT_VERSION}", "cluster": "${VAULT_CLUSTER}", "healthy": bool(${VAULT_HEALTH_OK})},
}, indent=2))
PY
  exit $([[ "${OVERALL_OK}" -eq 1 ]] && echo 0 || echo 1)
fi

# ── human output ─────────────────────────────────────────────────────────────
printf '\n%sVault Podman Status%s\n' "${C_BOLD}" "${C_RESET}"
printf '%s%s%s\n' "${C_DIM}" "$(date '+%Y-%m-%d %H:%M:%S %Z') · host $(hostname -f 2>/dev/null || hostname)" "${C_RESET}"

if [[ "${OVERALL_OK}" -eq 1 ]]; then
  printf '\n  %s Overall: %srunning%s (quadlet + unit + container)\n' "${OK}" "${C_GREEN}" "${C_RESET}"
else
  printf '\n  %s Overall: %sdegraded / not ready%s\n' "${BAD}" "${C_RED}" "${C_RESET}"
fi

section "Deployment"
kv "Mode" "$([[ "${ROOTLESS}" -eq 1 ]] && echo "rootless" || echo "rootful")"
kv "Podman user" "${PODMAN_USER}"
kv "systemd scope" "${SCOPE_LABEL}"
kv "Container name" "${CONTAINER_NAME}"
if [[ "${ROOTLESS}" -eq 1 ]]; then
  kv "Linger" "${LINGER_LABEL}" "$(mark_bool "${LINGER}")"
fi

section "Quadlet"
kv "Unit file" "${QUADLET_PATH}" "$(mark_bool "${QUADLET_EXISTS}")"
if [[ "${QUADLET_EXISTS}" -eq 1 ]]; then
  kv "Image" "${QUADLET_IMAGE:-?}"
  kv "PublishPort" "${QUADLET_PUBLISH:-?}"
  kv "Network" "${QUADLET_NETWORK:-"(default / none)"}"
fi

section "systemd · ${UNIT}"
kv "Load" "${UNIT_LOAD}" "$([[ "${UNIT_LOAD}" == "loaded" ]] && echo "${OK}" || echo "${BAD}")"
kv "Active" "${UNIT_ACTIVE} (${UNIT_SUB})" "$(mark_bool "${UNIT_OK}")"
kv "Enabled" "${UNIT_ENABLED}" "$([[ "${UNIT_ENABLED}" == "enabled" ]] && echo "${OK}" || echo "${WARN}")"

section "Podman container"
kv "Status" "${CTR_STATUS}" "$(mark_bool "${CTR_OK}")"
if [[ "${CTR_EXISTS}" -eq 1 ]]; then
  kv "ID" "${CTR_ID}"
  kv "Image" "${CTR_IMAGE}"
  kv "Started" "${CTR_STARTED}"
  kv "Health" "${CTR_HEALTH}"
  kv "Ports" "${CTR_PORTS:-n/a}"
fi
kv "Image on host" "${IMAGE_REF:-n/a}${IMAGE_ID:+ (${IMAGE_ID})}" "$([[ -z "${IMAGE_REF}" ]] && echo "${NA}" || mark_bool "${IMAGE_PRESENT}")"
if [[ -n "${NETWORK}" ]]; then
  kv "Network" "${NETWORK}" "$(mark_bool "${NET_EXISTS}")"
else
  kv "Network" "(none configured)" "${NA}"
fi

section "Host paths"
kv "Storage" "${STORAGE_PATH} — ${STORAGE_DETAIL}" "$(mark_bool "${STORAGE_OK}")"
kv "Config dir" "${CONFIG_PATH} — ${CONFIG_DETAIL}" "$(mark_bool "${CONFIG_OK}")"
kv "vault.hcl" "${CONFIG_PATH}/vault.hcl" "$(mark_bool "${CONFIG_FILE_OK}")"
kv "TLS dir" "${TLS_DIR} — ${TLS_DETAIL}" "$(mark_bool "${TLS_OK}")"

section "Network / Vault API"
kv "Listen :${PORT}" "$([[ "${PORT_LISTEN}" -eq 1 ]] && echo "yes" || echo "no")" "$(mark_bool "${PORT_LISTEN}")"
kv "Initialized" "${VAULT_INIT}" "$(mark_tri true "${VAULT_INIT}")"
kv "Sealed" "${VAULT_SEALED}" "$(mark_tri false "${VAULT_SEALED}" true)"
kv "Version" "${VAULT_VERSION}"
kv "Cluster" "${VAULT_CLUSTER}"

section "Quick commands"
if [[ "${ROOTLESS}" -eq 1 ]]; then
  _sc="systemctl --user"
  _as="XDG_RUNTIME_DIR=/run/user/\$(id -u ${PODMAN_USER}) "
  if [[ "$(id -un)" != "${PODMAN_USER}" ]]; then
    printf '  %s Run as %s (or prefix with: sudo -u %s %s)\n' "${INFO}" "${PODMAN_USER}" "${PODMAN_USER}" "${_as}"
  fi
  printf '  %s %sstatus %s\n' "${C_DIM}" "${_sc} " "${UNIT}${C_RESET}"
  printf '  %s %srestart %s\n' "${C_DIM}" "${_sc} " "${UNIT}${C_RESET}"
  printf '  %s podman logs -f %s\n' "${C_DIM}" "${CONTAINER_NAME}${C_RESET}"
  printf '  %s podman exec -e VAULT_ADDR=https://127.0.0.1:%s -e VAULT_SKIP_VERIFY=1 %s vault status\n' \
    "${C_DIM}" "${PORT}" "${CONTAINER_NAME}${C_RESET}"
else
  printf '  %s systemctl status %s\n' "${C_DIM}" "${UNIT}${C_RESET}"
  printf '  %s systemctl restart %s\n' "${C_DIM}" "${UNIT}${C_RESET}"
  printf '  %s podman logs -f %s\n' "${C_DIM}" "${CONTAINER_NAME}${C_RESET}"
  printf '  %s podman exec -e VAULT_ADDR=https://127.0.0.1:%s -e VAULT_SKIP_VERIFY=1 %s vault status\n' \
    "${C_DIM}" "${PORT}" "${CONTAINER_NAME}${C_RESET}"
fi

printf '\n'
exit $([[ "${OVERALL_OK}" -eq 1 ]] && echo 0 || echo 1)
