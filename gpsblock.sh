cat > /usr/local/bin/gpsblock <<'EOF'
#!/bin/bash

set -e

CONF="/etc/dnsmasq.d/gpsblock.conf"
BACKUP="/etc/resolv.conf.gpsblock.bak"

install_dnsmasq() {
    command -v dnsmasq >/dev/null 2>&1 && return

    if command -v apt-get >/dev/null 2>&1; then
        apt-get update -qq
        apt-get install -y dnsmasq
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y dnsmasq
    elif command -v yum >/dev/null 2>&1; then
        yum install -y dnsmasq
    elif command -v apk >/dev/null 2>&1; then
        apk add dnsmasq
    else
        echo "不支持的系统"
        exit 1
    fi
}

on() {
    install_dnsmasq

    mkdir -p /etc/dnsmasq.d

    [ -f "$BACKUP" ] || cp -a /etc/resolv.conf "$BACKUP" 2>/dev/null || true

    cat > "$CONF" <<'DNS"
# 仅阻断定位相关域名
# location
address=/location/0.0.0.0
address=/location/::
# geolocation
address=/geolocation/0.0.0.0
address=/geolocation/::
# geolocate
address=/geolocate/0.0.0.0
address=/geolocate/::
DNS

    if command -v systemctl >/dev/null 2>&1; then
        systemctl enable dnsmasq >/dev/null 2>&1 || true
        systemctl restart dnsmasq
    else
        service dnsmasq restart 2>/dev/null || true
    fi

    rm -f /etc/resolv.conf
    printf 'nameserver 127.0.0.1\n' > /etc/resolv.conf

    echo "GPS 定位域名拦截：已开启"
    echo "匹配：location / geolocation / geolocate"
    echo "其他网站和 API：不主动拦截"
}

off() {
    rm -f "$CONF"

    if [ -f "$BACKUP" ]; then
        rm -f /etc/resolv.conf
        cp -a "$BACKUP" /etc/resolv.conf
        rm -f "$BACKUP"
    else
        rm -f /etc/resolv.conf
        printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' > /etc/resolv.conf
    fi

    if command -v systemctl >/dev/null 2>&1; then
        systemctl restart dnsmasq 2>/dev/null || true
    else
        service dnsmasq restart 2>/dev/null || true
    fi

    echo "GPS 定位域名拦截：已关闭"
}

status() {
    if [ -f "$CONF" ]; then
        echo "GPS 定位域名拦截：已开启"
        echo
        echo "拦截规则："
        echo "  *location*"
        echo "  *geolocation*"
        echo "  *geolocate*"
    else
        echo "GPS 定位域名拦截：已关闭"
    fi
}

if [ "$(id -u)" != "0" ]; then
    echo "请使用 root 运行"
    exit 1
fi

case "$1" in
    on|start)
        on
        ;;
    off|stop)
        off
        ;;
    status)
        status
        ;;
    *)
        echo "用法：gpsblock {on|off|status}"
        exit 1
        ;;
esac
EOF

chmod +x /usr/local/bin/gpsblock
gpsblock on
