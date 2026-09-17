#!/usr/bin/env bash

# ============================================================
# Xray VLESS + REALITY + XTLS Vision
# Xray 26.x
# Designed for v2rayN / v2rayNG
# ============================================================

set -u

XRAY_BIN="/usr/local/bin/xray"
XRAY_DIR="/usr/local/etc/xray"
XRAY_CONFIG="${XRAY_DIR}/config.json"
XRAY_SERVICE="xray"

BACKUP_DIR="${XRAY_DIR}/backup"

SERVER_IP=""
UUID=""
PRIVATE_KEY=""
PUBLIC_KEY=""
SHORT_ID=""

DEST=""
SERVER_NAME=""

CONFIG_BACKUP=""

# ------------------------------------------------------------
# Colors
# ------------------------------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ------------------------------------------------------------
# Basic functions
# ------------------------------------------------------------

msg() {
    echo -e "${GREEN}[+]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[!]${NC} $*"
}

error() {
    echo -e "${RED}[-]${NC} $*"
}

info() {
    echo -e "${CYAN}[*]${NC} $*"
}

pause() {
    echo
    read -r -p "按 Enter 返回菜单..." _
}

require_root() {
    if [ "$(id -u)" != "0" ]; then
        error "请使用 root 用户运行此脚本。"
        exit 1
    fi
}

# ------------------------------------------------------------
# Detect OS
# ------------------------------------------------------------

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS="${ID:-unknown}"
        VERSION="${VERSION_ID:-unknown}"
    else
        OS="unknown"
        VERSION="unknown"
    fi

    info "系统: ${OS} ${VERSION}"
}

# ------------------------------------------------------------
# Dependencies
# ------------------------------------------------------------

install_dependencies() {

    command -v curl >/dev/null 2>&1 && return 0

    info "未检测到 curl，正在安装..."

    if command -v apt-get >/dev/null 2>&1; then

        apt-get update -y
        apt-get install -y curl ca-certificates unzip

    elif command -v dnf >/dev/null 2>&1; then

        dnf install -y curl ca-certificates unzip

    elif command -v yum >/dev/null 2>&1; then

        yum install -y curl ca-certificates unzip

    elif command -v apk >/dev/null 2>&1; then

        apk add curl ca-certificates unzip

    else
        error "无法自动安装依赖，请手动安装 curl、ca-certificates、unzip。"
        exit 1
    fi
}

# ------------------------------------------------------------
# Get server IPv4
# ------------------------------------------------------------

