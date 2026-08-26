#!/bin/bash

IPSET="gpsblock"
CHAIN="GPSBLOCK"

# 定位相關 API 域名
DOMAINS="
www.googleapis.com
geolocation.googleapis.com
geocode.googleapis.com
location.services.mozilla.com
"

# 建立 ipset
ipset create "$IPSET" hash:ip -exist

# 解析 API IP
for domain in $DOMAINS; do
    getent ahostsv4 "$domain" 2>/dev/null |
    awk '{print $1}' |
    sort -u |
    while read -r ip; do
        [ -n "$ip" ] && ipset add "$IPSET" "$ip" -exist
    done
done

# 建立 chain
iptables -N "$CHAIN" 2>/dev/null || true
iptables -F "$CHAIN"

# 只攔指定 API IP
iptables -A "$CHAIN" \
    -m set --match-set "$IPSET" dst \
    -j REJECT

# INPUT
iptables -C INPUT -j "$CHAIN" 2>/dev/null ||
iptables -I INPUT 1 -j "$CHAIN"

# OUTPUT
iptables -C OUTPUT -j "$CHAIN" 2>/dev/null ||
iptables -I OUTPUT 1 -j "$CHAIN"

# FORWARD
iptables -C FORWARD -j "$CHAIN" 2>/dev/null ||
iptables -I FORWARD 1 -j "$CHAIN"

# 保存
mkdir -p /etc/iptables
iptables-save > /etc/iptables/rules.v4

echo "GPS API 攔截已啟用"
echo "INPUT / OUTPUT / FORWARD"
