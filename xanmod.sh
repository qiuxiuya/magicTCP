#!/usr/bin/env bash

BRANCH=""
VERSION=""

usage() {
    cat <<EOF
Usage: $0 -v <branch>

Options:
  -v    Branch directory (e.g. 6.4.10, lts_6.1.77, rt_6.1.73-rt22)
  -h    Show this help

Examples:
  $0 -v 6.4.10
  $0 -v lts_6.1.77
  $0 -v rt_6.1.73-rt22
EOF
    exit 1
}

while getopts "v:h" opt; do
    case "$opt" in
        v) BRANCH="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

if [ -z "$BRANCH" ]; then
    usage
fi

# Derive kernel version from branch: strip lts_ or rt_ prefix
VERSION="${BRANCH#lts_}"
VERSION="${VERSION#rt_}"

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
    apt-get install -y wget curl jq

    LEVEL=$(get_cpu_level)
    if [ -z "$LEVEL" ]; then
        echo "Failed to detect CPU microarchitecture level"
        exit 1
    fi

    KVER_DIR="${VERSION}-x64v${LEVEL}-xanmod1"
    DEB_PATH="xanmod/${BRANCH}/${KVER_DIR}"
    API_URL="https://api.github.com/repos/qiuxiuya/magicTCP/contents/${DEB_PATH}"

    FILE_LIST=$(curl -sSL "$API_URL")
    if [ $? -ne 0 ]; then
        echo "Failed to query GitHub API"
        echo "  branch: $BRANCH"
        echo "  version: $VERSION"
        echo "  path: $DEB_PATH"
        exit 1
    fi

    if echo "$FILE_LIST" | jq -e '.message' &>/dev/null; then
        echo "Path not found: $DEB_PATH"
        echo "  branch: $BRANCH"
        echo "  version: $VERSION"
        echo "  API response: $(echo "$FILE_LIST" | jq -r '.message')"
        echo ""
        echo "Available branches:"
        BRANCHES=$(curl -sSL "https://api.github.com/repos/qiuxiuya/magicTCP/contents/xanmod" 2>/dev/null)
        if [ -n "$BRANCHES" ] && ! echo "$BRANCHES" | jq -e '.message' &>/dev/null; then
            echo "$BRANCHES" | jq -r '.[] | select(.type == "dir") | "  " + .name'
        fi
        exit 1
    fi

    URLS=($(echo "$FILE_LIST" | jq -r '.[] | select(.name | endswith(".deb")) | .download_url'))
    if [ ${#URLS[@]} -eq 0 ]; then
        echo "No .deb files found in: $DEB_PATH"
        echo "  branch: $BRANCH"
        echo "  version: $VERSION"
        exit 1
    fi

    WORKDIR=$(mktemp -d)
    cd "$WORKDIR" || exit 1

    for url in "${URLS[@]}"; do
        filename=$(basename "$url")
        filename=$(printf '%b' "${filename//%/\\x}")
        filename="${filename%%\?*}"
        wget -q --show-progress "$url" -O "$filename"
        if [ $? -ne 0 ]; then
            echo "Download failed: $filename"
            cd /
            rm -rf "$WORKDIR"
            exit 1
        fi
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

apply_tcp_optimization() {
    mem_total_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    buf_bytes=$((mem_total_kb * 5 / 100 * 1024))

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
        ["net.core.default_qdisc"]="fq"
        ["net.ipv4.tcp_congestion_control"]="bbr"
        ["net.core.somaxconn"]="65535"
        ["net.core.netdev_max_backlog"]="65535"
        ["net.ipv4.tcp_max_syn_backlog"]="16384"
        ["net.ipv4.ip_local_port_range"]="1024 65535"
        ["net.core.rmem_max"]="$buf_bytes"
        ["net.core.wmem_max"]="$buf_bytes"
        ["net.ipv4.tcp_rmem"]="4096 87380 $buf_bytes"
        ["net.ipv4.tcp_wmem"]="4096 65536 $buf_bytes"
        ["net.core.rmem_default"]="2097152"
        ["net.core.wmem_default"]="2097152"
        ["net.ipv4.tcp_notsent_lowat"]="16384"
        ["net.ipv4.tcp_mtu_probing"]="1"
        ["net.ipv4.udp_rmem_min"]="16384"
        ["net.ipv4.udp_wmem_min"]="16384"
        ["net.ipv4.tcp_ecn"]="1"
        ["net.ipv4.tcp_max_orphans"]="32768"
        ["net.ipv4.tcp_slow_start_after_idle"]="0"
        ["net.ipv4.tcp_tw_reuse"]="1"
        ["net.ipv4.tcp_fin_timeout"]="15"
        ["net.ipv4.tcp_retries2"]="8"
        ["net.ipv4.tcp_fastopen"]="3"
        ["net.ipv4.tcp_adv_win_scale"]="-1"
        ["net.ipv4.tcp_window_scaling"]="1"
        ["net.ipv4.conf.all.route_localnet"]="1"
        ["net.ipv4.ip_forward"]="1"
        ["net.ipv4.conf.all.forwarding"]="1"
        ["net.ipv4.conf.default.forwarding"]="1"
        ["net.core.optmem_max"]="65535"
        ["net.ipv4.udp_mem"]="8192 262144 536870912"
    )

    cp /etc/sysctl.conf /etc/sysctl.conf.bak

    for param in "${!params[@]}"; do
        value="${params[$param]}"
        escaped_param=$(printf '%s\n' "$param" | sed 's/[][\/.^$*+?|(){}]/\\&/g')

        if grep -qE "^[[:space:]]*${escaped_param}[[:space:]]*=" /etc/sysctl.conf; then
            sed -i -E "s|^[[:space:]]*${escaped_param}[[:space:]]*=.*|$param = $value|" /etc/sysctl.conf
        else
            echo "$param = $value" >> /etc/sysctl.conf
        fi

        sysctl -w "$param=$value"
    done

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

uninstall_other_kernels() {
    LEVEL=$(get_cpu_level)
    [ -z "$LEVEL" ] && exit 1

    INSTALLED_KVER="${VERSION}-x64v${LEVEL}-xanmod1"

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

echo "1. Install xanmod kernel"
echo "2. Apply TCP optimization"
echo "3. Uninstall other kernel"

read -p "Please select [1-3]: " num

case "$num" in
    1) install_xanmod_kernel ;;
    2) apply_tcp_optimization ;;
    3) uninstall_other_kernels ;;
    *) exit 1 ;;
esac
