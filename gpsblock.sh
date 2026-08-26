#!/bin/bash

IPSET4="gpsblock"
IPSET6="gpsblock6"

CHAIN4="GPSBLOCK"
CHAIN6="GPSBLOCK"

DOMAINS="
www.googleapis.com
geolocation.googleapis.com
geocode.googleapis.com
location.services.mozilla.com
"

TEAM_URL="https://www.nekoqwq.com"

# =========================
# Banner
# =========================

banner() {
    clear

    cat <<'EOF'
 _   _       _    _                    _   _            _       _
| \ | | ___ | |  / \   _ __  _   _ ___| \ | | ___  ___ | |_ ___| |__   ___
|  \| |/ _ \| | / _ \ | '_ \| | | / __|  \| |/ _ \/ __|| __/ __| '_ \ / __|
| |\  | (_) | |/ ___ \| | | | |_| \__ \ |\  |  __/\__ \| || (__| | | | (__
|_| \_|\___/|_/_/   \_\_| |_|\__,_|___/_| \_|\___||___/ \__\___|_| |_|\___|

                    NoAnyLocationCheck

          一個由 MTF 藥娘發瘋開發的防送中腳本
          團隊：https://www.nekoqwq.com

EOF
}

# =========================
# 自動安裝依賴
# =========================

install_dependencies() {

    if command -v ipset >/dev/null 2>&1 &&
       command -v iptables >/dev/null 2>&1 &&
       command -v ip6tables >/dev/null 2>&1 &&
       command -v getent >/dev/null 2>&1; then
        return 0
    fi

    echo "正在檢查並安裝必要组件..."
    echo

    if command -v apt-get >/dev/null 2>&1; then

        export DEBIAN_FRONTEND=noninteractive

        apt-get update -qq

        apt-get install -y -qq \
            ipset \
            iptables \
            iproute2 \
            libc-bin \
            >/dev/null 2>&1

    elif command -v dnf >/dev/null 2>&1; then

        dnf install -y \
            ipset \
            iptables \
            iproute \
            glibc-common \
            >/dev/null 2>&1

    elif command -v yum >/dev/null 2>&1; then

        yum install -y \
            ipset \
            iptables \
            iproute \
            glibc-common \
            >/dev/null 2>&1

    elif command -v apk >/dev/null 2>&1; then

        apk add \
            ipset \
            iptables \
            iproute2 \
            libc-utils \
            >/dev/null 2>&1

    else
        echo "無法自動判斷套件管理器"
        echo "請手動安裝 ipset、iptables"
        exit 1
    fi

    if ! command -v ipset >/dev/null 2>&1; then
        echo "ipset 安裝失敗"
        exit 1
    fi

    if ! command -v iptables >/dev/null 2>&1; then
        echo "iptables 安裝失敗"
        exit 1
    fi

    echo "必要组件安裝完成"
    echo
}

# =========================
# 保存規則
# =========================

save_rules() {

    mkdir -p /etc/iptables

    iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
    ip6tables-save > /etc/iptables/rules.v6 2>/dev/null || true

    if command -v ipset >/dev/null 2>&1; then
        ipset save > /etc/iptables/ipsets.conf 2>/dev/null || true
    fi

    if command -v netfilter-persistent >/dev/null 2>&1; then
        netfilter-persistent save >/dev/null 2>&1 || true
    fi
}

# =========================
# 開啟
# =========================

enable_block() {

    install_dependencies

    # IPv4
    ipset create "$IPSET4" hash:ip family inet -exist

    # IPv6
    ipset create "$IPSET6" hash:ip family inet6 -exist

    # 清除舊 IP
    ipset flush "$IPSET4" 2>/dev/null || true
    ipset flush "$IPSET6" 2>/dev/null || true

    # =========================
    # IPv4 DNS 解析
    # =========================

    for domain in $DOMAINS; do

        getent ahostsv4 "$domain" 2>/dev/null |
        awk '{print $1}' |
        sort -u |
        while read -r ip; do

            [ -n "$ip" ] &&
            ipset add "$IPSET4" "$ip" -exist

        done

    done

    # =========================
    # IPv6 DNS 解析
    # =========================

    for domain in $DOMAINS; do

        getent ahostsv6 "$domain" 2>/dev/null |
        awk '{print $1}' |
        sort -u |
        while read -r ip; do

            [ -n "$ip" ] &&
            ipset add "$IPSET6" "$ip" -exist

        done

    done

    # =========================
    # IPv4 Chain
    # =========================

    iptables -N "$CHAIN4" 2>/dev/null || true

    iptables -F "$CHAIN4"

    iptables -A "$CHAIN4" \
        -m set \
        --match-set "$IPSET4" dst \
        -j REJECT

    iptables -C INPUT -j "$CHAIN4" 2>/dev/null ||
    iptables -I INPUT 1 -j "$CHAIN4"

    iptables -C OUTPUT -j "$CHAIN4" 2>/dev/null ||
    iptables -I OUTPUT 1 -j "$CHAIN4"

    iptables -C FORWARD -j "$CHAIN4" 2>/dev/null ||
    iptables -I FORWARD 1 -j "$CHAIN4"

    # =========================
    # IPv6 Chain
    # =========================

    ip6tables -N "$CHAIN6" 2>/dev/null || true

    ip6tables -F "$CHAIN6"

    ip6tables -A "$CHAIN6" \
        -m set \
        --match-set "$IPSET6" dst \
        -j REJECT

    ip6tables -C INPUT -j "$CHAIN6" 2>/dev/null ||
    ip6tables -I INPUT 1 -j "$CHAIN6"

    ip6tables -C OUTPUT -j "$CHAIN6" 2>/dev/null ||
    ip6tables -I OUTPUT 1 -j "$CHAIN6"

    ip6tables -C FORWARD -j "$CHAIN6" 2>/dev/null ||
    ip6tables -I FORWARD 1 -j "$CHAIN6"

    save_rules

    echo "NoAnyLocationCheck 已開啟"
    echo
    echo "IPv4：已啟用"
    echo "IPv6：已啟用"
    echo "定位 API：已攔截"
}

# =========================
# 關閉
# =========================

disable_block() {

    # IPv4
    iptables -D INPUT -j "$CHAIN4" 2>/dev/null || true
    iptables -D OUTPUT -j "$CHAIN4" 2>/dev/null || true
    iptables -D FORWARD -j "$CHAIN4" 2>/dev/null || true

    iptables -F "$CHAIN4" 2>/dev/null || true
    iptables -X "$CHAIN4" 2>/dev/null || true

    # IPv6
    ip6tables -D INPUT -j "$CHAIN6" 2>/dev/null || true
    ip6tables -D OUTPUT -j "$CHAIN6" 2>/dev/null || true
    ip6tables -D FORWARD -j "$CHAIN6" 2>/dev/null || true

    ip6tables -F "$CHAIN6" 2>/dev/null || true
    ip6tables -X "$CHAIN6" 2>/dev/null || true

    # 移除 ipset
    ipset destroy "$IPSET4" 2>/dev/null || true
    ipset destroy "$IPSET6" 2>/dev/null || true

    save_rules

    echo "NoAnyLocationCheck 已關閉"
    echo
    echo "IPv4：已解除"
    echo "IPv6：已解除"
    echo "定位 API：不再攔截"
}

# =========================
# 選單
# =========================

menu() {

    banner

    echo "1. 開啟"
    echo "2. 關閉"
    echo "3. 退出"
    echo

    read -r -p "請選擇： " choice

    case "$choice" in

        1)
            enable_block
            ;;

        2)
            disable_block
            ;;

        3)
            exit 0
            ;;

        *)
            echo "無效選項"
            ;;

    esac
}

# =========================
# Root
# =========================

if [ "$(id -u)" != "0" ]; then
    echo "請使用 root 執行"
    exit 1
fi

# =========================
# 命令模式
# =========================

case "${1:-}" in

    on|start|enable)
        banner
        enable_block
        ;;

    off|stop|disable)
        banner
        disable_block
        ;;

    *)
        menu
        ;;

esac
