INSTALLED_KVER=""

install_xanmod_kernel() {
    apt update -y && apt install -y wget curl

    LEVEL=$(awk '
BEGIN {
    while (!/flags/) if (getline < "/proc/cpuinfo" != 1) exit 1
    if (/lm/&&/cmov/&&/cx8/&&/fpu/&&/fxsr/&&/mmx/&&/syscall/&&/sse2/) level = 1
    if (level == 1 && /cx16/&&/lahf/&&/popcnt/&&/sse4_1/&&/sse4_2/&&/ssse3/) level = 2
    if (level == 2 && /avx/&&/avx2/&&/bmi1/&&/bmi2/&&/f16c/&&/fma/&&/abm/&&/movbe/&&/xsave/) level = 3
    if (level == 3 && /avx512f/&&/avx512bw/&&/avx512cd/&&/avx512dq/&&/avx512vl/) level = 4
    if (level > 0) { print level; exit 0 }
    exit 1
}
')

    WORKDIR=$(mktemp -d)
    cd "$WORKDIR"

    if [ "$LEVEL" = "2" ]; then
        URLS=(
            "https://raw.githubusercontent.com/qiuxiuya/magicTCP/main/kernel/6.18.2-x64v2-xanmod/linux-image-6.18.2-x64v2-xanmod1_6.18.2-x64v2-xanmod1-0%7E20251218.g9f068d0_amd64.deb%3Fviasf%3D1"
            "https://raw.githubusercontent.com/qiuxiuya/magicTCP/main/kernel/6.18.2-x64v2-xanmod/linux-headers-6.18.2-x64v2-xanmod1_6.18.2-x64v2-xanmod1-0%7E20251218.g9f068d0_amd64.deb%3Fviasf%3D1"
            "https://raw.githubusercontent.com/qiuxiuya/magicTCP/main/kernel/6.18.2-x64v2-xanmod/linux-libc-dev_6.18.2-x64v2-xanmod1-0%7E20251218.g9f068d0_amd64.deb%3Fviasf%3D1"
        )
    elif [ "$LEVEL" = "3" ] || [ "$LEVEL" = "4" ]; then
        URLS=(
            "https://raw.githubusercontent.com/qiuxiuya/magicTCP/main/kernel/6.18.2-x64v3-xanmod/linux-image-6.18.2-x64v3-xanmod1_6.18.2-x64v3-xanmod1-0%7E20251218.g9f068d0_amd64.deb%3Fviasf%3D1"
            "https://raw.githubusercontent.com/qiuxiuya/magicTCP/main/kernel/6.18.2-x64v3-xanmod/linux-headers-6.18.2-x64v3-xanmod1_6.18.2-x64v3-xanmod1-0%7E20251218.g9f068d0_amd64.deb%3Fviasf%3D1"
            "https://raw.githubusercontent.com/qiuxiuya/magicTCP/main/kernel/6.18.2-x64v3-xanmod/linux-libc-dev_6.18.2-x64v3-xanmod1-0%7E20251218.g9f068d0_amd64.deb%3Fviasf%3D1"
        )
    else
        echo "CPU x86-64-v$LEVEL not supported"
        exit 1
    fi

    echo "Downloading kernel packages for x86-64-v$LEVEL ..."
    i=0
    for url in "${URLS[@]}"; do
        i=$((i + 1))
        echo "  -> Downloading file $i ..."
        wget -q --show-progress "$url" -O "${i}.deb"
        if [ $? -ne 0 ]; then
            echo "Download failed: $url"
            exit 1
        fi
    done

    echo "Installing..."
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
    bash <(curl -fsSL https://raw.githubusercontent.com/qiuxiuya/lotspeed/zeta-tcp/install.sh)
}

apply_tcp_optimization() {
    declare -A params=(
        ["net.ipv4.conf.all.route_localnet"]="1"
        ["net.ipv4.ip_forward"]="1"
        ["net.ipv4.conf.all.forwarding"]="1"
        ["net.ipv4.conf.default.forwarding"]="1"
        ["net.ipv4.udp_rmem_min"]="16384"
        ["net.ipv4.udp_wmem_min"]="16384"
        ["net.core.netdev_max_backlog"]="30000"
        ["net.ipv4.udp_mem"]="8192 262144 536870912"
        ["net.core.default_qdisc"]="fq"
    )

    cp /etc/sysctl.conf /etc/sysctl.conf.bak

    for param in "${!params[@]}"; do
        value="${params[$param]}"
        if grep -q "^$param" /etc/sysctl.conf; then
            sed -i "s|^$param.*|$param = $value|" /etc/sysctl.conf
        else
            echo "$param = $value" >> /etc/sysctl.conf
        fi
        sysctl -w "$param=$value"
    done

    grep -q '^precedence ::ffff:0:0/96  100' /etc/gai.conf || echo 'precedence ::ffff:0:0/96  100' >> /etc/gai.conf
}

uninstall_other_kernels() {
    LEVEL=$(awk '
BEGIN {
    while (!/flags/) if (getline < "/proc/cpuinfo" != 1) exit 1
    if (/lm/&&/cmov/&&/cx8/&&/fpu/&&/fxsr/&&/mmx/&&/syscall/&&/sse2/) level = 1
    if (level == 1 && /cx16/&&/lahf/&&/popcnt/&&/sse4_1/&&/sse4_2/&&/ssse3/) level = 2
    if (level == 2 && /avx/&&/avx2/&&/bmi1/&&/bmi2/&&/f16c/&&/fma/&&/abm/&&/movbe/&&/xsave/) level = 3
    if (level == 3 && /avx512f/&&/avx512bw/&&/avx512cd/&&/avx512dq/&&/avx512vl/) level = 4
    if (level > 0) { print level; exit 0 }
    exit 1
}
')

    if [ "$LEVEL" = "2" ]; then
        INSTALLED_KVER="6.18.2-x64v2-xanmod1"
    elif [ "$LEVEL" = "3" ] || [ "$LEVEL" = "4" ]; then
        INSTALLED_KVER="6.18.2-x64v3-xanmod1"
    else
        echo "Unable to detect CPU level, aborting uninstall."
        exit 1
    fi

    echo "Keeping kernel: $INSTALLED_KVER"
    echo "Removing all other kernels..."

    dpkg --list | grep linux-image \
        | grep -v "$INSTALLED_KVER" \
        | awk '{print $2}' \
        | xargs --no-run-if-empty apt-get remove --purge -y

    dpkg --list | grep linux-headers \
        | grep -v "$INSTALLED_KVER" \
        | awk '{print $2}' \
        | xargs --no-run-if-empty apt-get remove --purge -y

    update-grub

    bash <(curl -fsSL https://raw.githubusercontent.com/qiuxiuya/lotspeed/zeta-tcp/install.sh) -u
    apt-get autoclean -y

    echo "Done. Only $INSTALLED_KVER is retained."
}

echo "1. Install xanmod kernel"
echo "2. Install lotspeed"
echo "3. Apply TCP optimization"
echo "4. Uninstall other kernel"

read -p "Please select [1-4]: " num
case "$num" in
1)
    install_xanmod_kernel
    ;;
2)
    install_lotspeed
    ;;
3)
    apply_tcp_optimization
    ;;
4)
    uninstall_other_kernels
    ;;
*)
    clear
    echo "Invalid selection. Please choose 1, 2, 3, or 4."
    exit 1
    ;;
esac
