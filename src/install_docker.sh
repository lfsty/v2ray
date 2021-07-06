#!/bin/bash

#docker环境安装
echo "检查安装Docker环境......"
docker -v
if [ $? -eq  0 ]; then
    echo "检查到Docker已安装!"
else
    echo "安装docker环境..."
    curl -sSL https://get.daocloud.io/docker | sh
    cat > "/etc/docker/daemon.json" <<-EOF
{
    "ipv6": true,
    "fixed-cidr-v6": "fe00::/64",
    "experimental": true,
    "ip6tables": true
}
EOF
    systemctl restart docker
    echo "安装docker环境...安装完成!"
fi

docker-compose --version
if [ $? -eq 0 ]; then
    echo "docker-compose已安装"
else
    curl -sSL "https://github.com/docker/compose/releases/download/1.24.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
fi