#!/bin/bash

set -e

VERSION="1.0.0"
CONF="/etc/dnsmasq.d/gpsblock.conf"
BACKUP="/etc/resolv.conf.gpsblock.backup"
MARKER="/etc/gpsblock.enabled"

check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo "请使用 root 运行"
        exit 1
    fi
}

detect_os() {
    if command -v apt-get >/dev/null 2>&1; then
        OS="debian"
    elif command -v dnf >/dev/null 2>&1; then
        OS="dnf"
    elif command -v yum >/dev/null 2>&1; then
        OS="yum"
    elif command -v apk >/dev/null 2>&1; then
        OS="alpine"
    else
        echo "无法识别系统"
        exit 1
    fi
}

install_dnsmasq() {
    if command -v dnsmasq >/dev/null 2>&1; then
        return
    fi

    echo "正在安装 dnsmasq..."

    case "$OS" in
        debian)
            apt-get update -qq
            DEBIAN_FRONTEND=noninteractive apt-get install -y dnsmasq
            ;;
        dnf)
            dnf install -y dnsmasq
            ;;
        yum)
            yum install -y dnsmasq
            ;;
        alpine)
            apk add dnsmasq
            ;;
    esac
}

restart_dnsmasq() {
    if command -v systemctl >/dev/null 2>&1; then
        systemctl enable dnsmasq >/dev/null 2>&1 || true
        systemctl restart dnsmasq
        return
    fi

    if command -v rc-service >/dev/null 2>&1; then
        rc-service dnsmasq restart
        return
    fi

    service dnsmasq restart 2>/dev/null || true
}

start_dnsmasq() {
    if command -v systemctl >/dev/null 2>&1; then
        systemctl enable dnsmasq >/dev/null 2>&1 || true
        systemctl start dnsmasq 2>/dev/null || true
        return
    fi

    if command -v rc-service >/dev/null 2>&1; then
        rc-service dnsmasq start 2>/dev/null || true
        return
    fi

    service dnsmasq start 2>/dev/null || true
}

backup_dns() {
    if [ ! -f "$BACKUP" ]; then
        if [ -f /etc/resolv.conf ]; then
            cp -a /etc/resolv.conf "$BACKUP" 2>/dev/null || true
        fi
    fi
}

write_config() {
    mkdir -p /etc/dnsmasq.d

    cat > "$CONF" <<'DNSCONFIG'
# GPSBLOCK
# Only block location-related DNS names.
# Does NOT block entire Google / Apple / Microsoft domains.

address=/location/0.0.0.0
address=/location/::
address=/geolocation/0.0.0.0
address=/geolocation/::
address=/geolocate/0.0.0.0
address=/geolocate/::
DNSCONFIG
}

set_local_dns() {
    rm -f /etc/resolv.conf

    cat > /etc/resolv.conf <<'DNS'
nameserver 127.0.0.1
DNS
}

enable() {
    check_root
    detect_os
    install_dnsmasq
    backup_dns
    write_config

    start_dnsmasq
    restart_dnsmasq

    set_local_dns

    touch "$MARKER"

    echo
    echo "================================"
    echo " GPS 定位域名阻断：已开启"
    echo "================================"
    echo
    echo "阻断：location"
    echo "阻断：geolocation"
    echo "阻断：geolocate"
    echo
    echo "普通网站：正常"
    echo "普通 API：正常"
    echo "Google / Apple / Microsoft：不整体阻断"
    echo
}

disable() {
    check_root

    rm -f "$CONF"
    rm -f "$MARKER"

    if [ -f "$BACKUP" ]; then
        rm -f /etc/resolv.conf
        cp -a "$BACKUP" /etc/resolv.conf
        rm -f "$BACKUP"
    else
        rm -f /etc/resolv.conf

        cat > /etc/resolv.conf <<'DNS'
nameserver 1.1.1.1
nameserver 8.8.8.8
DNS
    fi

    restart_dnsmasq 2>/dev/null || true

    echo
    echo "================================"
    echo " GPS 定位域名阻断：已关闭"
    echo "================================"
    echo
}

status() {
    echo
    echo "================================"
    echo " GPSBLOCK 状态"
    echo "================================"
    echo

    if [ -f "$MARKER" ] && [ -f "$CONF" ]; then
        echo "状态：已开启"
    else
        echo "状态：已关闭"
    fi

    echo

    if [ -f "$CONF" ]; then
        echo "当前拦截规则："
        echo
        echo "  *location*"
        echo "  *geolocation*"
        echo "  *geolocate*"
    fi

    echo
}

menu() {
    while true; do
        clear

        echo "================================"
        echo "          GPSBLOCK"
        echo "       Version $VERSION"
        echo "================================"
        echo
        echo "1. 开启定位域名阻断"
        echo "2. 关闭定位域名阻断"
        echo "3. 查看当前状态"
        echo "4. 退出"
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
                exit 0
                ;;
            *)
                echo
                echo "无效选项"
                sleep 1
                ;;
        esac
    done
}

check_root

case "${1:-}" in
    on|start|enable)
        enable
        ;;
    off|stop|disable)
        disable
        ;;
    status)
        status
        ;;
    *)
        menu
        ;;
esac
