#!/usr/bin/env bash

# Shared compatibility and licensing helpers for YanTunnel.
# This file is intentionally dependency-light so it can run before the
# optional packages are installed by the main installer.

export YAN_HOME="${YAN_HOME:-/usr/bin/yanbhoikfost}"
export YAN_ETC="${YAN_ETC:-/etc/yanstunnel}"
export YAN_LICENSE_FILE="${YAN_LICENSE_FILE:-$YAN_ETC/license.conf}"
export YAN_PERMISSION_URL="${YAN_PERMISSION_URL:-https://raw.githubusercontent.com/yansyntax/yanstunnel/main/permission.txt}"

if [[ -t 1 ]]; then
  YAN_RED='\033[0;31m'
  YAN_GREEN='\033[0;32m'
  YAN_YELLOW='\033[0;33m'
  YAN_BLUE='\033[0;34m'
  YAN_CYAN='\033[0;36m'
  YAN_BOLD='\033[1m'
  YAN_NC='\033[0m'
else
  YAN_RED=''; YAN_GREEN=''; YAN_YELLOW=''; YAN_BLUE=''
  YAN_CYAN=''; YAN_BOLD=''; YAN_NC=''
fi

yan_log()  { printf '%b\n' "${YAN_BLUE}[INFO]${YAN_NC} $*"; }
yan_ok()   { printf '%b\n' "${YAN_GREEN}[ OK ]${YAN_NC} $*"; }
yan_warn() { printf '%b\n' "${YAN_YELLOW}[WARN]${YAN_NC} $*" >&2; }
yan_die()  { printf '%b\n' "${YAN_RED}[FAIL]${YAN_NC} $*" >&2; return 1; }

yan_trim() {
  local value="${1-}"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

yan_require_root() {
  [[ "${EUID:-$(id -u)}" -eq 0 ]] || yan_die "Jalankan installer sebagai root (sudo -i)." || return 1
}

yan_detect_os() {
  [[ -r /etc/os-release ]] || yan_die "File /etc/os-release tidak ditemukan." || return 1
  # shellcheck disable=SC1091
  . /etc/os-release
  local os_id="${ID:-}" version="${VERSION_ID:-}" major
  major="${version%%.*}"
  [[ "$major" =~ ^[0-9]+$ ]] || yan_die "Versi OS tidak dapat dibaca." || return 1

  case "$os_id" in
    debian)
      (( major >= 10 )) || yan_die "Debian ${version} belum didukung; gunakan Debian 10 atau lebih baru." || return 1
      ;;
    ubuntu)
      (( major >= 20 )) || yan_die "Ubuntu ${version} belum didukung; gunakan Ubuntu 20.04 atau lebih baru." || return 1
      ;;
    *)
      yan_die "OS ${os_id:-tidak dikenal} ${version:-} tidak didukung. Gunakan Debian 10–13 atau Ubuntu 20.04–25.xx." || return 1
      ;;
  esac

  export YAN_OS_ID="$os_id"
  export YAN_OS_VERSION="$version"
  export YAN_OS_MAJOR="$major"
  yan_ok "OS terdeteksi: ${PRETTY_NAME:-$os_id $version}"
}

yan_detect_arch() {
  case "$(uname -m)" in
    x86_64|amd64) export YAN_ARCH="amd64" ;;
    aarch64|arm64) export YAN_ARCH="arm64-v8a" ;;
    *) yan_die "Arsitektur $(uname -m) belum didukung oleh build Xray ini." || return 1 ;;
  esac
  yan_ok "Arsitektur terdeteksi: $YAN_ARCH"
}