get_server_ip() {

    SERVER_IP=""

    # First try route based detection
    if command -v ip >/dev/null 2>&1; then

        SERVER_IP=$(ip route get 1.1.1.1 2>/dev/null \
            | awk '/src/ {for(i=1;i<=NF;i++) if($i=="src") print $(i+1); exit}')

    fi

    # Public IP fallback
    if [ -z "$SERVER_IP" ]; then
        SERVER_IP=$(curl -4 -fsS --max-time 5 https://api.ipify.org 2>/dev/null || true)
    fi

    if [ -z "$SERVER_IP" ]; then
        SERVER_IP=$(curl -4 -fsS --max-time 5 https://ifconfig.me 2>/dev/null || true)
    fi

    if [ -z "$SERVER_IP" ]; then
        error "无法自动获取服务器 IPv4。"
        read -r -p "请输入服务器 IPv4: " SERVER_IP
    fi

    msg "服务器 IPv4: ${SERVER_IP}"
}

# ------------------------------------------------------------
# Check port 443
# ------------------------------------------------------------

check_port_443() {

    info "检查 TCP 443 端口..."

    if ! command -v ss >/dev/null 2>&1; then
        warn "系统没有 ss，跳过端口检查。"
        return 0
    fi

    PORT_INFO=$(ss -lntp 2>/dev/null | awk '$4 ~ /:443$/')

    if [ -z "$PORT_INFO" ]; then
        msg "443 端口目前没有监听。"
        return 0
    fi

    echo
    echo "$PORT_INFO"
    echo

    # If Xray itself occupies 443, we can stop it during installation.
    if echo "$PORT_INFO" | grep -q "xray"; then
        warn "443 当前由 Xray 占用。"
        return 0
    fi

    error "443 已被其他程序占用。"
    error "REALITY 需要监听 443，请先处理上面的进程。"

    return 1
}

# ------------------------------------------------------------
# Stop Xray
# ------------------------------------------------------------

stop_xray() {

    if systemctl list-unit-files 2>/dev/null | grep -q '^xray.service'; then
        systemctl stop xray >/dev/null 2>&1 || true
    fi

    pkill -x xray >/dev/null 2>&1 || true

    sleep 1
}

# ------------------------------------------------------------
# Install / Update Xray
# ------------------------------------------------------------

install_xray_binary() {

    info "安装 / 更新 Xray..."

    install_dependencies

    # Official Xray installer
    bash <(curl -Ls https://github.com/XTLS/Xray-install/raw/main/install-release.sh)

    if [ ! -x "$XRAY_BIN" ]; then
        error "Xray 安装失败：${XRAY_BIN} 不存在。"
        return 1
    fi

    msg "Xray 安装成功："

    "$XRAY_BIN" version | head -n 1

    return 0
}

# ------------------------------------------------------------
# Backup current config
# ------------------------------------------------------------

backup_config() {

    mkdir -p "$BACKUP_DIR"

    if [ -f "$XRAY_CONFIG" ]; then

        CONFIG_BACKUP="${BACKUP_DIR}/config.$(date +%Y%m%d_%H%M%S).json"

        cp -a "$XRAY_CONFIG" "$CONFIG_BACKUP"

        msg "旧配置已备份："
        echo "    $CONFIG_BACKUP"
    fi
}

# ------------------------------------------------------------
# Generate UUID
# ------------------------------------------------------------

generate_uuid() {

    UUID=""

    UUID=$("$XRAY_BIN" uuid 2>/dev/null || true)

    if [ -z "$UUID" ]; then
        error "UUID 生成失败。"
        return 1
    fi

    msg "UUID: ${UUID}"
}

# ------------------------------------------------------------
# Generate REALITY X25519 keys
# ------------------------------------------------------------

generate_reality_keys() {

    info "生成 REALITY X25519 密钥..."

    local result=""

    result=$("$XRAY_BIN" x25519 2>/dev/null || true)

    if [ -z "$result" ]; then
        error "xray x25519 执行失败。"
        return 1
    fi

    echo
    echo "$result"
    echo

    # Xray 26.x:
    #
    # PrivateKey: xxxxx
    # Password (PublicKey): xxxxx
    #
    PRIVATE_KEY=$(printf '%s\n' "$result" \
        | sed -n 's/^PrivateKey:[[:space:]]*//p' \
        | head -n 1)

    PUBLIC_KEY=$(printf '%s\n' "$result" \
        | sed -n 's/^Password (PublicKey):[[:space:]]*//p' \
        | head -n 1)

    # Compatibility with older Xray output
    if [ -z "$PUBLIC_KEY" ]; then

        PUBLIC_KEY=$(printf '%s\n' "$result" \
            | sed -n 's/^PublicKey:[[:space:]]*//p' \
            | head -n 1)
    fi

    if [ -z "$PUBLIC_KEY" ]; then

        PUBLIC_KEY=$(printf '%s\n' "$result" \
            | sed -n 's/^Password:[[:space:]]*//p' \
            | head -n 1)
    fi

    if [ -z "$PRIVATE_KEY" ] || [ -z "$PUBLIC_KEY" ]; then

        error "无法解析 X25519 密钥。"
        error "Xray 输出："
        echo "$result"

        return 1
    fi

    msg "REALITY PrivateKey: ${PRIVATE_KEY}"
    msg "REALITY PublicKey : ${PUBLIC_KEY}"
}

# ------------------------------------------------------------
# Generate Short ID
# ------------------------------------------------------------

generate_short_id() {

    if command -v openssl >/dev/null 2>&1; then

        SHORT_ID=$(openssl rand -hex 8)

    else

        SHORT_ID=$(od -An -N8 -tx1 /dev/urandom \
            | tr -d ' \n')
    fi

    if [ -z "$SHORT_ID" ]; then
        error "shortId 生成失败。"
        return 1
    fi

    msg "Short ID: ${SHORT_ID}"
}

# ------------------------------------------------------------
# Select REALITY target
# ------------------------------------------------------------

select_reality_target() {

    echo
    echo "============================================================"
    echo " REALITY 伪装站点"
    echo "============================================================"
    echo
    echo "默认使用：speed.cloudflare.com:443"
    echo
    echo "要求目标站点支持 TLS 1.3 / HTTP2。"
    echo
    echo "1. speed.cloudflare.com:443"
    echo "2. www.cloudflare.com:443"
    echo "3. 自定义"
    echo

    read -r -p "请选择 [1-3，默认 1]: " choice

    case "$choice" in

        2)
            DEST="www.cloudflare.com:443"
            SERVER_NAME="www.cloudflare.com"
            ;;

        3)
            read -r -p "请输入 REALITY Target，例如 example.com:443: " DEST

            if [ -z "$DEST" ]; then
                error "Target 不能为空。"
                return 1
            fi

            SERVER_NAME="${DEST%%:*}"

            if [ -z "$SERVER_NAME" ]; then
                error "无法解析 serverName。"
                return 1
            fi
            ;;

        *)
            DEST="speed.cloudflare.com:443"
            SERVER_NAME="speed.cloudflare.com"
            ;;
    esac

    msg "REALITY Target : ${DEST}"
    msg "REALITY SNI    : ${SERVER_NAME}"
}

