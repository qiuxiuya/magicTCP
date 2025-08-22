#!/bin/bash

echo """\
                         __                    
   ____  ___  _  _______/ /_____  _________ ___ 
  / __ \/ _ \| |/_/ ___/ __/ __ \/ ___/ __ \__ \\
 / / / /  __/>  <(__  ) /_/ /_/ / /  / / / / / /
/_/ /_/\___/_/|_/____/\__/\____/_/  /_/ /_/ /_/ 
_________________________________________________
        magicTCP v0.1 | 12/06/2025 edition

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
        ["net.ipv4.tcp_rmem"]="8192 262144 536870912"
        ["net.ipv4.tcp_wmem"]="8192 262144 536870912"
        ["net.ipv4.tcp_collapse_max_bytes"]="6291456"
        ["net.ipv4.tcp_notsent_lowat"]="131072"
        ["net.ipv4.tcp_adv_win_scale"]="1"
        ["net.core.default_qdisc"]="fq"
        ["net.ipv4.tcp_congestion_control"]="bbr"
        ["net.ipv4.tcp_window_scaling"]="1"
        ["net.ipv4.conf.all.route_localnet"]="1"
        ["net.ipv4.ip_forward"]="1"
        ["net.ipv4.conf.all.forwarding"]="1"
        ["net.ipv4.conf.default.forwarding"]="1"
        ["net.ipv4.udp_rmem_min"]="16384"
        ["net.ipv4.udp_wmem_min"]="16384"
        ["net.core.rmem_default"]="262144"
        ["net.core.rmem_max"]="2621440"
        ["net.core.wmem_default"]="262144"
        ["net.core.wmem_max"]="2621440"
        ["net.core.optmem_max"]="65535"
        ["net.ipv4.udp_mem"]="8192 262144 524288"
        ["net.core.netdev_max_backlog"]="30000"
        ["net.ipv4.tcp_fastopen"]="3"
        ["net.ipv4.tcp_mtu_probing"]="1"
        ["net.ipv4.tcp_mem"]="786432 1048576 26777216"
        ["net.ipv4.tcp_tw_reuse"]="1"
        ["net.ipv4.tcp_fin_timeout"]="15"
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
