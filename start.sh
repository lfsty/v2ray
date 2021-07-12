#!/bin/bash
GREEN="32m"
BLUE="36m"
YELLOW="33m"
colorEcho(){
  echo -e "\033[${1}${2}\033[0m"
}

TAG="master"

ARGS=`getopt -o '' -a -l dev -- "$@"`
if [ $? != 0 ]; then
    echo "Terminating..."
    exit 1
fi
eval set -- "${ARGS}"
while true
do
    case "$1" in
        --dev)
            TAG="dev"
            shift
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Internal error!"
            exit 1
            ;;
    esac
done


echo "请选择安装选项:"
echo "1) Vmess"
echo "2) Vless+ws+TLS"
echo "3) 卸载"
read -p "请选择：" num

case ${num} in
    1)
        bash <(curl -s https://raw.githubusercontent.com/lfsty/v2ray/${TAG}/src/install_docker.sh)
        bash <(curl -s https://raw.githubusercontent.com/lfsty/v2ray/${TAG}/src/Vmess.sh)
        ;;
    2)
        bash <(curl -s https://raw.githubusercontent.com/lfsty/v2ray/${TAG}/src/install_docker.sh)
        bash <(curl -s https://raw.githubusercontent.com/lfsty/v2ray/${TAG}/src/Vless_ws_tls.sh)
        ;;
    3) 
        bash <(curl -s https://raw.githubusercontent.com/lfsty/v2ray/${TAG}/src/uninstall.sh)
        colorEcho ${GREEN} "卸载完成"
        ;;
    *)
        colorEcho ${YELLOW} "选择错误"
esac