# ------------------------------------------------------------
# Fix Xray permissions
# ------------------------------------------------------------

fix_xray_permissions() {

    info "修复 Xray 配置目录权限..."

    mkdir -p "$XRAY_DIR"

    # Directory must be searchable by the Xray service user.
    chown root:root "$XRAY_DIR"
    chmod 755 "$XRAY_DIR"

    if [ -f "$XRAY_CONFIG" ]; then

        chown root:root "$XRAY_CONFIG"
        chmod 644 "$XRAY_CONFIG"

    fi

    # Ensure parent directories are searchable.
    chmod 755 /usr/local 2>/dev/null || true

    echo
    echo "配置目录："
    ls -ld "$XRAY_DIR"

    echo
    echo "配置文件："
    ls -l "$XRAY_CONFIG"
    echo
}

# ------------------------------------------------------------
# Write config
# ------------------------------------------------------------

write_config() {

    info "生成 Xray 配置..."

    mkdir -p "$XRAY_DIR"

    local tmp_config="${XRAY_CONFIG}.tmp"

    cat > "$tmp_config" <<EOF
{
  "log": {
    "loglevel": "warning"
  },

  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": 443,
      "protocol": "vless",

      "settings": {
        "clients": [
          {
            "id": "${UUID}",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },

      "streamSettings": {
        "network": "raw",
        "security": "reality",

        "realitySettings": {
          "show": false,
          "target": "${DEST}",
          "xver": 0,

          "serverNames": [
            "${SERVER_NAME}"
          ],

          "privateKey": "${PRIVATE_KEY}",

          "shortIds": [
            "${SHORT_ID}"
          ]
        }
      },

      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls",
          "quic"
        ],
        "routeOnly": true
      }
    }
  ],

  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    }
  ]
}
EOF

    if [ ! -s "$tmp_config" ]; then
        error "配置文件生成失败。"
        rm -f "$tmp_config"
        return 1
    fi

    # Validate JSON syntax
    if command -v python3 >/dev/null 2>&1; then

        if ! python3 -m json.tool "$tmp_config" >/dev/null 2>&1; then
            error "JSON 格式错误。"
            rm -f "$tmp_config"
            return 1
        fi

    fi

    mv -f "$tmp_config" "$XRAY_CONFIG"

    fix_xray_permissions

    msg "配置文件生成完成。"
}

# ------------------------------------------------------------
# Test config
# ------------------------------------------------------------

test_config() {

    info "测试 Xray 配置..."

    fix_xray_permissions

    echo
    echo "------------------------------------------------------------"

    if "$XRAY_BIN" run -test -config "$XRAY_CONFIG"; then

        echo "------------------------------------------------------------"
        msg "Xray 配置测试通过。"
        echo

        return 0

    else

        echo "------------------------------------------------------------"
        error "Xray 配置测试失败。"
        echo
        error "请检查上面的错误信息。"
        echo

        return 1
    fi
}

# ------------------------------------------------------------
# Start service
# ------------------------------------------------------------

start_xray() {

    info "重新加载 systemd..."

    systemctl daemon-reload

    info "启动 Xray..."

    systemctl enable xray >/dev/null 2>&1 || true

    systemctl restart xray

    sleep 2

    if systemctl is-active --quiet xray; then

        msg "Xray 启动成功。"

        return 0
    fi

    error "Xray 启动失败。"

    echo
    systemctl status xray --no-pager -l || true

    echo
    error "最近日志："

    journalctl -u xray -n 50 --no-pager || true

    return 1
}

# ------------------------------------------------------------
# Check port
# ------------------------------------------------------------

check_xray_port() {

    echo
    info "检查 Xray 443 监听..."

    if command -v ss >/dev/null 2>&1; then

        ss -lntp 2>/dev/null | grep -E ':443[[:space:]]' || true

    fi
}

