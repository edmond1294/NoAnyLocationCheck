#!/bin/bash

set -e

CONF="/etc/dnsmasq.d/gpsblock.conf"
BACKUP="/etc/resolv.conf.gpsblock.bak"

DOMAINS="
location
geolocation
geolocate
"

check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo "请使用 root 运行"
        exit 1
    fi
}

install_dnsmasq() {
    if command -v dnsmasq >/dev/null 2>&1; then
        return
    fi

    echo "正在安装 dnsmasq..."

    if command -v apt-get >/dev/null 2>&1; then
        apt-get update -qq
        DEBIAN_FRONTEND=noninteractive apt-get install -y dnsmasq
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y dnsmasq
    elif command -v yum >/dev/null 2>&1; then
        yum install -y dnsmasq
    elif command -v apk >/dev/null 2>&1; then
        apk add dnsmasq
    else
        echo "无法自动安装 dnsmasq"
        exit 1
    fi
}

enable_block() {
    install_dnsmasq

    mkdir -p /etc/dnsmasq.d

    if [ ! -f "$BACKUP" ]; then
        cp -a /etc/resolv.conf "$BACKUP" 2>/dev/null || true
    fi

    cat > "$CONF" <<'DNSCONF'
# GPS location domain blocking
# Only block domains containing:
# location
# geolocation
# geolocate

address=/location/0.0.0.0
address=/location/::
address=/geolocation/0.0.0.0
address=/geolocation/::
address=/geolocate/0.0.0.0
address=/geolocate/::
DNSCONF

    if command -v systemctl >/dev/null 2>&1; then
        systemctl enable dnsmasq >/dev/null 2>&1 || true
        systemctl restart dnsmasq
    else
        service dnsmasq restart 2>/dev/null || true
    fi

    rm -f /etc/resolv.conf
    printf '%s\n' 'nameserver 127.0.0.1' > /etc/resolv.conf

    echo
    echo "GPS 定位域名阻断：已开启"
    echo
    echo "阻断关键词："
    echo "  location"
    echo "  geolocation"
    echo "  geolocate"
    echo
    echo "其他网站和 API：不主动阻断"
}

disable_block() {
    rm -f "$CONF"

    if [ -f "$BACKUP" ]; then
        rm -f /etc/resolv.conf
        cp -a "$BACKUP" /etc/resolv.conf
        rm -f "$BACKUP"
    else
        rm -f /etc/resolv.conf
        printf '%s\n' \
            'nameserver 1.1.1.1' \
            'nameserver 8.8.8.8' \
            > /etc/resolv.conf
    fi

    if command -v systemctl >/dev/null 2>&1; then
        systemctl restart dnsmasq 2>/dev/null || true
    else
        service dnsmasq restart 2>/dev/null || true
    fi

    echo
    echo "GPS 定位域名阻断：已关闭"
}

show_status() {
    if [ -f "$CONF" ]; then
        echo "GPS 定位域名阻断：已开启"
        echo
        echo "当前规则："
        cat "$CONF"
    else
        echo "GPS 定位域名阻断：已关闭"
    fi
}

check_root

case "${1:-}" in
    on|start)
        enable_block
        ;;
    off|stop)
        disable_block
        ;;
    status)
        show_status
        ;;
    *)
        echo "用法："
        echo "  gpsblock on"
        echo "  gpsblock off"
        echo "  gpsblock status"
        exit 1
        ;;
esac
