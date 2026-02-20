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
        KERNEL_PATH="kernel/x64v2"
    elif [ "$LEVEL" = "3" ] || [ "$LEVEL" = "4" ]; then
        KERNEL_PATH="kernel/x64v3"
    else
        echo "CPU x86-64-v$LEVEL not support"
        exit 1
    fi

    API_URL="https://api.github.com/repos/qiuxiuya/magicTCP/contents/$KERNEL_PATH"
    
    DOWNLOAD_URLS=$(curl -s "$API_URL" | grep "download_url" | grep ".deb" | cut -d '"' -f 4)
    
    if [ -z "$DOWNLOAD_URLS" ]; then
        echo "Failed to fetch kernel files."
        exit 1
    fi

    for u in $DOWNLOAD_URLS; do
        wget -q "$u"
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
    declare -A params=(
        ["net.ipv4.tcp_congestion_control"]="bbr"
        ["net.core.default_qdisc"]="fq"
        ["net.ipv4.tcp_fastopen"]="3"
    )

    cp /etc/sysctl.conf /etc/sysctl.conf.bak

    for param in "${!params[@]}"; do
        value="${params[$param]}"
        if grep "^$param" /etc/sysctl.conf; then
            sed -i "s|^$param.*|$param = $value|" /etc/sysctl.conf
        else
            echo "$param = $value" >> /etc/sysctl.conf
        fi
        sysctl -w "$param=$value"
    done

    grep '^precedence ::ffff:0:0/96  100' /etc/gai.conf || echo 'precedence ::ffff:0:0/96  100' >> /etc/gai.conf
}

uninstall_other_kernels() {
    dpkg --list | grep linux-image | grep -v 'xanmod' | awk '{print $2}' | xargs apt-get remove --purge -y
    update-grub
}

echo "1. Install xanmod kernel"
echo "2. Apply TCP optimization"
echo "3. Uninstall other kernel"

read -p "Please select [1-3]: " num
case "$num" in
1)
    install_xanmod_kernel
    ;;
2)
    apply_tcp_optimization
    ;;
3)
    uninstall_other_kernels
    ;;
*)
    clear
    echo "Invalid selection. Please choose 1, 2, or 3."
    exit 1
    ;;
esac
