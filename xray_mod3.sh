#!/usr/bin/env bash

# ============================================================
# Xray VLESS + REALITY + XTLS Vision 一键安装脚本
#
# Xray:
#   VLESS + TCP + REALITY + xtls-rprx-vision
#
# Client:
#   v2rayN / v2rayNG / sing-box 等支持 Xray Vision 的客户端
#
# Config:
#   /usr/local/etc/xray/config.json
#
# Client information:
#   /usr/local/etc/xray/client-info.txt
#
# Backup:
#   /usr/local/etc/xray/backup/
#
# ============================================================

set -e

XRAY_BIN="/usr/local/bin/xray"
XRAY_DIR="/usr/local/etc/xray"
XRAY_CONFIG="${XRAY_DIR}/config.json"
XRAY_INFO="${XRAY_DIR}/client-info.txt"
BACKUP_DIR="${XRAY_DIR}/backup"

INSTALL_SCRIPT_URL="https://github.com/XTLS/Xray-install/raw/main/install-release.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'


# ============================================================
# 基础函数
# ============================================================

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

die() {
    error "$1"
    exit 1
}

pause_enter() {
    echo
    read -rp "按 Enter 继续..."
}


# ============================================================
# Root
# ============================================================

check_root() {

    if [ "$(id -u)" != "0" ]; then
        die "请使用 root 用户运行此脚本"
    fi
}


# ============================================================
# OS
# ============================================================

check_os() {

    if [ ! -f /etc/os-release ]; then
        die "无法识别操作系统"
    fi

    . /etc/os-release

    info "操作系统：${PRETTY_NAME}"

    case "${ID}" in
        debian|ubuntu|centos|rocky|almalinux|fedora)
            ;;
        *)
            warn "当前系统 ${ID} 未经过充分测试"

            read -rp "是否继续？[y/N]: " answer

            if [[ ! "$answer" =~ ^[Yy]$ ]]; then
                exit 0
            fi
            ;;
    esac
}


# ============================================================
# 依赖
# ============================================================

check_commands() {

    local missing=""

    for cmd in curl openssl sed grep awk; do

        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing="${missing} ${cmd}"
        fi

    done

    if [ -n "$missing" ]; then

        warn "缺少命令：${missing}"

        if command -v apt-get >/dev/null 2>&1; then

            export DEBIAN_FRONTEND=noninteractive

            apt-get update

            apt-get install -y \
                curl \
                openssl \
                ca-certificates \
                sed \
                grep \
                gawk

        elif command -v dnf >/dev/null 2>&1; then

            dnf install -y \
                curl \
                openssl \
                ca-certificates \
                sed \
                grep \
                gawk

        elif command -v yum >/dev/null 2>&1; then

            yum install -y \
                curl \
                openssl \
                ca-certificates \
                sed \
                grep \
                gawk

        else
            die "无法自动安装依赖"
        fi
    fi
}


# ============================================================
# 备份旧配置
# ============================================================

backup_config() {

    if [ -f "$XRAY_CONFIG" ]; then

        mkdir -p "$BACKUP_DIR"

        local backup_file

        backup_file="${BACKUP_DIR}/config-$(date +%Y%m%d-%H%M%S).json"

        cp "$XRAY_CONFIG" "$backup_file"

        chmod 600 "$backup_file"

        success "旧配置已备份：${backup_file}"
    fi
}


# ============================================================
# 安装 / 更新 Xray
# ============================================================

install_xray() {

    info "检查 Xray..."

    if [ -x "$XRAY_BIN" ]; then

        echo

        "$XRAY_BIN" version 2>/dev/null | head -n 2 || true

        echo

        read -rp "检测到已有 Xray，是否更新/重新安装？[Y/n]: " answer

        if [[ "$answer" =~ ^[Nn]$ ]]; then
            return
        fi
    else

        info "未检测到 Xray，开始安装..."
    fi

    bash -c "$(curl -fsSL "$INSTALL_SCRIPT_URL")" @ install

    if [ ! -x "$XRAY_BIN" ]; then
        die "Xray 安装失败"
    fi

    success "Xray 安装完成"

    echo

    "$XRAY_BIN" version || true
}


# ============================================================
# UUID
# ============================================================

generate_uuid() {

    local uuid

    uuid="$("$XRAY_BIN" uuid 2>/dev/null || true)"

    if [ -z "$uuid" ]; then

        if command -v uuidgen >/dev/null 2>&1; then
            uuid="$(uuidgen)"
        else
            die "UUID 生成失败"
        fi

    fi

    echo "$uuid"
}


