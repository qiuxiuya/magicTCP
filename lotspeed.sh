#!/usr/bin/env bash

INSTALLED_KVER=""
LOTSPEED_INSTALL_URL="https://raw.githubusercontent.com/qiuxiuya/lotspeed/zeta-tcp/install.sh"

get_cpu_level() {
    awk '
BEGIN {
    while (!/flags/) if (getline < "/proc/cpuinfo" != 1) exit 1
    if (/lm/&&/cmov/&&/cx8/&&/fpu/&&/fxsr/&&/mmx/&&/syscall/&&/sse2/) level = 1
    if (level == 1 && /cx16/&&/lahf/&&/popcnt/&&/sse4_1/&&/sse4_2/&&/ssse3/) level = 2
    if (level == 2 && /avx/&&/avx2/&&/bmi1/&&/bmi2/&&/f16c/&&/fma/&&/abm/&&/movbe/&&/xsave/) level = 3
    if (level == 3 && /avx512f/&&/avx512bw/&&/avx512cd/&&/avx512dq/&&/avx512vl/) level = 4
    if (level > 0) { print level; exit 0 }
    exit 1
}'
}

install_xanmod_kernel() {
    apt-get update
    apt-get install -y wget curl

    LEVEL=$(get_cpu_level)
    WORKDIR=$(mktemp -d)
    cd "$WORKDIR" || exit 1

    if [ "$LEVEL" = "1" ]; then
        URLS=(
            "https://raw.githubusercontent.com/qiuxiuya/magicTCP/main/xanmod/6.4.10/6.4.10-x64v1-xanmod1/linux-image-6.4.10-x64v1-xanmod1_6.4.10-x64v1-xanmod1-0~20230811.g489fabdc_amd64.deb"
            "https://raw.githubusercontent.com/qiuxiuya/magicTCP/main/xanmod/6.4.10/6.4.10-x64v1-xanmod1/linux-headers-6.4.10-x64v1-xanmod1_6.4.10-x64v1-xanmod1-0~20230811.g489fabdc_amd64.deb"
            "https://raw.githubusercontent.com/qiuxiuya/magicTCP/main/xanmod/6.4.10/6.4.10-x64v1-xanmod1/linux-libc-dev_6.4.10-x64v1-xanmod1-0~20230811.g489fabdc_amd64.deb"
        )
    elif [ "$LEVEL" = "2" ]; then
        URLS=(
            "https://raw.githubusercontent.com/qiuxiuya/magicTCP/main/xanmod/6.4.10/6.4.10-x64v2-xanmod1/linux-image-6.4.10-x64v2-xanmod1_6.4.10-x64v2-xanmod1-0~20230811.g489fabdc_amd64.deb"
            "https://raw.githubusercontent.com/qiuxiuya/magicTCP/main/xanmod/6.4.10/6.4.10-x64v2-xanmod1/linux-headers-6.4.10-x64v2-xanmod1_6.4.10-x64v2-xanmod1-0~20230811.g489fabdc_amd64.deb"
            "https://raw.githubusercontent.com/qiuxiuya/magicTCP/main/xanmod/6.4.10/6.4.10-x64v2-xanmod1/linux-libc-dev_6.4.10-x64v2-xanmod1-0~20230811.g489fabdc_amd64.deb"
        )
    elif [ "$LEVEL" = "3" ]; then
        URLS=(
            "https://raw.githubusercontent.com/qiuxiuya/magicTCP/main/xanmod/6.4.10/6.4.10-x64v3-xanmod1/linux-image-6.4.10-x64v3-xanmod1_6.4.10-x64v3-xanmod1-0~20230811.g489fabdc_amd64.deb"
            "https://raw.githubusercontent.com/qiuxiuya/magicTCP/main/xanmod/6.4.10/6.4.10-x64v3-xanmod1/linux-headers-6.4.10-x64v3-xanmod1_6.4.10-x64v3-xanmod1-0~20230811.g489fabdc_amd64.deb"
            "https://raw.githubusercontent.com/qiuxiuya/magicTCP/main/xanmod/6.4.10/6.4.10-x64v3-xanmod1/linux-libc-dev_6.4.10-x64v3-xanmod1-0~20230811.g489fabdc_amd64.deb"
        )
    elif [ "$LEVEL" = "4" ]; then
        URLS=(
            "https://raw.githubusercontent.com/qiuxiuya/magicTCP/main/xanmod/6.4.10/6.4.10-x64v4-xanmod1/linux-image-6.4.10-x64v4-xanmod1_6.4.10-x64v4-xanmod1-0~20230811.g489fabdc_amd64.deb"
            "https://raw.githubusercontent.com/qiuxiuya/magicTCP/main/xanmod/6.4.10/6.4.10-x64v4-xanmod1/linux-headers-6.4.10-x64v4-xanmod1_6.4.10-x64v4-xanmod1-0~20230811.g489fabdc_amd64.deb"
            "https://raw.githubusercontent.com/qiuxiuya/magicTCP/main/xanmod/6.4.10/6.4.10-x64v4-xanmod1/linux-libc-dev_6.4.10-x64v4-xanmod1-0~20230811.g489fabdc_amd64.deb"
        )
    else
        exit 1
    fi

    for url in "${URLS[@]}"; do
        filename=$(basename "$url")
        filename=$(printf '%b' "${filename//%/\\x}")
        filename="${filename%%\?*}"
        wget -q --show-progress "$url" -O "$filename" || exit 1
    done

    dpkg -i ./*.deb

    cd /
    rm -rf "$WORKDIR"

    for kver in $(ls /lib/modules | grep xanmod); do
        update-initramfs -c -k "$kver"
    done

    update-grub
    reboot
}

install_lotspeed() {
    command -v curl &>/dev/null || {
        apt-get update
        apt-get install -y curl
    }

    bash <(curl -sSL "$LOTSPEED_INSTALL_URL")
}

apply_tcp_optimization() {
    mkdir -p /etc/security/limits.d/ /etc/systemd/system.conf.d/ /etc/systemd/user.conf.d/

    cat > /etc/security/limits.d/99-network-performance.conf <<EOF
* soft nofile 1048576
* hard nofile 1048576
* soft nproc 65535
* hard nproc 65535
EOF

    cat > /etc/systemd/system.conf.d/99-network-performance.conf <<EOF
[Manager]
DefaultLimitNOFILE=1048576
DefaultLimitNPROC=65535
EOF

    cat > /etc/systemd/user.conf.d/99-network-performance.conf <<EOF
[Manager]
DefaultLimitNOFILE=1048576
DefaultLimitNPROC=65535
EOF

    cat > /etc/profile.d/99-network-performance.sh <<EOF
#!/bin/sh
ulimit -n 1048576 2>/dev/null || true
ulimit -u 65535 2>/dev/null || true
EOF
    chmod 644 /etc/profile.d/99-network-performance.sh

    if ! grep -q "network-performance limits" /etc/bash.bashrc 2>/dev/null; then
        cat >> /etc/bash.bashrc <<'EOF'
# BEGIN network-performance limits
if [ -n "${BASH_VERSION:-}" ]; then
    ulimit -n 1048576 2>/dev/null || true
    ulimit -u 65535 2>/dev/null || true
fi
# END network-performance limits
EOF
    fi

    systemctl daemon-reexec 2>/dev/null || true

    ulimit -Hn 1048576 2>/dev/null || true
    ulimit -Sn 1048576 2>/dev/null || true
    ulimit -Hu 65535 2>/dev/null || true
    ulimit -Su 65535 2>/dev/null || true

    declare -A params=(
        ["net.ipv4.conf.all.route_localnet"]="1"
        ["net.core.somaxconn"]="65535"
        ["net.core.netdev_max_backlog"]="65535"
        ["net.ipv4.tcp_max_syn_backlog"]="16384"
        ["net.ipv4.ip_local_port_range"]="1024 65535"
        ["net.ipv4.tcp_fastopen"]="3"
        ["net.ipv4.tcp_tw_reuse"]="1"
        ["net.ipv4.tcp_fin_timeout"]="15"
        ["net.ipv4.tcp_retries2"]="8"
        ["net.ipv4.ip_forward"]="1"
        ["net.ipv4.conf.all.forwarding"]="1"
        ["net.ipv4.conf.default.forwarding"]="1"
        ["net.ipv4.tcp_no_metrics_save"]="1"
        ["net.ipv4.tcp_congestion_control"]="lotspeed"
    )

    cp /etc/sysctl.conf /etc/sysctl.conf.bak

    for param in "${!params[@]}"; do
        value="${params[$param]}"
        escaped_param=$(printf '%s\n' "$param" | sed 's/[][\\/.^$*+?|(){}]/\\&/g')

        if grep -qE "^[[:space:]]*${escaped_param}[[:space:]]*=" /etc/sysctl.conf; then
            sed -i -E "s|^[[:space:]]*${escaped_param}[[:space:]]*=.*|$param = $value|" /etc/sysctl.conf
        else
            echo "$param = $value" >> /etc/sysctl.conf
        fi

        sysctl -w "$param=$value"
    done

    command -v iptables &>/dev/null || apt-get install -y iptables
    dpkg -l iptables-persistent 2>/dev/null | grep -q '^ii' || apt-get install -y iptables-persistent
    iptables -t mangle -D POSTROUTING -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || true
    iptables -t mangle -A POSTROUTING -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
    ip6tables -t mangle -D POSTROUTING -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || true
    ip6tables -t mangle -A POSTROUTING -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
    mkdir -p /etc/iptables
    iptables-save > /etc/iptables/rules.v4
    ip6tables-save > /etc/iptables/rules.v6

    if [ ! -f /etc/gai.conf ]; then
        cat > /etc/gai.conf <<EOF
label ::1/128       0
label ::/0          1
label 2002::/16     2
label ::/96         3
label ::ffff:0:0/96 4
precedence  ::1/128       50
precedence  ::/0          40
precedence  2002::/16     30
precedence  ::/96         20
precedence  ::ffff:0:0/96 10
EOF
    fi
    cp /etc/gai.conf /etc/gai.conf.bak
    grep -q '^precedence ::ffff:0:0/96  100' /etc/gai.conf 2>/dev/null || echo 'precedence ::ffff:0:0/96  100' >> /etc/gai.conf
}

optimize_nic_queue() {
    command -v ethtool &>/dev/null || { apt-get update && apt-get install -y ethtool; }
    interfaces=$(ls /sys/class/net | grep -vE 'lo|docker|veth|br-|any|tung3|sit0|tun|wg')
    cpu_count=$(nproc)
    rps_cpus=$(printf '%x' $(((1 << cpu_count) - 1)))
    for eth in $interfaces; do
        max_rx=$(ethtool -g "$eth" 2>/dev/null | grep -A 5 "Pre-set maximums" | grep "RX:" | awk '{print $2}')
        ethtool -G "$eth" rx "${max_rx:-1024}" tx "${max_rx:-1024}" &>/dev/null || true
        for rps_file in /sys/class/net/$eth/queues/rx-*/rps_cpus; do [ -f "$rps_file" ] && echo "$rps_cpus" >"$rps_file"; done
        for rfc_file in /sys/class/net/$eth/queues/rx-*/rps_flow_cnt; do [ -f "$rfc_file" ] && echo "4096" >"$rfc_file"; done
    done
    sysctl -w net.core.rps_sock_flow_entries=32768 &>/dev/null

    echo "net.core.rps_sock_flow_entries = 32768" > /etc/sysctl.d/99-nic-queue.conf

    cat > /usr/local/bin/nic-queue-optimize.sh <<EOF
#!/usr/bin/env bash
interfaces=\$(ls /sys/class/net | grep -vE 'lo|docker|veth|br-|any|tung3|sit0|tun|wg')
cpu_count=\$(nproc)
rps_cpus=\$(printf '%x' \$(((1 << cpu_count) - 1)))
for eth in \$interfaces; do
    max_rx=\$(ethtool -g "\$eth" 2>/dev/null | grep -A 5 "Pre-set maximums" | grep "RX:" | awk '{print \$2}')
    ethtool -G "\$eth" rx "\${max_rx:-1024}" tx "\${max_rx:-1024}" &>/dev/null || true
    for rps_file in /sys/class/net/\$eth/queues/rx-*/rps_cpus; do [ -f "\$rps_file" ] && echo "\$rps_cpus" >"\$rps_file"; done
    for rfc_file in /sys/class/net/\$eth/queues/rx-*/rps_flow_cnt; do [ -f "\$rfc_file" ] && echo "4096" >"\$rfc_file"; done
 done
EOF
    chmod +x /usr/local/bin/nic-queue-optimize.sh

    cat > /etc/systemd/system/nic-queue-optimize.service <<EOF
[Unit]
Description=Optimize NIC queue settings (ethtool + RPS)
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/nic-queue-optimize.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable nic-queue-optimize.service
}