# ------------------------------------------------------------
# Generate v2rayN URL
# ------------------------------------------------------------

generate_vless_url() {

    local remark="VLESS-REALITY-Vision"

    local encoded_remark=""

    if command -v python3 >/dev/null 2>&1; then

        encoded_remark=$(python3 - "$remark" <<'PY'
import sys
from urllib.parse import quote
print(quote(sys.argv[1], safe=''))
PY
)

    else

        encoded_remark="$remark"
    fi

    echo
    echo "============================================================"
    echo " v2rayN / v2rayNG VLESS + REALITY"
    echo "============================================================"
    echo

    echo "服务器地址:"
    echo "$SERVER_IP"

    echo
    echo "端口:"
    echo "443"

    echo
    echo "UUID:"
    echo "$UUID"

    echo
    echo "Flow:"
    echo "xtls-rprx-vision"

    echo
    echo "SNI:"
    echo "$SERVER_NAME"

    echo
    echo "Public Key:"
    echo "$PUBLIC_KEY"

    echo
    echo "Short ID:"
    echo "$SHORT_ID"

    echo
    echo "Fingerprint:"
    echo "chrome"

    echo
    echo "------------------------------------------------------------"
    echo "VLESS URL:"
    echo

    echo "vless://${UUID}@${SERVER_IP}:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${SERVER_NAME}&fp=chrome&pbk=${PUBLIC_KEY}&sid=${SHORT_ID}&type=tcp&headerType=none#${encoded_remark}"

    echo
    echo "============================================================"
}

# ------------------------------------------------------------
# Save client info
# ------------------------------------------------------------

save_client_info() {

    local info_file="${XRAY_DIR}/client-info.txt"

    cat > "$info_file" <<EOF
Xray VLESS + REALITY + XTLS Vision
==================================

Server:
${SERVER_IP}

Port:
443

UUID:
${UUID}

Flow:
xtls-rprx-vision

Reality Target:
${DEST}

SNI:
${SERVER_NAME}

PublicKey:
${PUBLIC_KEY}

PrivateKey:
${PRIVATE_KEY}

ShortID:
${SHORT_ID}

Fingerprint:
chrome

VLESS URL:
vless://${UUID}@${SERVER_IP}:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${SERVER_NAME}&fp=chrome&pbk=${PUBLIC_KEY}&sid=${SHORT_ID}&type=tcp&headerType=none#VLESS-REALITY-Vision
EOF

    chown root:root "$info_file"
    chmod 600 "$info_file"

    msg "客户端参数已保存："
    echo "    $info_file"
}

# ------------------------------------------------------------
# Install complete
# ------------------------------------------------------------

install_complete() {

    echo
    echo "============================================================"
    echo " 开始安装 VLESS + REALITY + XTLS Vision"
    echo "============================================================"
    echo

    detect_os

    get_server_ip

    # Stop existing Xray before checking 443.
    stop_xray

    if ! check_port_443; then
        error "请先处理 443 端口占用。"
        return 1
    fi

    if ! install_xray_binary; then
        return 1
    fi

    backup_config

    if ! generate_uuid; then
        return 1
    fi

    if ! generate_reality_keys; then
        return 1
    fi

    if ! generate_short_id; then
        return 1
    fi

    if ! select_reality_target; then
        return 1
    fi

    if ! write_config; then
        return 1
    fi

    if ! test_config; then

        error "配置测试失败，不启动 Xray。"

        if [ -n "$CONFIG_BACKUP" ] && [ -f "$CONFIG_BACKUP" ]; then
            warn "旧配置仍然保留："
            echo "    $CONFIG_BACKUP"
        fi

        return 1
    fi

    if ! start_xray; then
        return 1
    fi

    check_xray_port

    save_client_info

    generate_vless_url

    echo
    echo "============================================================"
    msg "安装完成！"
    echo "============================================================"
    echo
}

# ------------------------------------------------------------
# Show status
# ------------------------------------------------------------

show_status() {

    echo
    echo "============================================================"
    echo " Xray 状态"
    echo "============================================================"
    echo

    systemctl status xray --no-pager -l || true

    echo
    echo "监听端口："

    ss -lntp 2>/dev/null | grep -E ':443[[:space:]]' || true

    pause
}

# ------------------------------------------------------------
# Show config
# ------------------------------------------------------------

show_config() {

    echo
    echo "============================================================"
    echo " Xray 配置"
    echo "============================================================"
    echo

    if [ ! -f "$XRAY_CONFIG" ]; then
        error "配置文件不存在：$XRAY_CONFIG"
    else
        cat "$XRAY_CONFIG"
    fi

    pause
}