# ============================================================
# Reality X25519
#
# Xray 26.x 输出：
#
# PrivateKey: xxx
# Password (PublicKey): xxx
# Hash32: xxx
#
# ============================================================

generate_reality_keys() {

    local result

    info "生成 Reality X25519 密钥..."

    result="$("$XRAY_BIN" x25519 2>&1)"

    echo
    echo "$result"
    echo

    # --------------------------------------------------------
    # Xray 26.x
    # --------------------------------------------------------

    REALITY_PRIVATE_KEY="$(
        echo "$result" |
        awk -F': ' '/^PrivateKey:/ {
            print $2
            exit
        }'
    )"

    REALITY_PUBLIC_KEY="$(
        echo "$result" |
        awk -F': ' '/^Password \(PublicKey\):/ {
            print $2
            exit
        }'
    )"

    # --------------------------------------------------------
    # 兼容其它 Xray 输出
    # --------------------------------------------------------

    if [ -z "$REALITY_PRIVATE_KEY" ]; then

        REALITY_PRIVATE_KEY="$(
            echo "$result" |
            awk -F': ' '/^Private key:/ {
                print $2
                exit
            }'
        )"

    fi

    if [ -z "$REALITY_PUBLIC_KEY" ]; then

        REALITY_PUBLIC_KEY="$(
            echo "$result" |
            awk -F': ' '/^Public key:/ {
                print $2
                exit
            }'

        )"

    fi

    if [ -z "$REALITY_PUBLIC_KEY" ]; then

        REALITY_PUBLIC_KEY="$(
            echo "$result" |
            awk -F': ' '/^Password:/ {
                print $2
                exit
            }'
        )"

    fi

    # --------------------------------------------------------
    # 检查
    # --------------------------------------------------------

    if [ -z "$REALITY_PRIVATE_KEY" ]; then
        die "无法解析 Reality PrivateKey"
    fi

    if [ -z "$REALITY_PUBLIC_KEY" ]; then
        die "无法解析 Reality PublicKey"
    fi

    success "Reality 密钥生成成功"

    echo
    echo "PrivateKey:"
    echo "$REALITY_PRIVATE_KEY"

    echo

    echo "PublicKey:"
    echo "$REALITY_PUBLIC_KEY"
}


# ============================================================
# Short ID
# ============================================================

generate_short_id() {

    SHORT_ID="$(openssl rand -hex 8)"

    if [ -z "$SHORT_ID" ]; then
        die "ShortID 生成失败"
    fi

    success "Reality ShortID：${SHORT_ID}"
}


# ============================================================
# 获取服务器 IPv4
# ============================================================

get_server_ip() {

    SERVER_IP=""

    info "获取服务器公网 IPv4..."

    SERVER_IP="$(
        curl -4 -fsS \
        --connect-timeout 5 \
        --max-time 10 \
        https://api.ipify.org \
        2>/dev/null || true
    )"

    if [ -z "$SERVER_IP" ]; then

        SERVER_IP="$(
            curl -4 -fsS \
            --connect-timeout 5 \
            --max-time 10 \
            https://ifconfig.me \
            2>/dev/null || true
        )"

    fi

    if [ -z "$SERVER_IP" ]; then

        SERVER_IP="$(
            hostname -I 2>/dev/null |
            awk '{print $1}'
        )"

    fi

    if [ -z "$SERVER_IP" ]; then

        warn "无法自动获取服务器 IP"

        read -rp "请输入服务器 IP 或域名： " SERVER_IP

    fi

    if [ -z "$SERVER_IP" ]; then
        die "服务器 IP 不能为空"
    fi
}


# ============================================================
# 端口
# ============================================================

input_port() {

    echo

    read -rp "VLESS 端口 [443]: " XRAY_PORT

    XRAY_PORT="${XRAY_PORT:-443}"

    if ! [[ "$XRAY_PORT" =~ ^[0-9]+$ ]]; then
        die "端口必须是数字"
    fi

    if [ "$XRAY_PORT" -lt 1 ] || [ "$XRAY_PORT" -gt 65535 ]; then
        die "端口范围必须是 1-65535"
    fi
}


# ============================================================
# Reality Destination
# ============================================================