uninstall_other_kernels() {
    LEVEL=$(get_cpu_level)

    if [ "$LEVEL" = "1" ]; then
        INSTALLED_KVER="6.4.10-x64v1-xanmod1"
    elif [ "$LEVEL" = "2" ]; then
        INSTALLED_KVER="6.4.10-x64v2-xanmod1"
    elif [ "$LEVEL" = "3" ]; then
        INSTALLED_KVER="6.4.10-x64v3-xanmod1"
    elif [ "$LEVEL" = "4" ]; then
        INSTALLED_KVER="6.4.10-x64v4-xanmod1"
    else
        exit 1
    fi

    dpkg --list | grep linux-image \
        | grep -v "$INSTALLED_KVER" \
        | awk '{print $2}' \
        | xargs --no-run-if-empty apt-get remove --purge -y

    dpkg --list | grep linux-headers \
        | grep -v "$INSTALLED_KVER" \
        | awk '{print $2}' \
        | xargs --no-run-if-empty apt-get remove --purge -y

    update-grub
    apt-get autoclean -y
}

uninstall_kernels_and_lotspeed() {
    uninstall_other_kernels

    command -v curl &>/dev/null || {
        apt-get update
        apt-get install -y curl
    }

    bash <(curl -sSL "$LOTSPEED_INSTALL_URL") -u
}

