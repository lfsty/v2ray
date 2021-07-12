#!/bin/bash
GREEN="32m"
BLUE="36m"
YELLOW="33m"
colorEcho(){
  echo -e "\033[${1}${2}\033[0m"
}

#配置目录
ROOT="/var/lfsty"
#端口号
PORT=$(shuf -i 10000-65000 -n 1)
#uuid
UUID=$(cat /proc/sys/kernel/random/uuid)
#本机ip
LOCAL_IP=$(curl -sSL -4 icanhazip.com)



createDir(){
  if [ ! -d "${ROOT}"  ];then
    mkdir -p "${ROOT}"
  fi
  if [ ! -d "${ROOT}/v2ray"  ];then
    mkdir -p "${ROOT}/v2ray"
  fi
}

genVmessConfig(){ 
    cat > "${ROOT}/v2ray/config.json" <<-EOF
{
  "log":{
    "loglevel":"info",
    "access":"/var/log/v2ray/access.log"
  },
  "inbounds": [{
    "port": ${PORT},
    "protocol": "vmess",
    "settings": {
      "clients": [
        {
          "id": "${UUID}",
          "level": 1,
          "alterId": 64
        }
      ]
    }
  }
  ],
  "outbounds": [{
    "protocol": "freedom",
    "settings": {}
  },{
    "protocol": "blackhole",
    "settings": {},
    "tag": "blocked"
  }],
  "routing": {
    "rules": [
      {
        "type": "field",
        "ip": ["geoip:private"],
        "outboundTag": "blocked"
      }
    ]
  }
}
EOF
}

genVmessDockerComposeConfig(){
    cat > "${ROOT}/docker-compose.yml" <<-EOF
version: '2.4'
services: 
    v2ray:
        image: teddysun/v2ray
        container_name: v2ray
        ports:  
            - ${PORT}:${PORT}
        volumes: 
            - ${ROOT}/v2ray/config.json:/etc/v2ray/config.json
        restart: always
        networks: 
            proxy_net:

networks: 
    proxy_net:
        driver: bridge
        enable_ipv6: true
        ipam: 
          driver: default
          config: 
              - subnet: fe10::/120
                gateway: fe10::1
EOF
}

genVmessUrl(){
    cat > ./vmess.json <<-EOF
{
  "v": "2",
  "ps": "${LOCAL_IP}",
  "add": "${LOCAL_IP}",
  "port": "${PORT}",
  "id": "${UUID}",
  "aid": "64",
  "net": "tcp",
  "type": "none",
  "host": "",
  "path": "",
  "tls": ""
}
EOF
    vmess="vmess://$(cat vmess.json | base64 -w 0)"
    rm -rf vmess.json

    colorEcho ${GREEN}  "Vmess安装成功，相关配置如下："
    colorEcho ${BLUE} "协议:VMESS"
    colorEcho ${BLUE} "IP(address):${LOCAL_IP}"
    colorEcho ${BLUE} "端口(port):${PORT}"
    colorEcho ${BLUE} "id(uuid):${UUID}"

    colorEcho ${GREEN}  "您的vmess链接为："
    colorEcho ${BLUE} ${vmess}
}

ARGS=`getopt -o o:p:u: -- "$@"`
if [ $? != 0 ]; then
    echo "Terminating..."
    exit 1
fi

eval set -- "${ARGS}"
while true
do
    case "$1" in
        -o)
            ROOT=$2
            shift 2
            ;;
        -p)
            PORT=$2
            shift 2
            ;;
        -u)
            UUID=$2
            shift 2
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


createDir
genVmessConfig
genVmessDockerComposeConfig
docker-compose -f ${ROOT}/docker-compose.yml up -d
genVmessUrl