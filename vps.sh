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

# ================== iptables转发管理 ==================
fwd_enabled() {
    [ "$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null)" = "1" ]
}

fwd_set_forward() {
    [ -f /etc/sysctl.conf ] || touch /etc/sysctl.conf
    sed -i '/net\.ipv4\.ip_forward/d' /etc/sysctl.conf
    echo "net.ipv4.ip_forward = $1" >> /etc/sysctl.conf
    sysctl -w net.ipv4.ip_forward="$1" >/dev/null
}

fwd_show_rules() {
    rules=$(iptables -t nat -nL PREROUTING --line-number 2>/dev/null | grep 'DNAT')
    if [ -z "$rules" ]; then
        echo "暂无转发规则"
    else
        echo "$rules"
    fi
}

fwd_add_rule() {
    proto="$1"
    read -p "请输入本机监听端口: " fwd_local
    read -p "请输入目标服务器IP: " fwd_ip
    read -p "请输入目标服务器端口: " fwd_port
    if ! [[ "$fwd_local" =~ ^[0-9]+$ ]] || ! [[ "$fwd_port" =~ ^[0-9]+$ ]] || ! [[ "$fwd_ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo "错误：输入无效！"
        return 1
    fi
    if [ "$proto" = "tcp" ] || [ "$proto" = "both" ]; then
        iptables -t nat -A PREROUTING -p tcp --dport "$fwd_local" -j DNAT --to-destination "$fwd_ip:$fwd_port" || { echo "错误：TCP规则添加失败"; return 1; }
        iptables -t nat -A POSTROUTING -p tcp -d "$fwd_ip" --dport "$fwd_port" -j MASQUERADE
    fi
    if [ "$proto" = "udp" ] || [ "$proto" = "both" ]; then
        iptables -t nat -A PREROUTING -p udp --dport "$fwd_local" -j DNAT --to-destination "$fwd_ip:$fwd_port" || { echo "错误：UDP规则添加失败"; return 1; }
        iptables -t nat -A POSTROUTING -p udp -d "$fwd_ip" --dport "$fwd_port" -j MASQUERADE
    fi
    echo "转发规则添加成功！"
}

fwd_del_rule() {
    proto="$1"
    if [ "$proto" = "tcp" ]; then
        rules=$(iptables -t nat -nL PREROUTING --line-number 2>/dev/null | grep 'DNAT' | grep ' tcp ')
    elif [ "$proto" = "udp" ]; then
        rules=$(iptables -t nat -nL PREROUTING --line-number 2>/dev/null | grep 'DNAT' | grep ' udp ')
    else
        rules=$(iptables -t nat -nL PREROUTING --line-number 2>/dev/null | grep 'DNAT')
    fi
    if [ -z "$rules" ]; then
        echo "暂无转发规则"
        return 1
    fi
    echo "当前转发规则："
    echo "$rules"
    echo "----------------------------------"
    read -p "请输入要删除的规则序号: " fwd_num
    if ! [[ "$fwd_num" =~ ^[0-9]+$ ]]; then
        echo "错误：输入无效！"
        return 1
    fi
    line=$(echo "$rules" | awk -v n="$fwd_num" '$1==n')
    if [ -z "$line" ]; then
        echo "错误：序号不存在！"
        return 1
    fi
    fwd_dest=$(echo "$line" | sed -n 's/.*to:\([0-9.]*\):\([0-9]*\).*/\1 \2/p')
    fwd_dport=$(echo "$line" | sed -n 's/.*dpt:\([0-9]*\).*/\1/p')
    if [ -z "$fwd_dest" ] || [ -z "$fwd_dport" ]; then
        echo "错误：规则解析失败！"
        return 1
    fi
    fwd_ip=$(echo "$fwd_dest" | awk '{print $1}')
    fwd_port=$(echo "$fwd_dest" | awk '{print $2}')
    if [ "$proto" = "tcp" ]; then
        iptables -t nat -D PREROUTING "$fwd_num"
        iptables -t nat -D POSTROUTING -p tcp -d "$fwd_ip" --dport "$fwd_port" -j MASQUERADE 2>/dev/null
    elif [ "$proto" = "udp" ]; then
        iptables -t nat -D PREROUTING "$fwd_num"
        iptables -t nat -D POSTROUTING -p udp -d "$fwd_ip" --dport "$fwd_port" -j MASQUERADE 2>/dev/null
    else
        iptables -t nat -D PREROUTING -p tcp --dport "$fwd_dport" -j DNAT --to-destination "$fwd_ip:$fwd_port" 2>/dev/null
        iptables -t nat -D PREROUTING -p udp --dport "$fwd_dport" -j DNAT --to-destination "$fwd_ip:$fwd_port" 2>/dev/null
        iptables -t nat -D POSTROUTING -p tcp -d "$fwd_ip" --dport "$fwd_port" -j MASQUERADE 2>/dev/null
        iptables -t nat -D POSTROUTING -p udp -d "$fwd_ip" --dport "$fwd_port" -j MASQUERADE 2>/dev/null
    fi
    echo "转发规则删除成功！"
}

iptables_menu() {
    while true; do
        clear
        echo "=================================="
        echo "        iptables转发管理          "
        echo "=================================="
        if fwd_enabled; then
            echo "当前IP转发状态：已开启"
        else
            echo "当前IP转发状态：已关闭"
        fi
        echo "=================================="
        echo "1. 开启/关闭转发功能"
        echo "2. 添加TCP转发规则"
        echo "3. 删除TCP转发规则"
        echo "4. 添加UDP转发规则"
        echo "5. 删除UDP转发规则"
        echo "6. 添加TCP+UDP转发规则"
        echo "7. 删除TCP+UDP转发规则"
        echo "8. 查看当前转发规则"
        echo "0. 返回上一级菜单"
        echo "=================================="
        read -p "请输入选项（0-8）: " fwd_input

        if ! [[ "$fwd_input" =~ ^[0-8]$ ]]; then
            echo ""
            echo "无效选项，请重新输入"
            sleep 1
            echo ""
            continue
        fi

        case "$fwd_input" in
            0)
                break
                ;;
            1)
                echo ""
                if fwd_enabled; then
                    fwd_set_forward 0
                    echo "转发功能已关闭！"
                else
                    fwd_set_forward 1
                    echo "转发功能已开启！"
                fi
                sleep 1
                ;;
            2)
                echo ""
                fwd_add_rule "tcp"
                wait_return
                ;;
            3)
                echo ""
                fwd_del_rule "tcp"
                wait_return
                ;;
            4)
                echo ""
                fwd_add_rule "udp"
                wait_return
                ;;
            5)
                echo ""
                fwd_del_rule "udp"
                wait_return
                ;;
            6)
                echo ""
                fwd_add_rule "both"
                wait_return
                ;;
            7)
                echo ""
                fwd_del_rule "both"
                wait_return
                ;;
            8)
                echo ""
                echo "当前转发规则："
                echo "----------------------------------"
                fwd_show_rules
                wait_return
                ;;
        esac
    done
}

