#!/bin/bash
GREEN="32m"
BLUE="36m"
YELLOW="33m"
colorEcho(){
  echo -e "\033[${1}${2}\033[0m"
}

#本机ip
LOCAL_IP=$(curl -4 icanhazip.com)
#端口号
PORT=$(shuf -i 10000-65000 -n 1)
#uuid
UUID=$(cat /proc/sys/kernel/random/uuid)
#配置文件存放路径
ROOT="/var/lfsty"

genVlessConfig(){
    if [ ! -d "${ROOT}/v2ray"  ];then
        mkdir "${ROOT}/v2ray"
    fi
    cat > "${ROOT}/v2ray/config.json" <<-EOF
{
  "inbounds": [{
    "port": ${PORT},
    "protocol": "vless",
    "settings": {
        "clients": [
            {
                "id": "${UUID}",
                "level": 0
            }
        ],
        "decryption": "none"
    },
    "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
            "path": "${WS_PATH}",
            "headers": {
                "Host": "${DOMAIN}"
            }
        }
    }
  }],
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



#生成nginx配置文件
genNginxConfig(){
    if [ ! -d "${ROOT}/nginx"  ];then
            mkdir "${ROOT}/nginx"
    fi

    cat > "${ROOT}/nginx/nginx.conf" <<-EOF
user  nginx;
worker_processes  1;
error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;
events {
    worker_connections  1024;
}
http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                    '\$status $body_bytes_sent "\$http_referer" '
                    '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;
    sendfile        on;

    keepalive_timeout  65;
    fastcgi_intercept_errors on;
    include /etc/nginx/conf.d/*.conf;
}
EOF

    if [ ! -d "${ROOT}/nginx/conf.d"  ];then
            mkdir "${ROOT}/nginx/conf.d"
    fi
    cat > "${ROOT}/nginx/conf.d/${DOMAIN}.conf" <<-EOF
server {
    listen 80;
    server_name ${DOMAIN};
    return 301 https://${DOMAIN}:443\$request_uri;
}
server {
    listen       443 ssl;
    server_name  ${DOMAIN};
    charset utf-8;
    
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:HIGH:!aNULL:!MD5:!RC4:!DHE;
    ssl_ecdh_curve secp384r1;	
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_session_tickets off;
    
    ssl_certificate /var/ssl/${DOMAIN}.pem;
    ssl_certificate_key /var/ssl/${DOMAIN}.key;
    
    location ${WS_PATH} {
        proxy_redirect off;
        proxy_pass http://v2ray:${PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }         

    location / {
        return 404;
    }
}
EOF
}

genVlessDockerComposeConfig(){
    cat > "${ROOT}/docker-compose.yml" <<-EOF
version: '2.4'
services: 
    v2ray:
        image: teddysun/v2ray
        container_name: v2ray
        volumes: 
            - ${ROOT}/v2ray/config.json:/etc/v2ray/config.json
        restart: always
        networks: 
            proxy_net:
    nginx:
        image: nginx
        container_name: nginx
        volumes: 
            - ${ROOT}/nginx/nginx.conf:/etc/nginx/nginx.conf
            - ${ROOT}/nginx/conf.d:/etc/nginx/conf.d
            - ${ROOT}/nginx/ssl:/var/ssl
            - ${ROOT}/wait-for-it.sh:/wait-for-it.sh
        entrypoint: "bash /wait-for-it.sh v2ray:${PORT} -- /docker-entrypoint.sh nginx -g 'daemon off;'"
        ports:
            - "80:80"
            - "443:443"
        depends_on: 
            - v2ray
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
                - subnet: 2001:3200:3200::/64
                  gateway: 2001:3200:3200::1
EOF
}

#获取域名并判断格式是否正确
getDomain(){
    domain_flag=''
    until [ "$domain_flag" != '' ]
    do
        read -p "请输入域名: " DOMAIN
        domain_flag=$(echo $DOMAIN | grep -P "^(?=^.{3,255}$)[a-zA-Z0-9][-a-zA-Z0-9]{0,62}(\.[a-zA-Z0-9][-a-zA-Z0-9]{0,62})+$")
        if [ ! -n "${domain_flag}" ]; then
            echo "域名有误,请重新输入!!!"
        fi
    done
}

#申请ssl证书
genSSL(){
    apt install certbot -y
    certbot certonly --standalone --agree-tos --register-unsafely-without-email -d ${DOMAIN}
    if [ "$?" = 1 ];then
        colorEcho ${YELLOW} "申请证书失败"
        exit
    fi  
    if [ ! -d "${ROOT}/nginx"  ];then
        mkdir "${ROOT}/nginx"
    fi
    if [ ! -d "${ROOT}/nginx/ssl"  ];then
        mkdir "${ROOT}/nginx/ssl"
    fi
    ln /etc/letsencrypt/archive/${DOMAIN}/privkey1.pem ${ROOT}/nginx/ssl/${DOMAIN}.key
    ln /etc/letsencrypt/archive/${DOMAIN}/fullchain1.pem ${ROOT}/nginx/ssl/${DOMAIN}.pem
}

#输出配置
printResult(){
    colorEcho ${GREEN}  "Vless+ws+TLS安装成功，请按以下参数手动配置："
    colorEcho ${BLUE} "协议:VLESS"
    colorEcho ${BLUE} "IP(address):${DOMAIN}"
    colorEcho ${BLUE} "端口(port):443"
    colorEcho ${BLUE} "id(uuid):${UUID}"
    colorEcho ${BLUE} "流控(flow):无"
    colorEcho ${BLUE} "加密(encryption):none"
    colorEcho ${BLUE} "传输协议(network):ws"
    colorEcho ${BLUE} "伪装域名(host):${DOMAIN}"
    colorEcho ${BLUE} "路径(path):${WS_PATH}"
    colorEcho ${BLUE} "底层传输安全(tls):TLS"
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

if [ ! -d "${ROOT}"  ];then
    mkdir "${ROOT}"
fi

getDomain
DOMAIN_IP=`ping ${DOMAIN} -c 1 | sed '1{s/[^(]*(//;s/).*//;q}'`
colorEcho ${YELLOW} "您的域名为：${DOMAIN}，解析为：${DOMAIN_IP}"
colorEcho ${YELLOW} "您本机ip为：${LOCAL_IP}"
if [ "${DOMAIN_IP}" != ${LOCAL_IP} ];then
    read -p "您的域名与本机ip不符，是否继续(y/n)?(若使用CDN，请继续):" confirm
    confirm=${confirm:-"n"}
    if [ ${confirm} == "y" ] || [  ${confirm} == "Y" ];then
        :
    else
        exit
    fi
