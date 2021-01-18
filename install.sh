rm -rf /etc/localtime
ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

GREEN="32m"
BLUE="36m"
YELLOW="33m"
colorEcho(){
  echo -e "\033[${1}${2}\033[0m"
}

JSON_PATH='/usr/local/etc/v2ray'

sudo apt-get install net-tools -y
sudo apt-get install jq -y

if [ ! -f "./.install-release.sh" ];then
	curl -O https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh
	mv install-release.sh .install-release.sh
fi

bash ./.install-release.sh

port=$(shuf -i 2000-65000 -n 1)
uuid=$(cat /proc/sys/kernel/random/uuid)

cat > ./config.json <<-EOF
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

cat ./config.json | jq '.' > tmp.json
mv tmp.json ${JSON_PATH}/config.json
rm ./config.json


systemctl start v2ray
systemctl enable v2ray


local_ip=$(curl ifconfig.me)
cat > ./vmess.json <<-EOF
{
  "v": "2",
  "ps": "${local_ip}",
  "add": "${local_ip}",
  "port": "${port}",
  "id": "${uuid}",
  "aid": "0",
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
