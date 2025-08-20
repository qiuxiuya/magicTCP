#!/bin/bash

echo """\
                         __                    
   ____  ___  _  _______/ /_____  _________ ___ 
  / __ \/ _ \| |/_/ ___/ __/ __ \/ ___/ __ \__ \
 / / / /  __/>  <(__  ) /_/ /_/ / /  / / / / / /
/_/ /_/\___/_/|_/____/\__/\____/_/  /_/ /_/ /_/ 
_________________________________________________
        magicTCP v0.1 | 20/08/2025 edition

"""

install_magictcp_kernel() {
    magictcp_kernel_version="6.1.55-magictcp001"
    apt install -y wget
    wget "https://raw.githubusercontent.com/qiuxiuya/magicTCP/main/kernel/linux-headers-${magictcp_kernel_version}_${magictcp_kernel_version}-4_amd64.deb" -O "linux-headers-${magictcp_kernel_version}.deb"
    wget "https://raw.githubusercontent.com/qiuxiuya/magicTCP/main/kernel/linux-image-${magictcp_kernel_version}_${magictcp_kernel_version}-4_amd64.deb" -O "linux-image-${magictcp_kernel_version}.deb"
    dpkg -i "linux-headers-${magictcp_kernel_version}.deb"
    dpkg -i "linux-image-${magictcp_kernel_version}.deb"
    rm -rf "linux-headers-${magictcp_kernel_version}.deb"
    rm -rf "linux-image-${magictcp_kernel_version}.deb"

    update-initramfs -c -k ${magictcp_kernel_version}
    update-grub
    reboot
}

apply_tcp_optimization() {
    declare -A params=(
        ["net.core.rmem_max"]="67108864"
        ["net.core.wmem_max"]="67108864"
        ["net.ipv4.tcp_rmem"]="4096 87380 67108864"
        ["net.ipv4.tcp_wmem"]="4096 65536 67108864"
        ["net.core.optmem_max"]="65536"
        ["net.ipv4.tcp_mtu_probing"]="1"
        ["net.ipv4.tcp_slow_start_after_idle"]="0"
        ["net.ipv4.tcp_fastopen"]="3"
        ["net.ipv4.tcp_window_scaling"]="1"
        ["net.ipv4.tcp_timestamps"]="1"
        ["net.ipv4.tcp_sack"]="1"
        ["net.ipv4.tcp_no_metrics_save"]="1"
        ["net.ipv4.tcp_low_latency"]="1"
        ["net.ipv4.tcp_adv_win_scale"]="-2"
        ["net.core.netdev_max_backlog"]="16384"
        ["net.ipv4.tcp_max_syn_backlog"]="8192"
        ["net.ipv4.tcp_fin_timeout"]="10"
        ["net.ipv4.tcp_tw_reuse"]="1"
        ["net.ipv4.tcp_tw_recycle"]="0"
        ["net.ipv4.udp_rmem_min"]="4096"
        ["net.ipv4.udp_wmem_min"]="4096"
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
    sudo dpkg --list | grep linux-image | grep -v 'magic' | awk '{print $2}' | xargs sudo apt-get remove --purge -y
    sudo update-grub
}

echo "1. Install magicTCP kernel"
echo "2. Apply TCP optimization"
echo "3. Uninstall other kernel"

read -p "Please select :" num
case "$num" in
    1)
        install_magictcp_kernel
        ;;
    2)
        apply_tcp_optimization
        ;;
    3)
        uninstall_other_kernels
        ;;
    *)
        clear
        echo -e "${Error}:Please select a valid option [1, 2, 3]"
        exit 1
        ;;
esac