# ================== acme.sh 申请证书 ==================
is_domain() {
    [[ "$1" =~ ^([A-Za-z0-9](-*[A-Za-z0-9])*\.)+(xn--[a-z0-9]{2,}|[A-Za-z]{2,})$ ]] && return 0 || return 1
}

# acme.sh 独立服务器默认绑定 IPv4；--listen-v6 会强制 IPv6，仅在主机无全局 IPv4 时使用
acme_listen_flag() {
    if ip -4 addr show scope global 2>/dev/null | grep -q "inet "; then
        echo ""
    else
        echo "--listen-v6"
    fi
}

acme_cert_issue() {
    local method="$1"

    # 检测/安装 acme.sh
    if ! command -v ~/.acme.sh/acme.sh &> /dev/null; then
        echo "未检测到 acme.sh，正在安装..."
        cd ~ || return 1
        curl -s https://get.acme.sh | sh
        if [ $? -ne 0 ]; then
            echo "错误：acme.sh 安装失败"
            wait_return
            return 1
        fi
        echo "acme.sh 安装成功"
    fi

    # 输入并校验域名
    local domain=""
    while true; do
        read -p "请输入您的域名: " domain
        domain="${domain// /}"
        if [ -z "$domain" ]; then
            echo "域名不能为空，请重新输入。"
            continue
        fi
        if ! is_domain "$domain"; then
            echo "域名格式无效: ${domain}，请输入有效域名。"
            continue
        fi
        break
    done
    echo "您的域名是: ${domain}，正在检查..."

    # 检测已有证书（仅复用文件完整且非空的证书，避免复用 0 字节证书）
    local cert_exists=0
    if ~/.acme.sh/acme.sh --list 2>/dev/null | awk '{print $1}' | grep -Fxq "${domain}"; then
        local acmeCertDir=""
        if [ -s ~/.acme.sh/${domain}_ecc/fullchain.cer ] && [ -s ~/.acme.sh/${domain}_ecc/${domain}.key ]; then
            acmeCertDir=~/.acme.sh/${domain}_ecc
        elif [ -s ~/.acme.sh/${domain}/fullchain.cer ] && [ -s ~/.acme.sh/${domain}/${domain}.key ]; then
            acmeCertDir=~/.acme.sh/${domain}
        fi
        if [ -n "${acmeCertDir}" ]; then
            cert_exists=1
            local certInfo=$(~/.acme.sh/acme.sh --list 2>/dev/null | grep -F "${domain}")
            echo "检测到 ${domain} 已有证书，将直接复用。"
            [ -n "${certInfo}" ] && echo "$certInfo"
        else
            echo "检测到 ${domain} 的 acme.sh 状态不完整（无有效证书文件），正在清理后重新签发。"
            rm -rf ~/.acme.sh/${domain} ~/.acme.sh/${domain}_ecc
        fi
    fi
    if [ ${cert_exists} -eq 0 ]; then
        echo "您的域名已准备就绪，开始签发证书..."
    fi

    # 创建证书存放目录
    local certPath="/root/cert/${domain}"
    if [ ! -d "$certPath" ]; then
        mkdir -p "$certPath"
    else
        rm -rf "$certPath"
        mkdir -p "$certPath"
    fi

    # ---- 不同验证方式的专用参数 ----
    local dns_alias=""
    local webroot=""
    local WebPort=80

    if [ "$method" = "dns" ]; then
        echo ""
        echo "请选择 DNS 服务商（用于 DNS-01 验证）："
        echo "1. Cloudflare (dns_cf)"
        echo "2. DNSPod 腾讯云 (dns_dp)"
        echo "3. 阿里云 (dns_ali)"
        echo "4. DigitalOcean (dns_do)"
        echo "5. Namesilo (dns_ns)"
        echo "6. 自定义（手动输入 dns 别名及环境变量）"
        read -p "请选择（1-6）: " dns_provider
        case "$dns_provider" in
            1)
                read -p "请输入 CF_Token: " CF_Token
                read -p "请输入 CF_Account_ID: " CF_Account_ID
                export CF_Token CF_Account_ID
                dns_alias="dns_cf"
                ;;
            2)
                read -p "请输入 DP_Id: " DP_Id
                read -p "请输入 DP_Key: " DP_Key
                export DP_Id DP_Key
                dns_alias="dns_dp"
                ;;
            3)
                read -p "请输入 Ali_Key: " Ali_Key
                read -p "请输入 Ali_Secret: " Ali_Secret
                export Ali_Key Ali_Secret
                dns_alias="dns_ali"
                ;;
            4)
                read -p "请输入 DO_API_KEY: " DO_API_KEY
                export DO_API_KEY
                dns_alias="dns_do"
                ;;
            5)
                read -p "请输入 Namesilo_Key: " Namesilo_Key
                export Namesilo_Key
                dns_alias="dns_ns"
                ;;
            *)
                read -p "请输入 acme.sh 的 dns 别名（如 dns_cf）: " dns_alias
                echo "请输入所需的环境变量（每行一个 export 语句，输入空行结束）："
                while read -r line; do
                    [ -z "$line" ] && break
                    eval "export $line"
                done
                ;;
        esac
        echo "使用 DNS 验证，服务商别名: ${dns_alias}"
    elif [ "$method" = "webroot" ]; then
        echo "反代验证需要某个 Web 服务器（如 nginx/apache）在 80 端口能访问该目录，"
        echo "用于把 3X-UI 面板反代到公网并签发证书的场景。"
        read -p "请输入反代服务器网站目录（webroot）路径，如 /var/www/html: " webroot
        [ -n "$webroot" ] && webroot="${webroot%/}"
        if [ -z "$webroot" ] || [ ! -d "$webroot" ]; then
            echo "错误：目录 ${webroot} 不存在或为空，无法进行反代文件验证。"
            wait_return
            return 1
        fi
        mkdir -p "$webroot/.well-known/acme-challenge"
        echo "使用反代文件验证，网站目录: ${webroot}"
    else
        read -p "请选择要使用的端口（默认 80）: " WebPort
        if [ -z "$WebPort" ]; then
            WebPort=80
        elif [[ ! "$WebPort" =~ ^[1-9][0-9]*$ || "$WebPort" -gt 65535 ]]; then
            echo "输入 ${WebPort} 无效，将使用默认端口 80。"
            WebPort=80
        fi
        echo "将使用端口: ${WebPort} 签发证书，请确保该端口已开放。"
        echo "正在临时停止面板（释放端口）..."
        systemctl stop x-ui 2>/dev/null || rc-service x-ui stop 2>/dev/null
    fi

    # ---- 按验证方式签发证书 ----
    if [ ${cert_exists} -eq 1 ]; then
        echo "使用已有证书，直接安装..."
    else
        echo "开始签发证书..."
        ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt --force >/dev/null 2>&1
        case "$method" in
            standalone)
                ~/.acme.sh/acme.sh --issue -d ${domain} $(acme_listen_flag) --standalone --httpport ${WebPort} --force
                ;;
            dns)
                ~/.acme.sh/acme.sh --issue -d ${domain} --dns ${dns_alias} --force
                ;;
            webroot)
                ~/.acme.sh/acme.sh --issue -d ${domain} --webroot "${webroot}" --force
                ;;
        esac
        if [ $? -ne 0 ]; then
            echo "错误：证书签发失败，请检查日志。"
            rm -rf ~/.acme.sh/${domain} ~/.acme.sh/${domain}_ecc
            systemctl start x-ui 2>/dev/null || rc-service x-ui start 2>/dev/null
            wait_return
            return 1
        fi
    fi

    # ============ 下发证书（移动证书）代码如下，保持不变 ============
    # 配置 reloadcmd
    local reloadCmd="systemctl restart x-ui || rc-service x-ui restart"
    echo "默认 --reloadcmd 为: ${reloadCmd}"
    echo "该命令会在每次签发/续期证书后执行。"
    read -p "是否修改 --reloadcmd ？(y/n): " setReloadcmd
    if [ "$setReloadcmd" = "y" ] || [ "$setReloadcmd" = "Y" ]; then
        echo ""
        echo "请选择："
        echo "1. 预设：systemctl reload nginx ; systemctl restart x-ui"
        echo "2. 自定义输入命令"
        echo "0. 保持默认 reloadcmd"
        read -p "请选择一项: " acme_rc_choice
        case "$acme_rc_choice" in
            1)
                echo "reloadcmd 为: systemctl reload nginx ; systemctl restart x-ui"
                reloadCmd="systemctl reload nginx ; systemctl restart x-ui"
                ;;
            2)
                echo "建议把 x-ui restart 放在最后"
                read -p "请输入自定义 reloadcmd: " reloadCmd
                echo "reloadcmd 为: ${reloadCmd}"
                ;;
            *)
                echo "保持默认 reloadcmd"
                ;;
        esac
    fi

    # 安装证书（移动证书到目标目录）
    local installOutput=""
    installOutput=$(~/.acme.sh/acme.sh --installcert --force -d ${domain} \
        --key-file ${certPath}/privkey.pem \
        --fullchain-file ${certPath}/fullchain.pem --reloadcmd "${reloadCmd}" 2>&1)
    local installRc=$?
    echo "${installOutput}"

    local installWroteFiles=0
    if echo "${installOutput}" | grep -q "Installing key to:" && echo "${installOutput}" | grep -q "Installing full chain to:"; then
        installWroteFiles=1
    fi

    if [ -f "${certPath}/privkey.pem" ] && [ -f "${certPath}/fullchain.pem" ] && { [ ${installRc} -eq 0 ] || [ ${installWroteFiles} -eq 1 ]; }; then
        echo "证书安装成功，正在启用自动续期..."
    else
        echo "错误：证书安装失败，退出。"
        if [ ${cert_exists} -eq 0 ]; then
            rm -rf ~/.acme.sh/${domain} ~/.acme.sh/${domain}_ecc
        fi
        systemctl start x-ui 2>/dev/null || rc-service x-ui start 2>/dev/null
        wait_return
        return 1
    fi

    # 启用自动续期
    ~/.acme.sh/acme.sh --upgrade --auto-upgrade >/dev/null 2>&1
    # 安全权限：私钥仅所有者可读
    echo "证书续期设置完成，证书详情："
    ls -lah ${certPath}
    chmod 600 ${certPath}/privkey.pem 2>/dev/null
    chmod 644 ${certPath}/fullchain.pem 2>/dev/null

    # 启动面板
    systemctl start x-ui 2>/dev/null || rc-service x-ui start 2>/dev/null

    # 询问是否为面板设置该证书
    read -p "是否将此证书设置为面板证书？(y/n): " setPanel
    if [ "$setPanel" = "y" ] || [ "$setPanel" = "Y" ]; then
        local webCertFile="${certPath}/fullchain.pem"
        local webKeyFile="${certPath}/privkey.pem"
        if [ -f "$webCertFile" ] && [ -f "$webKeyFile" ]; then
            if [ -x /usr/local/x-ui/x-ui ]; then
                /usr/local/x-ui/x-ui cert -webCert "$webCertFile" -webCertKey "$webKeyFile"
                echo "已为面板设置证书路径："
                echo "证书文件: $webCertFile"
                echo "私钥文件: $webKeyFile"
                echo "面板将重启以应用证书..."
                systemctl restart x-ui 2>/dev/null || rc-service x-ui restart 2>/dev/null
            else
                echo "未检测到 x-ui 面板，跳过面板证书设置（证书已保存到 ${certPath}）。"
            fi
        else
            echo "错误：未找到 ${domain} 的证书或私钥文件。"
        fi
    fi
    # ============ 下发证书（移动证书）代码到此结束 ============

    wait_return
}

