GREEN="32m"
colorEcho(){
  echo -e "\033[${1}${2}\033[0m"
}

if [ ! -f "./.install-release.sh" ];then
	echo "v2ray尚未安装"
	exit
fi

systemctl stop v2ray
systemctl disable v2ray
bash ./.install-release.sh --remove
colorEcho ${GREEN} "卸载完成"