yan_valid_ipv4() {
  local ip="${1-}" octet
  [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
  IFS=. read -r -a octets <<< "$ip"
  for octet in "${octets[@]}"; do
    (( 10#$octet <= 255 )) || return 1
  done
}

yan_public_ip() {
  local endpoint value
  for endpoint in \
    "https://api.ipify.org" \
    "https://ipv4.icanhazip.com" \
    "https://ifconfig.me/ip" \
    "https://ipinfo.io/ip"; do
    if command -v curl >/dev/null 2>&1; then
      value="$(curl -4fsSL --connect-timeout 5 --max-time 10 "$endpoint" 2>/dev/null | tr -d '[:space:]' || true)"
    elif command -v wget >/dev/null 2>&1; then
      value="$(wget -qO- --timeout=10 "$endpoint" 2>/dev/null | tr -d '[:space:]' || true)"
    else
      value=''
    fi
    if yan_valid_ipv4 "$value"; then
      printf '%s' "$value"
      return 0
    fi
  done
  return 1
}

yan_download() {
  local url="$1" destination="$2"
  mkdir -p "$(dirname "$destination")"
  if command -v curl >/dev/null 2>&1; then
    curl -4fL --connect-timeout 10 --max-time 120 --retry 2 --retry-delay 1 "$url" -o "$destination"
  elif command -v wget >/dev/null 2>&1; then
    wget -q --timeout=120 -O "$destination" "$url"
  else
    yan_die "Dibutuhkan curl atau wget untuk mengunduh komponen." || return 1
  fi
}

yan_service_active() {
  local service="$1"
  if command -v systemctl >/dev/null 2>&1; then
    systemctl is-active --quiet "$service"
  else
    service "$service" status >/dev/null 2>&1
  fi
}

yan_service_restart() {
  local service="$1"
  if command -v systemctl >/dev/null 2>&1; then
    systemctl restart "$service"
  else
    service "$service" restart
  fi
}

yan_service_enable() {
  local service="$1"
  if command -v systemctl >/dev/null 2>&1; then
    systemctl enable --now "$service"
  else
    service "$service" start
  fi
}

yan_load_license_from_file() {
  local permission_file="$1" current_ip="$2"
  local username allowed_ip duration extra today expiry epoch_now epoch_exp
  [[ -r "$permission_file" ]] || return 1
  while IFS=':' read -r username allowed_ip duration extra; do
    username="$(yan_trim "$username")"
    allowed_ip="$(yan_trim "$allowed_ip")"
    duration="$(yan_trim "$duration")"
    [[ -z "$username" || "$username" == \#* ]] && continue
    [[ -z "$extra" && "$allowed_ip" == "$current_ip" ]] || continue
    yan_valid_ipv4 "$allowed_ip" || continue
    if [[ "$duration" =~ ^[0-9]+$ ]]; then
      (( duration > 0 )) || continue
      expiry="$(date -d "+${duration} days" +%F 2>/dev/null)" || continue
    elif [[ "$duration" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
      expiry="$duration"
      duration='-'
    else
      continue
    fi
    today="$(date +%F)"
    epoch_now="$(date -d "$today 00:00:00" +%s 2>/dev/null || printf '0')"
    epoch_exp="$(date -d "$expiry 23:59:59" +%s 2>/dev/null || printf '0')"
    (( epoch_exp >= epoch_now && epoch_exp > 0 )) || continue
    printf '%s|%s|%s|%s\n' "$username" "$allowed_ip" "$duration" "$expiry"
    return 0
  done < "$permission_file"
  return 1
}

yan_save_license() {
  local record="$1"
  local username ip duration expiry
  IFS='|' read -r username ip duration expiry <<< "$record"
  install -d -m 0755 "$YAN_ETC"
  cat > "$YAN_LICENSE_FILE" <<EOF
username=$username
ip=$ip
duration=$duration
expires=$expiry
installed_at=$(date +%F)
EOF
  chmod 0644 "$YAN_LICENSE_FILE"
}

yan_check_license() {
  local permission_url="${1:-$YAN_PERMISSION_URL}" permission_file current_ip record
  current_ip="$(yan_public_ip)" || yan_die "IP publik VPS tidak dapat dideteksi." || return 1
  permission_file="$(mktemp)"
  trap 'rm -f "$permission_file"' RETURN
  if [[ -f "$permission_url" ]]; then
    cp "$permission_url" "$permission_file"
  else
    yan_download "$permission_url" "$permission_file" || {
      yan_die "permission.txt tidak dapat diakses. Instalasi dihentikan (fail-closed)."
      return 1
    }
  fi
  record="$(yan_load_license_from_file "$permission_file" "$current_ip")" || {
    yan_die "IP $current_ip belum terdaftar atau izinnya sudah kedaluwarsa."
    printf '%b\n' "${YAN_YELLOW}Format permission.txt: Username : IP_VPS : jumlah_hari${YAN_NC}" >&2
    return 1
  }
  yan_save_license "$record"
  export YAN_PUBLIC_IP="$current_ip"
  export YAN_LICENSE_RECORD="$record"
  IFS='|' read -r _ _ _ expiry <<< "$record"
  yan_ok "Izin aktif untuk IP $current_ip sampai $expiry."
}

yan_license_status() {
  local current_ip record expiry
  [[ -r "$YAN_LICENSE_FILE" ]] || return 1
  # shellcheck disable=SC1090
  . "$YAN_LICENSE_FILE"
  current_ip="$(yan_public_ip 2>/dev/null || true)"
  [[ -n "${ip:-}" && "$current_ip" == "$ip" ]] || return 1
  record="${username:-}|${ip:-}|${duration:--}|${expires:-}"
  expiry="${expires:-}"
  [[ "$expiry" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || return 1
  (( "$(date -d "$expiry 23:59:59" +%s 2>/dev/null || printf 0)" >= "$(date +%s)" )) || return 1
  printf '%s\n' "$record"
}