# ------------------------------------------------------------
# Show client info
# ------------------------------------------------------------

show_client() {

    echo
    echo "============================================================"
    echo " 客户端参数"
    echo "============================================================"

    if [ -f "${XRAY_DIR}/client-info.txt" ]; then

        cat "${XRAY_DIR}/client-info.txt"

    else

        warn "client-info.txt 不存在。"

        if [ -n "$UUID" ] && [ -n "$PUBLIC_KEY" ]; then
            generate_vless_url
        fi
    fi

    pause
}

# ------------------------------------------------------------
# Show logs
# ------------------------------------------------------------

show_logs() {

    echo
    echo "============================================================"
    echo " Xray 最近日志"
    echo "============================================================"
    echo

    journalctl -u xray -n 100 --no-pager

    pause
}

# ------------------------------------------------------------
# Restart
# ------------------------------------------------------------

restart_xray() {

    fix_xray_permissions

    echo

    if ! test_config; then
        error "配置测试失败，不执行重启。"
        pause
        return
    fi

    systemctl restart xray

    sleep 2

    if systemctl is-active --quiet xray; then
        msg "Xray 重启成功。"
    else
        error "Xray 重启失败。"
        systemctl status xray --no-pager -l || true
    fi

    pause
}

# ------------------------------------------------------------
# Uninstall
# ------------------------------------------------------------

uninstall_xray() {

    echo
    echo "============================================================"
    echo " 卸载 Xray"
    echo "============================================================"
    echo

    warn "这将停止并卸载 Xray。"
    warn "配置文件默认不会立即删除。"
    echo

    read -r -p "确定卸载？请输入 YES: " confirm

    if [ "$confirm" != "YES" ]; then
        echo "取消。"
        pause
        return
    fi

    systemctl stop xray >/dev/null 2>&1 || true
    systemctl disable xray >/dev/null 2>&1 || true

    if [ -x "$XRAY_BIN" ]; then

        bash <(curl -Ls https://github.com/XTLS/Xray-install/raw/main/install-release.sh) remove

    fi

    systemctl daemon-reload

    msg "Xray 已卸载。"

    echo
    echo "配置目录仍可能存在："
    echo "$XRAY_DIR"

    pause
}

# ------------------------------------------------------------
# Repair permissions
# ------------------------------------------------------------

repair_permissions() {

    echo
    echo "============================================================"
    echo " 修复 Xray 权限"
    echo "============================================================"
    echo

    fix_xray_permissions

    msg "权限修复完成。"

    echo
    info "测试配置："

    "$XRAY_BIN" run -test -config "$XRAY_CONFIG" || true

    pause
}

# ------------------------------------------------------------
# Menu
# ------------------------------------------------------------

show_menu() {

    clear 2>/dev/null || true

    echo
    echo "============================================================"
    echo "        Xray VLESS + REALITY + XTLS Vision"
    echo "============================================================"
    echo
    echo " Xray: $XRAY_BIN"
    echo " Config: $XRAY_CONFIG"
    echo

    if [ -x "$XRAY_BIN" ]; then

        "$XRAY_BIN" version 2>/dev/null | head -n 1

    else

        echo "Xray: 未安装"

    fi

    echo
    echo "------------------------------------------------------------"
    echo
    echo " 1. 安装 / 重装 VLESS + REALITY"
    echo " 2. 查看 Xray 状态"
    echo " 3. 查看 Xray 配置"
    echo " 4. 查看客户端参数"
    echo " 5. 重启 Xray"
    echo " 6. 查看 Xray 日志"
    echo " 7. 修复配置权限"
    echo " 8. 卸载 Xray"
    echo " 0. 退出"
    echo
    echo "------------------------------------------------------------"
    echo
}

# ------------------------------------------------------------
# Main
# ------------------------------------------------------------

main() {

    require_root

    while true; do

        show_menu

        read -r -p "请选择 [0-8]: " choice

        case "$choice" in

            1)
                install_complete
                pause
                ;;

            2)
                show_status
                ;;

            3)
                show_config
                ;;

            4)
                show_client
                ;;

            5)
                restart_xray
                ;;

            6)
                show_logs
                ;;

            7)
                repair_permissions
                ;;

            8)
                uninstall_xray
                ;;

            0)
                echo
                echo "退出。"
                exit 0
                ;;

            *)
                warn "无效选择，请输入 0-8。"
                sleep 1
                ;;

        esac

    done
}

main "$@"
