#!/bin/bash

echo "请选择安装选项:"
echo "1) Vmess"
echo "2) Vless+ws+TLS"
echo "3) 卸载"
read -p "请选择：" num

case ${num} in
    1)
        bash <(curl -s https://raw.githubusercontent.com/lfsty/v2ray/master/src/install_docker.sh)
        bash <(curl -s https://raw.githubusercontent.com/lfsty/v2ray/master/src/Vmess.sh)
        ;;
    2)
        bash <(curl -s https://raw.githubusercontent.com/lfsty/v2ray/master/src/install_docker.sh)
        bash <(curl -s https://raw.githubusercontent.com/lfsty/v2ray/master/src/Vless_ws_tls.sh)
        ;;
    3) 
        bash <(curl -s https://raw.githubusercontent.com/lfsty/v2ray/master/src/uninstall.sh)
        colorEcho ${GREEN} "卸载完成"
        ;;
    *)
        colorEcho ${YELLOW} "选择错误"
esac