fi

read -p "请输入ws路径，以'/'开头，例/test   :" WS_PATH
WS_PATH=${WS_PATH:-/default}
read -p "是否已有证书？（y/n）:" confirm
confirm=${confirm:-"n"}
if [ ${confirm} == "y" ] || [ ${confirm} == "Y" ];then

    status="no"
    if [ ! -f "./${DOMAIN}.key" ];then
        colorEcho ${YELLOW} "key文件不存在,请把\"${DOMAIN}.key\"文件放于当前目录($(pwd))下"
        status="no"
    else
        colorEcho ${GREEN} "key文件存在"
        status="yes"
    fi
    if [ ! -f "./${DOMAIN}.pem" ];then
        colorEcho ${YELLOW} "pem文件不存在,请把\"${DOMAIN}.pem\"文件放于当前目录($(pwd))下"
        status="no"
    else
        colorEcho ${GREEN} "pem文件存在"
        status="yes"
    fi

    if [ ${status} == "no" ];then
        exit
    fi

    if [ ! -d "${ROOT}/nginx/ssl"  ];then
        mkdir "${ROOT}/nginx/ssl"
    fi
    cp "./${DOMAIN}.key" "${ROOT}/nginx/ssl/${DOMAIN}.key"
    cp "./${DOMAIN}.pem" "${ROOT}/nginx/ssl/${DOMAIN}.pem"
else
    echo "开始申请证书..."
    genSSL
    echo "证书申请成功..."
fi

curl https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh -o ${ROOT}/wait-for-it.sh
genVlessConfig
genNginxConfig
genVlessDockerComposeConfig
docker-compose -f ${ROOT}/docker-compose.yml up -d
printResult