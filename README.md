# v2ray 一键部署

原文地址（旧版本）：https://toutyrater.github.io/  
仓库地址（新版本）：https://github.com/v2fly/fhs-install-v2ray

仅供自己学习使用，Ubuntu18.0.4+,不定期维护

一键安装
```shell
bash <(curl -s https://raw.githubusercontent.com/lfsty/v2ray/master/install.sh)
```
卸载
```shell
bash <(curl -s https://raw.githubusercontent.com/lfsty/v2ray/master/uninstall.sh)
```



* 2021.1.24 

  重构，基于docker安装，增加vless+ws+tls选项，但证书只有三个月，需手动跟新，或手动添加crontab

  ```shell
  /usr/bin/certbot renew
  ```

* 2021.2.5

  增加ssl证书申请是否成功判断

 