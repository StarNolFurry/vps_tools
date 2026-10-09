#!/bin/bash

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "错误：需要以root用户运行此脚本"
        echo "请使用 sudo -i 切换到root用户后再运行"
        exit 1
    fi
}

wait_return() {
    echo ""
    read -n 1 -s -p "按任意键返回主菜单..."
    echo ""
    echo ""
}

error_exit() {
    echo "错误：$1"
    wait_return
}

check_root

while true; do
    clear
    echo "=================================="
    echo "          星诺常用VPS脚本          "
    echo "=================================="
    echo "1. 回程线路测试"
    echo "2. 使用SpeedTest Akile测速"
    echo "3. 融合怪测试脚本"
    echo "4. NodeQuality测试"
    echo "----------------------------------"
    echo "5. Akile DNS修改"
    echo "6. IP-Sentinel 送中回送"
    echo "----------------------------------"
    echo "7. 安装3X-UI面板"
    echo "8. 升级3X-UI面板"
    echo "9. 安装S-UI面板"
    echo "10. 升级S-UI面板"
    echo "11. Realm转发面板"
    echo "12. 懒人一键Sing-Box"
    echo "----------------------------------"
    echo "13. Argo隧道脚本"
    echo "14. 网络重装系统"
    echo "15. BBR加速"
    echo "88. 更多功能"
    echo "----------------------------------"
    echo "0. 退出脚本"
    echo "=================================="
    echo ""
    read -p "请输入选项（0-15, 88）: " input

    if ! [[ "$input" =~ ^[0-9]+$ ]]; then
        echo ""
        echo "无效输入！请输入数字"
        sleep 1
        echo ""
        continue
    fi

    case "$input" in
        0)
            echo ""
            echo "感谢使用！脚本已退出。"
            exit 0
            ;;
        1)
            echo ""
            echo "正在下载回程线路测试脚本..."
            echo "----------------------------------"
            curl https://raw.githubusercontent.com/ludashi2020/backtrace/main/install.sh -sSf | sh || error_exit "回程线路测试脚本执行失败"
            echo "----------------------------------"
            echo "测试完成！"
            wait_return
            ;;
        2)
            echo ""
            echo "正在下载并安装SpeedTest..."
            echo "----------------------------------"
            curl -sL https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-x86_64.tgz | tar -xz && rm -f speedtest.* && mv ./speedtest /usr/local/bin/speedtest && speedtest -s 74653 || error_exit "SpeedTest安装或执行失败"
            echo "----------------------------------"
            echo "测速完成！"
            wait_return
            ;;
        3)
            echo ""
            echo "正在下载并执行融合怪测试脚本..."
            echo "----------------------------------"
            curl -L https://gitlab.com/spiritysdx/za/-/raw/main/ecs.sh -o ecs.sh && chmod +x ecs.sh && bash ecs.sh || error_exit "融合怪测试脚本执行失败"
            echo "----------------------------------"
            wait_return
            ;;
        4)
            echo ""
            echo "正在执行NodeQuality测试..."
            echo "----------------------------------"
            bash <(curl -sL https://raw.githubusercontent.com/ssrsub/nodequality/main/nq.sh) || error_exit "NodeQuality测试执行失败"
            echo "----------------------------------"
            echo "NodeQuality测试完成！"
            wait_return
            ;;
        5)
            echo ""
            echo "正在执行Akile DNS修改脚本..."
            echo "----------------------------------"
            wget -qO- https://raw.githubusercontent.com/akile-network/aktools/refs/heads/main/akdns.sh | bash || error_exit "DNS修改失败"
            echo "----------------------------------"
            echo "DNS修改完成！"
            wait_return
            ;;
        6)
            echo ""
            echo "正在安装 IP-Sentinel 送中回送..."
            echo "----------------------------------"
            curl -fsSL https://raw.githubusercontent.com/hotyue/IP-Sentinel/main/core/install.sh -o /tmp/ins_agent.sh && bash /tmp/ins_agent.sh || error_exit "IP-Sentinel安装失败"
            echo "----------------------------------"
            echo "IP-Sentinel安装完成！"
            wait_return
            ;;
        7)
            echo ""
            echo "正在安装3X-UI面板..."
            echo "----------------------------------"
            bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh) || error_exit "3X-UI面板安装失败"
            echo "----------------------------------"
            echo "3X-UI面板安装完成！"
            wait_return
            ;;
        8)
            echo ""
            echo "正在检测3X-UI面板安装状态..."
            echo "----------------------------------"
            if [ -d "/etc/x-ui" ] || systemctl is-active --quiet x-ui 2>/dev/null; then
                echo "检测到3X-UI面板已安装，正在升级..."
                bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh) --upgrade || error_exit "3X-UI面板升级失败"
                echo "----------------------------------"
                echo "3X-UI面板升级完成！"
            else
                echo "未检测到3X-UI面板，请先安装后再升级"
                echo "----------------------------------"
            fi
            wait_return
            ;;
        9)
            echo ""
            echo "正在安装S-UI面板..."
            echo "----------------------------------"
            bash <(curl -Ls https://raw.githubusercontent.com/alireza0/s-ui/master/install.sh) || error_exit "S-UI面板安装失败"
            echo "----------------------------------"
            echo "S-UI面板安装完成！"
            wait_return
            ;;
        10)
            echo ""
            echo "正在检测S-UI面板安装状态..."
            echo "----------------------------------"
            if [ -d "/etc/s-ui" ] || systemctl is-active --quiet s-ui 2>/dev/null; then
                echo "检测到S-UI面板已安装，正在升级..."
                bash <(curl -Ls https://raw.githubusercontent.com/alireza0/s-ui/master/install.sh) --upgrade || error_exit "S-UI面板升级失败"
                echo "----------------------------------"
                echo "S-UI面板升级完成！"
            else
                echo "未检测到S-UI面板，请先安装后再升级"
                echo "----------------------------------"
            fi
            wait_return
            ;;
        11)
            while true; do
                clear
                echo "=================================="
                echo "          Realm转发面板           "
                echo "=================================="
                echo "1. 海外线路"
                echo "2. 国内线路"
                echo "0. 返回主菜单"
                echo "=================================="
                read -p "请选择下载源（0-2）: " realm_input

                if ! [[ "$realm_input" =~ ^[0-2]$ ]]; then
                    echo ""
                    echo "无效选项，请重新输入"
                    sleep 1
                    echo ""
                    continue
                fi

                case "$realm_input" in
                    0)
                        break
                        ;;
                    1)
                        echo ""
                        echo "正在从GitHub下载..."
                        echo "----------------------------------"
                        curl -L https://github.com/wcwq98/realm/releases/download/v3.1.21/realm.sh -o realm.sh && chmod +x realm.sh && ./realm.sh || error_exit "Realm安装失败"
                        echo "----------------------------------"
                        echo "Realm安装完成！"
                        wait_return
                        break
                        ;;
                    2)
                        echo ""
                        echo "正在从国内源下载..."
                        echo "----------------------------------"
                        curl -L https://host.wxgwxha.eu.org/https://github.com/wcwq98/realm/releases/download/v3.1.2/realm.sh -o realm.sh && chmod +x realm.sh && ./realm.sh || error_exit "Realm安装失败"
                        echo "----------------------------------"
                        echo "Realm安装完成！"
                        wait_return
                        break
                        ;;
                esac
            done
            ;;
        12)
            echo ""
            echo "正在执行懒人一键Sing-Box脚本..."
            echo "----------------------------------"
            bash <(curl -s https://raw.githubusercontent.com/fscarmen/sing-box/main/sing-box.sh) || error_exit "Sing-Box安装失败"
            echo "----------------------------------"
            echo "Sing-Box安装完成！"
            wait_return
            ;;
        13)
            echo ""
            echo "正在执行Argo隧道脚本..."
            echo "----------------------------------"
            bash <(curl -Ls https://raw.githubusercontent.com/amclubs/am-serv00-vmess/main/install-argo.sh) || error_exit "Argo隧道脚本执行失败"
            echo "----------------------------------"
            echo "Argo隧道脚本执行完成！"
            wait_return
            ;;
        14)
            echo ""
            echo "正在执行网络重装系统脚本..."
            echo "----------------------------------"
            wget -N --no-check-certificate https://down.vpsaff.net/linux/dd/network-reinstall-os.sh && chmod +x network-reinstall-os.sh && ./network-reinstall-os.sh || error_exit "网络重装系统脚本执行失败"
            echo "----------------------------------"
            echo "网络重装系统脚本执行完成！"
            wait_return
            ;;
        15)
            while true; do
                clear
                echo "=================================="
                echo "          BBR加速管理            "
                echo "=================================="
                echo "1. BBR加速脚本"
                echo "2. BBR-V3脚本"
                echo "3. TCP调优"
                echo "0. 返回主菜单"
                echo "=================================="
                read -p "请输入选项（0-3）: " bbr_input

                if ! [[ "$bbr_input" =~ ^[0-3]$ ]]; then
                    echo ""
                    echo "无效选项，请重新输入"
                    sleep 1
                    echo ""
                    continue
                fi

                case "$bbr_input" in
                    0)
                        break
                        ;;
                    1)
                        echo ""
                        echo "正在执行BBR加速脚本..."
                        echo "----------------------------------"
                        bash <(curl -fsSL https://vpszdm.com/bbr.sh) || error_exit "BBR加速脚本执行失败"
                        echo "----------------------------------"
                        echo "BBR加速脚本执行完成！"
                        wait_return
                        break
                        ;;
                    2)
                        echo ""
                        echo "正在执行BBR-V3脚本..."
                        echo "----------------------------------"
                        bash <(curl -fsSL https://raw.githubusercontent.com/byJoey/Actions-bbr-v3/main/install.sh) || error_exit "BBR-V3脚本执行失败"
                        echo "----------------------------------"
                        echo "BBR-V3脚本执行完成！"
                        wait_return
                        break
                        ;;
                    3)
                        echo ""
                        echo "正在执行TCP调优脚本..."
                        echo "----------------------------------"
                        bash <(curl -fsSL https://raw.githubusercontent.com/Kylin010/tcpfit/main/tcpfit.sh) || error_exit "TCP调优脚本执行失败"
                        echo "----------------------------------"
                        echo "TCP调优脚本执行完成！"
                        wait_return
                        break
                        ;;
                esac
            done
            ;;
        88)
            echo ""
            echo "正在执行更多功能脚本..."
            echo "----------------------------------"
            bash <(curl -s https://raw.githubusercontent.com/everett7623/vps_scripts/main/vps_scripts.sh) || error_exit "更多功能脚本执行失败"
            echo "----------------------------------"
            echo "脚本执行完成！"
            wait_return
            ;;
        *)
            echo ""
            echo "无效选项，请输入0-15或88"
            sleep 1
            echo ""
            ;;
    esac
done