input_reality_dest() {

    echo

    echo "============================================================"
    echo "Reality 目标站点"
    echo "============================================================"
    echo

    echo "例如："
    echo "  www.cloudflare.com:443"
    echo "  www.microsoft.com:443"
    echo "  www.yahoo.com:443"
    echo

    echo "建议选择："
    echo "  - 支持 TLS 1.3"
    echo "  - 证书正常"
    echo "  - serverName 与证书匹配"
    echo

    read -rp \
        "Reality 目标站点 [www.cloudflare.com:443]: " \
        REALITY_DEST

    REALITY_DEST="${REALITY_DEST:-www.cloudflare.com:443}"

    # 如果用户只输入域名，自动添加 :443
    if [[ "$REALITY_DEST" != *:* ]]; then
        REALITY_DEST="${REALITY_DEST}:443"
    fi

    REALITY_SERVER_NAME="${REALITY_DEST%%:*}"

    if [ -z "$REALITY_SERVER_NAME" ]; then
        die "无法解析 Reality serverName"
    fi
}


# ============================================================
# SNI
# ============================================================

input_server_name() {

    echo

    read -rp \
        "Reality SNI [${REALITY_SERVER_NAME}]: " \
        REALITY_SNI

    REALITY_SNI="${REALITY_SNI:-$REALITY_SERVER_NAME}"
}


# ============================================================
# Fingerprint
# ============================================================

input_fingerprint() {

    echo

    echo "客户端指纹："
    echo "  chrome"
    echo "  firefox"
    echo "  safari"
    echo "  edge"
    echo "  ios"
    echo "  android"
    echo

    read -rp "客户端指纹 [chrome]: " FINGERPRINT

    FINGERPRINT="${FINGERPRINT:-chrome}"
}


# ============================================================
# 生成服务端配置
# ============================================================

create_config() {

    mkdir -p "$XRAY_DIR"

    backup_config

    info "生成 Xray 配置..."

    cat > "$XRAY_CONFIG" <<EOF
{
  "log": {
    "loglevel": "warning"
  },

  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": ${XRAY_PORT},

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

          "dest": "${REALITY_DEST}",

          "xver": 0,

          "serverNames": [
            "${REALITY_SNI}"
          ],

          "privateKey": "${REALITY_PRIVATE_KEY}",

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
    },

    {
      "protocol": "blackhole",
      "tag": "block"
    }
  ]
}
EOF

    chmod 600 "$XRAY_CONFIG"

    success "配置已生成：${XRAY_CONFIG}"
}


# ============================================================
# 配置测试
# ============================================================

test_config() {

    echo

    info "检查 Xray 配置..."

    if "$XRAY_BIN" run \
        -test \
        -config "$XRAY_CONFIG"; then

        success "Xray 配置检查通过"

    else

        die "Xray 配置检查失败，请检查 ${XRAY_CONFIG}"
    fi
}


# ============================================================
# 防火墙
# ============================================================

configure_firewall() {

    echo

    echo "============================================================"
    echo "配置防火墙"
    echo "============================================================"

    # --------------------------------------------------------
    # UFW
    # --------------------------------------------------------

    if command -v ufw >/dev/null 2>&1; then

        if ufw status 2>/dev/null | grep -q "Status: active"; then

            info "检测到 UFW"

            ufw allow "${XRAY_PORT}/tcp" >/dev/null || true

            success "UFW 已开放 TCP ${XRAY_PORT}"

            return
        fi
    fi

    # --------------------------------------------------------
    # firewalld
    # --------------------------------------------------------

    if command -v firewall-cmd >/dev/null 2>&1; then

        if firewall-cmd --state >/dev/null 2>&1; then

            info "检测到 firewalld"

            firewall-cmd \
                --permanent \
                --add-port="${XRAY_PORT}/tcp" \
                >/dev/null || true

            firewall-cmd \
                --reload \
                >/dev/null || true

            success "firewalld 已开放 TCP ${XRAY_PORT}"

            return
        fi
    fi

    # --------------------------------------------------------
    # iptables
    # --------------------------------------------------------

    if command -v iptables >/dev/null 2>&1; then

        info "检测到 iptables"

        if ! iptables \
            -C INPUT \
            -p tcp \
            --dport "$XRAY_PORT" \
            -j ACCEPT \
            >/dev/null 2>&1; then

            iptables \
                -I INPUT \
                -p tcp \
                --dport "$XRAY_PORT" \
                -j ACCEPT \
                || true
        fi

        success "iptables 已开放 TCP ${XRAY_PORT}"

        return
    fi

    warn "未检测到可自动配置的防火墙"
}


# ============================================================
# Xray 服务
# ============================================================