acme_cert_menu() {
    while true; do
        clear
        echo "=================================="
        echo "          acme.sh申请证书          "
        echo "=================================="
        echo "1. 域名直接申请（HTTP-01 认证，占用80端口）"
        echo "2. DNS验证域名（DNS-01 认证）"
        echo "3. 反代验证域名（webroot，适用于 nginx/apache 反代 3X-UI）"
        echo "0. 返回上一级菜单"
        echo "=================================="
        read -p "请输入选项（0-3）: " acme_input

        if ! [[ "$acme_input" =~ ^[0-3]$ ]]; then
            echo ""
            echo "无效选项，请重新输入"
            sleep 1
            echo ""
            continue
        fi

        case "$acme_input" in
            0)
                break
                ;;
            1)
                echo ""
                acme_cert_issue "standalone"
                ;;
            2)
                echo ""
                acme_cert_issue "dns"
                ;;
            3)
                echo ""
                acme_cert_issue "webroot"
                ;;
        esac
    done
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
            while true; do
                clear
                echo "=================================="
                echo "          更多功能               "
                echo "=================================="
                echo "1. 第三方VPS工具脚本"
                echo "2. TcpQuality"
                echo "3. iptables转发管理"
                echo "16. acme.sh申请证书"
                echo "0. 返回主菜单"
                echo "=================================="
                read -p "请输入选项（0-3, 16）: " more_input

                if ! [[ "$more_input" =~ ^[0-9]+$ ]]; then
                    echo ""
                    echo "无效选项，请重新输入"
                    sleep 1
                    echo ""
                    continue
                fi

                case "$more_input" in
                    0)
                        break
                        ;;
                    1)
                        echo ""
                        echo "正在执行第三方VPS工具脚本..."
                        echo "----------------------------------"
                        bash <(curl -s https://raw.githubusercontent.com/everett7623/vps_scripts/main/vps_scripts.sh) || error_exit "第三方VPS工具脚本执行失败"
                        echo "----------------------------------"
                        echo "第三方VPS工具脚本执行完成！"
                        wait_return
                        break
                        ;;
                    2)
                        echo ""
                        echo "正在执行TcpQuality脚本..."
                        echo "----------------------------------"
                        bash <(curl -fsSL https://raw.githubusercontent.com/ibsgss/TcpQuality/main/runTcpQuality.sh) || error_exit "TcpQuality脚本执行失败"
                        echo "----------------------------------"
                        echo "TcpQuality脚本执行完成！"
                        wait_return
                        break
                        ;;
                    3)
                        echo ""
                        iptables_menu
                        ;;
                    16)
                        echo ""
                        acme_cert_menu
                        ;;
                    *)
                        echo ""
                        echo "无效选项，请重新输入"
                        sleep 1
                        echo ""
                        ;;
                esac
            done
            ;;
        *)
            echo ""
            echo "无效选项，请输入0-15或88"
            sleep 1
            echo ""
            ;;
    esac
done