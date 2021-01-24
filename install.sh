#!/bin/bash

GREEN="32m"
BLUE="36m"
YELLOW="33m"
colorEcho(){
  echo -e "\033[${1}${2}\033[0m"
}

#域名
domain=""
#域名对应的ip
domain_ip=""
#本机ip
local_ip=$(curl ifconfig.me)
#端口号
port=$(shuf -i 10000-65000 -n 1)
#uuid
uuid=$(cat /proc/sys/kernel/random/uuid)
#ws的路径
ws_path=""
#配置文件存放路径
path="/var/lfsty"

#docker安装
docker_install()
{
	echo "检查Docker......"
	docker -v
    if [ $? -eq  0 ]; then
        echo "检查到Docker已安装!"
    else
    	echo "安装docker环境..."
        curl -sSL https://get.daocloud.io/docker | sh
        echo "安装docker环境...安装完成!"
    fi
}

#生成vmess配置文件
genVmessConfig(){
if [ ! -f "${path}/v2ray/config.json" ];then
cat > "${path}/v2ray/config.json" <<-EOF
{
  "log":{
    "loglevel":"info",
    "access":"/var/log/v2ray/access.log"
  },
  "inbounds": [{
    "port": ${port},
    "protocol": "vmess",
    "settings": {
      "clients": [
        {
          "id": "${uuid}",
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
fi
}
   

#docker部署Vmess
dockerRunVmess(){
    docker run --name vmess --restart=always -p ${port}:${port} \
    -v "${path}/v2ray/config.json":/etc/v2ray/config.json:rw \
    -d teddysun/v2ray
}
#生成vmess链接
genVmessUrl(){
cat > ./vmess.json <<-EOF
{
  "v": "2",
  "ps": "${local_ip}",
  "add": "${local_ip}",
  "port": "${port}",
  "id": "${uuid}",
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

    colorEcho ${GREEN}  "您的vmess链接为："
    colorEcho ${BLUE} ${vmess}
}


#vmess安装
install_vmess(){
    docker pull teddysun/v2ray

    if [ ! -d "${path}/v2ray"  ];then
        mkdir "${path}/v2ray"
    fi

    genVmessConfig
    dockerRunVmess
    genVmessUrl
}


#获取域名并判断格式是否正确
getDomain(){
    domain_flag=''
    until [ "$domain_flag" != '' ]
    do
        read -p "请输入域名: " domain
        domain_flag=$(echo $domain | grep -P "^(?=^.{3,255}$)[a-zA-Z0-9][-a-zA-Z0-9]{0,62}(\.[a-zA-Z0-9][-a-zA-Z0-9]{0,62})+$")
        if [ ! -n "${domain_flag}" ]; then
            echo "域名有误,请重新输入!!!"
        fi
    done
}

#判断域名ip是否与本机ip相同
#相同返回1，不同返回0
judgeIP(){
    if [ "${local_ip}" = "${domain_ip}" ];then
        return 1
    else
        return 0
    fi
}

#生成vless的config
genVlessConfig(){
if [ ! -f "${path}/v2ray/config.json" ];then
cat > "${path}/v2ray/config.json" <<-EOF
{
  "inbounds": [{
    "port": ${port},
    "protocol": "vless",
    "settings": {
        "clients": [
            {
                "id": "${uuid}",
                "level": 0
            }
        ],
        "decryption": "none"
    },
    "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
            "path": "${ws_path}",
            "headers": {
                "Host": "${domain}"
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
fi
}

#生成nginx配置文件
genNginxConfig(){
if [ ! -f "${path}/nginx/nginx.conf" ];then

cat > "${path}/nginx/nginx.conf" <<-EOF
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
fi

if [ ! -f "${path}/nginx/conf.d/${domain}.conf" ];then
cat > "${path}/nginx/conf.d/${domain}.conf" <<-EOF
server {
    listen 80;
    server_name ${domain};
    return 301 https://${domain}:443\$request_uri;
}
server {
    listen       443 ssl;
    server_name  ${domain};
    charset utf-8;
    
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:HIGH:!aNULL:!MD5:!RC4:!DHE;
    ssl_ecdh_curve secp384r1;	
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_session_tickets off;
    
    ssl_certificate /etc/letsencrypt/live/${domain}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${domain}/privkey.pem;
    
    location ${ws_path} {
        proxy_redirect off;
        proxy_pass http://vless:${port};
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
fi
}

dockerCreateNetwork(){
  docker network create nginx-v2ray
}
dockerRunImages(){
  docker run --name vless --restart=always --network nginx-v2ray \
  -v "${path}/v2ray/config.json":/etc/v2ray/config.json:rw \
  -d teddysun/v2ray

  docker run -p 80:80 -p 443:443 --name nginx --restart=always --network nginx-v2ray \
  -v "${path}/nginx/nginx.conf":/etc/nginx/nginx.conf:rw \
  -v "${path}/nginx/conf.d":/etc/nginx/conf.d:rw \
  -v /etc/letsencrypt:/etc/letsencrypt:rw \
  -d nginx
}

#申请ssl证书
genSSL(){
    echo "申请证书"
    apt install certbot -y
    certbot certonly --standalone --agree-tos --register-unsafely-without-email -d ${domain}
}

#Vless+ws+TLS安装
install_vless(){

    if [ ! -d "${path}/nginx"  ];then
        mkdir "${path}/nginx"
    fi

    if [ ! -d "${path}/v2ray"  ];then
        mkdir "${path}/v2ray"
    fi

    if [ ! -d "${path}/nginx/conf.d"  ];then
        mkdir "${path}/nginx/conf.d"
    fi
    
    getDomain
    domain_ip=`ping ${domain} -c 1 | sed '1{s/[^(]*(//;s/).*//;q}'`
    judgeIP
    if [ "$?" = 1 ];then
        colorEcho ${GREEN} "域名解析正确"
        read -p "请输入ws路径，以'/'开头，例/test   :" ws_path

        genNginxConfig
        genVlessConfig
        genSSL
        docker pull nginx
        docker pull teddysun/v2ray
        dockerCreateNetwork
        dockerRunImages

        colorEcho ${GREEN}  "Vless+ws+TLS安装成功，请按以下参数手动配置："
        colorEcho ${BLUE} "协议:VLESS"
        colorEcho ${BLUE} "IP(address):${domain}"
        colorEcho ${BLUE} "端口(port):443"
        colorEcho ${BLUE} "id(uuid):${uuid}"
        colorEcho ${BLUE} "流控(flow):无"
        colorEcho ${BLUE} "加密(encryption):none"
        colorEcho ${BLUE} "传输协议(network):ws"
        colorEcho ${BLUE} "伪装域名(host):${domain}"
        colorEcho ${BLUE} "路径(path):${ws_path}"
        colorEcho ${BLUE} "底层传输安全(tls):TLS"
    else
        colorEcho ${YELLOW} "您的IP为：${local_ip}"
        colorEcho ${YELLOW} "域名解析错误，程序退出"
        exit
    fi

}

install_command(){
    apt-get install curl -y
}

echo "1) Vmess"
echo "2) Vless+ws+TLS(需要一个已经完成解析并指向此服务器的域名)"
read -p "请选择：" num

docker_install
install_command
if [ ! -d "${path}"  ];then
  mkdir "${path}"
fi

case ${num} in
    1)
        install_vmess
        ;;
    2)
        install_vless
        ;;
    *)
        echo "error"
esac