restart_xray() {

    info "重新加载 systemd..."

    systemctl daemon-reload

    info "设置 Xray 开机启动..."

    systemctl enable xray >/dev/null 2>&1 || true

    info "启动 Xray..."

    systemctl restart xray

    sleep 2

    if systemctl is-active --quiet xray; then

        success "Xray 已正常运行"

    else

        error "Xray 启动失败"

        echo

        systemctl status \
            xray \
            --no-pager \
            -l || true

        echo

        echo "最近日志："

        journalctl \
            -u xray \
            -n 50 \
            --no-pager || true

        exit 1
    fi
}


# ============================================================
# 生成 VLESS URL
# ============================================================

generate_vless_link() {

    # SNI URL 编码
    ENCODED_SNI="$(
        printf '%s' "$REALITY_SNI" |
        sed 's/:/%3A/g'
    )"

    VLESS_LINK="vless://${UUID}@${SERVER_IP}:${XRAY_PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${ENCODED_SNI}&fp=${FINGERPRINT}&pbk=${REALITY_PUBLIC_KEY}&sid=${SHORT_ID}&type=tcp&headerType=none#Xray-Vision-REALITY"
}


# ============================================================
# 保存客户端信息
# ============================================================

save_info() {

    cat > "$XRAY_INFO" <<EOF
============================================================
Xray VLESS + REALITY + XTLS Vision
============================================================

Server IP:
${SERVER_IP}

Port:
${XRAY_PORT}

Protocol:
VLESS

Transport:
TCP / RAW

Security:
REALITY

Flow:
xtls-rprx-vision

UUID:
${UUID}

Reality PrivateKey:
${REALITY_PRIVATE_KEY}

Reality PublicKey:
${REALITY_PUBLIC_KEY}

Reality ShortID:
${SHORT_ID}

Reality Destination:
${REALITY_DEST}

Reality SNI:
${REALITY_SNI}

Fingerprint:
${FINGERPRINT}

------------------------------------------------------------
VLESS URL
------------------------------------------------------------

${VLESS_LINK}

============================================================
EOF

    chmod 600 "$XRAY_INFO"

    success "客户端信息已保存：${XRAY_INFO}"
}


# ============================================================
# 显示安装结果
# ============================================================

show_result() {

    echo
    echo
    echo "============================================================"
    echo -e "${GREEN}       Xray VLESS + REALITY + Vision 安装完成${NC}"
    echo "============================================================"

    echo

    echo -e "${CYAN}服务器 IP:${NC}"
    echo "  ${SERVER_IP}"

    echo

    echo -e "${CYAN}端口:${NC}"
    echo "  ${XRAY_PORT}"

    echo

    echo -e "${CYAN}协议:${NC}"
    echo "  VLESS"

    echo

    echo -e "${CYAN}传输:${NC}"
    echo "  TCP / RAW"

    echo

    echo -e "${CYAN}安全:${NC}"
    echo "  REALITY"

    echo

    echo -e "${CYAN}Flow:${NC}"
    echo "  xtls-rprx-vision"

    echo

    echo -e "${CYAN}UUID:${NC}"
    echo "  ${UUID}"

    echo

    echo -e "${CYAN}Reality PublicKey:${NC}"
    echo "  ${REALITY_PUBLIC_KEY}"

    echo

    echo -e "${CYAN}Reality ShortID:${NC}"
    echo "  ${SHORT_ID}"

    echo

    echo -e "${CYAN}Reality SNI:${NC}"
    echo "  ${REALITY_SNI}"

    echo

    echo -e "${CYAN}Fingerprint:${NC}"
    echo "  ${FINGERPRINT}"

    echo

    echo "============================================================"
    echo -e "${GREEN}v2rayN 导入链接${NC}"
    echo "============================================================"

    echo

    echo "$VLESS_LINK"

    echo

    echo "============================================================"

    echo

    echo "服务端配置："
    echo "  ${XRAY_CONFIG}"

    echo

    echo "客户端参数："
    echo "  ${XRAY_INFO}"

    echo
}


# ============================================================
# 状态
# ============================================================

show_status() {

    echo

    echo "============================================================"
    echo "Xray 状态"
    echo "============================================================"

    echo

    systemctl status \
        xray \
        --no-pager \
        -l || true

    echo

    echo "监听端口："

    if command -v ss >/dev/null 2>&1; then

        ss -lntp |
            grep ":${XRAY_PORT}" ||
            true

    elif command -v netstat >/dev/null 2>&1; then

        netstat -lntp |
            grep ":${XRAY_PORT}" ||
            true
    fi
}


# ============================================================
# 查看配置
# ============================================================

