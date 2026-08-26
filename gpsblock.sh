#!/bin/bash

set -e

APP_DIR="/opt/gpsblock"
ADDON="$APP_DIR/gpsblock.py"
CONF="$APP_DIR/config"
NFT="/etc/nftables.d/gpsblock.nft"
PORT="8080"

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
NC="\033[0m"

die() {
    echo -e "${RED}错误：$1${NC}"
    exit 1
}

root_check() {
    [ "$(id -u)" = "0" ] || die "请使用 root 运行"
}

detect_os() {
    if command -v apt-get >/dev/null 2>&1; then
        OS="debian"
    elif command -v dnf >/dev/null 2>&1; then
        OS="fedora"
    elif command -v yum >/dev/null 2>&1; then
        OS="rhel"
    else
        die "暂不支持此系统"
    fi
}

install_packages() {
    echo "正在安装依赖..."

    case "$OS" in
        debian)
            apt-get update
            DEBIAN_FRONTEND=noninteractive apt-get install -y \
                python3 python3-pip nftables ca-certificates
            ;;
        fedora)
            dnf install -y python3 python3-pip nftables ca-certificates
            ;;
        rhel)
            yum install -y python3 python3-pip nftables ca-certificates
            ;;
    esac

    python3 -m pip install --break-system-packages -U mitmproxy \
        >/dev/null 2>&1 || \
    python3 -m pip install -U mitmproxy >/dev/null 2>&1
}

create_addon() {
    mkdir -p "$APP_DIR"

    cat > "$ADDON" <<'PY'
from mitmproxy import http

BLOCK_WORDS = (
    "location",
    "geolocation",
    "geolocate",
)

def should_block(url: str) -> bool:
    u = url.lower()

    for word in BLOCK_WORDS:
        if word in u:
            return True

    return False

def request(flow: http.HTTPFlow):
    url = flow.request.pretty_url

    if should_block(url):
        flow.response = http.Response.make(
            403,
            b"GPS location request blocked by gpsblock",
            {
                "Content-Type": "text/plain",
                "Cache-Control": "no-store",
            },
        )

        print("[GPSBLOCK] BLOCK:", url)
    else:
        print("[GPSBLOCK] ALLOW:", url)
PY
}

create_config() {
    cat > "$CONF" <<EOF
PORT=$PORT
EOF
}

create_nft() {
    cat > "$NFT" <<EOF
table inet gpsblock {

    chain prerouting {
        type nat hook prerouting priority dstnat;

        tcp dport 80 redirect to :$PORT
        tcp dport 443 redirect to :$PORT
    }
}
EOF
}

remove_nft() {
    nft delete table inet gpsblock 2>/dev/null || true
    rm -f "$NFT"
}

create_service() {
    cat > /etc/systemd/system/gpsblock.service <<EOF
[Unit]
Description=GPSBlock Transparent Proxy
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/mitmdump \
    --mode transparent \
    --listen-host 0.0.0.0 \
    --listen-port $PORT \
    -s $ADDON \
    --set block_global=false \
    --set connection_strategy=lazy
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
}

enable_forwarding() {
    sysctl -w net.ipv4.ip_forward=1 >/dev/null

    cat > /etc/sysctl.d/99-gpsblock.conf <<EOF
net.ipv4.ip_forward=1
EOF

    sysctl --system >/dev/null 2>&1 || true
}

enable() {
    root_check
    detect_os
    install_packages
    create_addon
    create_config
    create_nft
    create_service
    enable_forwarding

    echo
    echo -e "${YELLOW}正在生成透明代理规则...${NC}"

    nft delete table inet gpsblock 2>/dev/null || true
    nft -f "$NFT"

    systemctl enable gpsblock >/dev/null 2>&1
    systemctl restart gpsblock

    echo
    echo -e "${GREEN}================================${NC}"
    echo -e "${GREEN} GPSBLOCK 已开启${NC}"
    echo -e "${GREEN}================================${NC}"
    echo
    echo "拦截关键词："
    echo "  location"
    echo "  geolocation"
    echo "  geolocate"
    echo
    echo "HTTP：已检查"
    echo "HTTPS：已检查"
    echo "DNS：不使用"
    echo
    echo "其他请求：正常放行"
    echo
    echo "注意：HTTPS 客户端需要信任 mitmproxy CA。"
    echo
}

disable() {
    root_check

    systemctl stop gpsblock 2>/dev/null || true
    systemctl disable gpsblock 2>/dev/null || true

    remove_nft

    echo
    echo -e "${GREEN}GPSBLOCK 已关闭${NC}"
    echo
}

status() {
    echo
    echo "================================"
    echo " GPSBLOCK 状态"
    echo "================================"
    echo

    if systemctl is-active --quiet gpsblock 2>/dev/null; then
        echo "代理状态：运行中"
    else
        echo "代理状态：未运行"
    fi

    if nft list table inet gpsblock >/dev/null 2>&1; then
        echo "防火墙：已启用"
    else
        echo "防火墙：未启用"
    fi

    echo
    echo "拦截关键词："
    echo "  location"
    echo "  geolocation"
    echo "  geolocate"
    echo
}

logs() {
    journalctl -u gpsblock -f
}

install() {
    root_check
    detect_os
    install_packages
    create_addon
    create_config
    create_nft
    create_service
    enable_forwarding

    echo
    echo -e "${GREEN}安装完成${NC}"
    echo
    echo "下一步："
    echo "  gpsblock on"
    echo "  gpsblock off"
    echo "  gpsblock status"
    echo "  gpsblock logs"
}

menu() {
    while true; do
        clear

        echo "================================"
        echo "          GPSBLOCK"
        echo "================================"
        echo
        echo "1. 开启"
        echo "2. 关闭"
        echo "3. 查看状态"
        echo "4. 查看拦截日志"
        echo "5. 退出"
        echo
        printf "请选择："

        read -r choice

        case "$choice" in
            1)
                enable
                read -r -p "按回车继续..."
                ;;
            2)
                disable
                read -r -p "按回车继续..."
                ;;
            3)
                status
                read -r -p "按回车继续..."
                ;;
            4)
                logs
                ;;
            5)
                exit 0
                ;;
            *)
                echo "无效选项"
                sleep 1
                ;;
        esac
    done
}

root_check

case "${1:-}" in
    install)
        install
        ;;
    on|start)
        enable
        ;;
    off|stop)
        disable
        ;;
    status)
        status
        ;;
    logs)
        logs
        ;;
    *)
        menu
        ;;
esac