rollback_tcp_optimization() {
    if [ -f /etc/sysctl.conf.bak ]; then
        mv /etc/sysctl.conf.bak /etc/sysctl.conf
    fi

    rm -f /etc/security/limits.d/99-network-performance.conf \
        /etc/systemd/system.conf.d/99-network-performance.conf \
        /etc/systemd/user.conf.d/99-network-performance.conf \
        /etc/profile.d/99-network-performance.sh
    sed -i '/# BEGIN network-performance limits/,/# END network-performance limits/d' /etc/bash.bashrc 2>/dev/null || true
    systemctl daemon-reexec 2>/dev/null || true

    if [ -f /etc/gai.conf.bak ]; then
        mv /etc/gai.conf.bak /etc/gai.conf
    else
        sed -i 's/^precedence ::ffff:0:0\/96  100/#precedence ::ffff:0:0\/96  100/' /etc/gai.conf 2>/dev/null || true
    fi

    sysctl -w net.ipv4.tcp_congestion_control=cubic &>/dev/null
    sysctl -w net.core.default_qdisc=pfifo_fast &>/dev/null

    if command -v iptables &>/dev/null; then
        iptables -t mangle -D POSTROUTING -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || true
        ip6tables -t mangle -D POSTROUTING -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || true
    fi
    rm -f /etc/iptables/rules.v4 /etc/iptables/rules.v6

    ulimit -n 1024 2>/dev/null || true

    systemctl disable nic-queue-optimize.service 2>/dev/null || true
    rm -f /etc/systemd/system/nic-queue-optimize.service /usr/local/bin/nic-queue-optimize.sh /etc/sysctl.d/99-nic-queue.conf
    systemctl daemon-reload

    for eth in $(ls /sys/class/net | grep -vE 'lo|docker|veth|br-|any|tung3|sit0|tun|wg'); do
        for rps_file in /sys/class/net/$eth/queues/rx-*/rps_cpus; do [ -f "$rps_file" ] && echo "0" >"$rps_file"; done
    done
    sysctl -w net.core.rps_sock_flow_entries=0 &>/dev/null

    command -v curl &>/dev/null || {
        apt-get update
        apt-get install -y curl
    }

    bash <(curl -sSL "$LOTSPEED_INSTALL_URL") -u

    sysctl --system &>/dev/null
}

echo "1. Install xanmod kernel"
echo "2. Install lotspeed"
echo "3. Apply TCP optimization"
echo "4. Optimize NIC queue"
echo "5. Uninstall other kernel and lotspeed"
echo "6. Rollback TCP optimization and uninstall lotspeed cache"

read -p "Please select [1-6]: " num

case "$num" in
    1) install_xanmod_kernel ;;
    2) install_lotspeed ;;
    3) apply_tcp_optimization ;;
    4) optimize_nic_queue ;;
    5) uninstall_kernels_and_lotspeed ;;
    6) rollback_tcp_optimization ;;
    *) exit 1 ;;
esac