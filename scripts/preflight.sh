#!/usr/bin/env bash
set -Eeuo pipefail

failures=0
warnings=0

pass() {
  printf 'PASS  %s\n' "$1"
}

fail() {
  printf 'STOP  %s\n' "$1" >&2
  failures=$((failures + 1))
}

warn() {
  printf 'WARN  %s\n' "$1" >&2
  warnings=$((warnings + 1))
}

info() {
  printf 'INFO  %s\n' "$1"
}

if [[ "$(uname -s 2>/dev/null || true)" == Linux ]]; then
  pass 'Linux kernel detected'
else
  fail 'This workflow is limited to Linux'
fi

os_id=''
os_version=''
if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  os_id="${ID:-}"
  os_version="${VERSION_ID:-unknown}"
fi

case "$os_id" in
  ubuntu|debian)
    pass "Supported distribution family: ${os_id} ${os_version}"
    ;;
  *)
    fail 'This public quickstart is validated only for Ubuntu/Debian'
    ;;
esac

arch="$(uname -m 2>/dev/null || true)"
case "$arch" in
  x86_64|amd64|aarch64|arm64)
    pass "Validated architecture family: ${arch}"
    ;;
  *)
    fail "Architecture is outside this guide's validated set: ${arch:-unknown}"
    ;;
esac

if (( EUID == 0 )); then
  pass 'Current shell is root'
elif command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
  pass 'Passwordless sudo is available'
else
  fail 'Root or passwordless sudo is required by this workflow'
fi

pid1=''
if [[ -r /proc/1/comm ]]; then
  IFS= read -r pid1 < /proc/1/comm || true
fi

if [[ "$pid1" == systemd ]] && command -v systemctl >/dev/null 2>&1; then
  if systemctl --version >/dev/null 2>&1; then
    pass 'PID 1 is systemd and systemctl is usable'
  else
    fail 'systemctl exists but is not usable'
  fi
else
  fail 'PID 1 must be systemd for this workflow'
fi

if [[ -c /dev/net/tun ]]; then
  pass '/dev/net/tun is present as a character device'
else
  fail '/dev/net/tun is unavailable; do not fall back to public SSH'
fi

required_commands=(curl getent id ss)
for command_name in "${required_commands[@]}"; do
  if command -v "$command_name" >/dev/null 2>&1; then
    pass "Required command is available: ${command_name}"
  else
    fail "Required command is missing: ${command_name}"
  fi
done

if command -v curl >/dev/null 2>&1; then
  if curl --fail --silent --show-error --location \
    --proto '=https' --proto-redir '=https' --tlsv1.2 \
    --max-time 20 --output /dev/null \
    https://tailscale.com/install.sh; then
    pass 'Outbound HTTPS can fetch the official Tailscale installer'
  else
    fail 'Cannot fetch the official Tailscale installer over HTTPS'
  fi
fi

if command -v tailscale >/dev/null 2>&1; then
  info 'Tailscale client is already installed'
else
  info 'Tailscale client is not installed yet'
fi

if command -v sshd >/dev/null 2>&1; then
  warn 'Existing OpenSSH server detected; this guide will not modify it'
else
  info 'No sshd command detected'
fi

if command -v ss >/dev/null 2>&1 && \
  ss -lntH 2>/dev/null | awk '{print $4}' | grep -Eq '(^|[.:])22$'; then
  warn 'An existing TCP 22 listener was detected; external audit is mandatory'
else
  info 'No TCP 22 listener detected by the current local check'
fi

printf 'PRECHECK_FAILURES=%d\n' "$failures"
printf 'PRECHECK_WARNINGS=%d\n' "$warnings"

if (( failures > 0 )); then
  printf 'PRECHECK_RESULT=STOP\n' >&2
  exit 1
fi

printf 'PRECHECK_RESULT=PASS\n'
