#!/usr/bin/env bash
set -Eeuo pipefail

APP_NAME="YanTunnel"
APP_VERSION="2.0.0"
REPO_RAW_CONFIG="${YANSTUNNEL_RAW_BASE:-https://raw.githubusercontent.com/yansyntax/yanstunnel/main/configs}"
REPO_RAW_BASE="${YANSTUNNEL_RAW_BASE:-https://raw.githubusercontent.com/yansyntax/yanstunnel/main}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || printf '%s' '')"
LOCAL_COMMON="$SCRIPT_DIR/lib/yanstunnel-common.sh"
REMOTE_COMMON="/tmp/yanstunnel-common.sh"
COMMON_SOURCE="$LOCAL_COMMON"

if [[ -r "$LOCAL_COMMON" ]]; then
  # shellcheck disable=SC1090
  source "$LOCAL_COMMON"
else
  command -v curl >/dev/null 2>&1 || {
    apt-get update -y
    apt-get install -y ca-certificates curl
  }
  curl -4fL --connect-timeout 10 --max-time 60 "$REPO_RAW_BASE/lib/yanstunnel-common.sh" -o "$REMOTE_COMMON"
  COMMON_SOURCE="$REMOTE_COMMON"
  # shellcheck disable=SC1090
  source "$REMOTE_COMMON"
fi

yan_require_root

if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
  apt-get update -y
  apt-get install -y ca-certificates curl
fi

yan_detect_os
yan_detect_arch
yan_check_license "${YAN_PERMISSION_URL:-$REPO_RAW_BASE/permission.txt}"

if [[ -e /etc/xray/domain && "${YAN_FORCE_REINSTALL:-0}" != "1" ]]; then
  yan_warn "Instalasi lama terdeteksi."
  read -r -p "Lanjutkan instalasi ulang? Data akun lama bisa terhapus. [y/N] " answer
  [[ "$answer" =~ ^[Yy]$ ]] || { yan_log "Instalasi dibatalkan."; exit 0; }
fi

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export TZ="${YAN_TIMEZONE:-Asia/Jakarta}"
ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime 2>/dev/null || true

yan_log "Memperbarui indeks paket..."
apt-get update -y

packages=(
  ca-certificates curl wget unzip zip sudo jq ruby socat tmux nmap bzip2 gzip
  coreutils screen rsyslog iftop htop net-tools vim nano sed bc build-essential
  gcc g++ automake make autoconf perl m4 dos2unix dropbear libreadline-dev
  zlib1g-dev libssl-dev dirmngr git lsof iptables iptables-persistent openssl
  fail2ban tmux vnstat libsqlite3-dev cron bash-completion xz-utils dnsutils
  chrony nginx certbot python3
)
available=()
for package in "${packages[@]}"; do
  if apt-cache show "$package" >/dev/null 2>&1; then
    available+=("$package")
  else
    yan_warn "Paket $package tidak tersedia di repositori OS ini; dilewati."
  fi
done
apt-get install -y "${available[@]}"

install -d -m 0755 /etc/xray /usr/local/etc/xray /var/lib/scrz-prem \
  /home/vps/public_html "$YAN_HOME" /etc/yanstunnel
rm -f /etc/nginx/sites-enabled/default /etc/nginx/sites-available/default

fetch_project() {
  local relative="$1" destination="$2"
  if [[ -f "$SCRIPT_DIR/$relative" ]]; then
    install -m 0644 "$SCRIPT_DIR/$relative" "$destination"
  else
    yan_download "$REPO_RAW_BASE/$relative" "$destination"
    chmod 0644 "$destination"
  fi
}

fetch_project nginx.conf /etc/nginx/nginx.conf
fetch_project vps.conf /etc/nginx/conf.d/vps.conf
fetch_project issue.net /etc/issue.net
fetch_project password /etc/pam.d/common-password

if [[ -f "$SCRIPT_DIR/cf.sh" ]]; then
  install -m 0755 "$SCRIPT_DIR/cf.sh" /usr/local/bin/yanstunnel-cf
else
  yan_download "$REPO_RAW_CONFIG/cf.sh" /usr/local/bin/yanstunnel-cf
  chmod 0755 /usr/local/bin/yanstunnel-cf
fi

download_or_copy() {
  local relative="$1" destination="$2"
  if [[ -f "$SCRIPT_DIR/$relative" ]]; then
    install -m 0755 "$SCRIPT_DIR/$relative" "$destination"
  else
    yan_download "$REPO_RAW_CONFIG/$relative" "$destination"
    chmod 0755 "$destination"
  fi
}

# Install protocol and utility commands with stable names (no .sh suffix).
declare -A commands=(  
  [bbr]=bbr.sh [dns]=dns.sh [ins-xray]=ins-xray.sh [ssh-vpn]=ssh-vpn.sh
  [set-br]=set-br.sh [ws-stunnel]=ws-stunnel
)
for command_name in "${!commands[@]}"; do
  download_or_copy "${commands[$command_name]}" "$YAN_HOME/$command_name"
done

# Menus are distributed as one archive and extracted into the private menu
# directory requested by the project owner. The public names are symlinks only.
menu_archive="$SCRIPT_DIR/menu.zip"
if [[ ! -f "$menu_archive" ]]; then
  menu_archive="$(mktemp)"
  yan_download "$REPO_RAW_BASE/menu.zip" "$menu_archive"
fi
rm -rf "$YAN_HOME"/*
unzip -q -o "$menu_archive" -d "$YAN_HOME"
find "$YAN_HOME" -type f -exec chmod 0755 {} +
for menu_name in main-menu menu-vmess menu-vless menu-trojan menu-trgo menu-ss menu-socks menu-ssh menu-bckp; do
  ln -sfn "$YAN_HOME/$menu_name" "/usr/local/bin/$menu_name"
done
ln -sfn "$YAN_HOME/main-menu" /usr/local/bin/menu
ln -sfn "$YAN_HOME/main-menu" /usr/bin/menu

cat > /etc/profile.d/yanstunnel.sh <<'EOF'
export PATH="/usr/local/bin:/usr/bin:/usr/bin/yanbhoikfost:$PATH"
EOF

if [[ -x "$YAN_HOME/yanstunnel-common" ]]; then
  install -m 0644 "$YAN_HOME/yanstunnel-common" "$YAN_HOME/common"
fi
install -m 0644 "$COMMON_SOURCE" "$YAN_HOME/common"

if [[ -x /usr/local/bin/yanstunnel-cf ]]; then
  (cd /root && /usr/local/bin/yanstunnel-cf) || yan_warn "Konfigurasi Cloudflare dilewati; domain bisa diatur dari menu."
fi

if [[ -x "$YAN_HOME/ins-xray" ]]; then
  "$YAN_HOME/ins-xray"
fi

if command -v systemctl >/dev/null 2>&1; then
  systemctl daemon-reload
  systemctl enable --now cron chrony nginx 2>/dev/null || true
fi

cat> /root/.profile << END
# ~/.profile: executed by Bourne-compatible login shells.

if [ "$BASH" ]; then
  if [ -f ~/.bashrc ]; then
    . ~/.bashrc
  fi
fi

mesg n || true
clear
menu
END
chmod 644 /root/.profile

cat > /etc/cron.d/yanstunnel <<'EOF'
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
2 0 * * * root /usr/local/bin/xp
2 1 * * * root /usr/local/bin/clearlog
EOF
chmod 0644 /etc/cron.d/yanstunnel

yan_ok "$APP_NAME v$APP_VERSION berhasil dipasang."
yan_log "Menu utama: menu"
yan_log "Menu tersimpan di: $YAN_HOME"