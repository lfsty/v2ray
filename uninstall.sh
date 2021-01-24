GREEN="32m"
colorEcho(){
  echo -e "\033[${1}${2}\033[0m"
}

docker rm -f nginx
docker rm -f vmess
docker rm -f vless
colorEcho ${GREEN} "卸载完成"