show_config() {

    if [ ! -f "$XRAY_CONFIG" ]; then

        warn "配置文件不存在"

        return
    fi

    echo

    echo "============================================================"
    echo "Xray 配置"
    echo "============================================================"

    echo

    cat "$XRAY_CONFIG"

    echo
}


# ============================================================
# 查看客户端信息
# ============================================================

show_client_info() {

    if [ ! -f "$XRAY_INFO" ]; then

        warn "没有找到客户端信息"

        return
    fi

    echo

    cat "$XRAY_INFO"

    echo
}


# ============================================================
# 卸载
# ============================================================

uninstall_xray() {

    echo

    warn "此操作将卸载 Xray。"

    echo "配置文件默认不会主动删除。"

    echo

    read -rp "确认卸载？请输入 YES： " answer

    if [ "$answer" != "YES" ]; then

        echo "已取消"

        return
    fi

    systemctl stop xray 2>/dev/null || true

    systemctl disable xray 2>/dev/null || true

    bash -c "$(curl -fsSL "$INSTALL_SCRIPT_URL")" @ remove || true

    success "Xray 已卸载"

    echo

    echo "配置仍保留在："
    echo "  ${XRAY_DIR}"
}


# ============================================================
# 安装主流程
# ============================================================

install_main() {

    clear

    echo "============================================================"
    echo " Xray VLESS + REALITY + XTLS Vision"
    echo "============================================================"

    echo

    check_root

    check_os

    check_commands

    install_xray

    echo

    echo "============================================================"
    echo "生成 VLESS + REALITY + Vision 配置"
    echo "============================================================"

    get_server_ip

    echo

    echo "服务器 IP：${SERVER_IP}"

    input_port

    input_reality_dest

    input_server_name

    input_fingerprint

    echo

    info "生成 UUID..."

    UUID="$(generate_uuid)"

    if [ -z "$UUID" ]; then
        die "UUID 生成失败"
    fi

    success "UUID：${UUID}"

    echo

    generate_reality_keys

    echo

    generate_short_id

    echo

    create_config

    echo

    test_config

    echo

    configure_firewall

    echo

    restart_xray

    echo

    generate_vless_link

    save_info

    show_result

    pause_enter

    install_menu
}


# ============================================================
# 菜单
# ============================================================

install_menu() {

    clear

    echo "============================================================"
    echo " Xray VLESS + REALITY + XTLS Vision"
    echo "============================================================"

    echo

    echo "1. 安装 / 重装"
    echo "2. 查看状态"
    echo "3. 查看配置"
    echo "4. 重启 Xray"
    echo "5. 查看客户端参数"
    echo "6. 查看 Xray 日志"
    echo "7. 卸载 Xray"
    echo "0. 退出"

    echo

    read -rp "请选择 [0-7]： " MENU

    case "$MENU" in

        1)

            install_main

            ;;

        2)

            show_status

            pause_enter

            install_menu

            ;;

        3)

            show_config

            pause_enter

            install_menu

            ;;

        4)

            systemctl restart xray

            success "Xray 已重启"

            show_status

            pause_enter

            install_menu

            ;;

        5)

            show_client_info

            pause_enter

            install_menu

            ;;

        6)

            echo

            journalctl \
                -u xray \
                -n 100 \
                --no-pager ||
                true

            pause_enter

            install_menu

            ;;

        7)

            uninstall_xray

            pause_enter

            install_menu

            ;;

        0)

            exit 0

            ;;

        *)

            warn "无效选项"

            sleep 1

            install_menu

            ;;

    esac
}


# ============================================================
# 命令行模式
# ============================================================

main() {

    check_root

    if [ "$#" -gt 0 ]; then

        case "$1" in

            install)

                install_main

                ;;

            status)

                show_status

                ;;

            config)

                show_config

                ;;

            info)

                show_client_info

                ;;

            restart)

                systemctl restart xray

                success "Xray 已重启"

                ;;

            logs)

                journalctl \
                    -u xray \
                    -n 100 \
                    --no-pager

                ;;

            uninstall)

                uninstall_xray

                ;;

            *)

                echo
                echo "用法："
                echo
                echo "  $0"
                echo "  $0 install"
                echo "  $0 status"
                echo "  $0 config"
                echo "  $0 info"
                echo "  $0 restart"
                echo "  $0 logs"
                echo "  $0 uninstall"
                echo

                ;;

        esac

    else

        install_menu

    fi
}


# ============================================================
# Start
# ============================================================

main "$@"
