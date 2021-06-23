# v2ray 部署

原文地址（旧版本）：https://toutyrater.github.io/  
仓库地址（新版本）：https://github.com/v2fly/fhs-install-v2ray

仅供自己学习使用，Ubuntu18.0.4+,不定期维护

安装
```shell
bash <(curl -s https://raw.githubusercontent.com/lfsty/v2ray/master/start.sh)
```


* 2021.6.23

  * 拆分文件

  * 支持ipv6

* 2021.3.6

  集成卸载功能

* 2021.3.5

  增加自有ssl证书选项

* 2021.2.5

  增加ssl证书申请是否成功判断

* 2021.1.24 

  重构，基于docker安装，增加vless+ws+tls选项，但证书只有三个月，需手动跟新，或手动添加crontab

  ```shell
  /usr/bin/certbot renew
  ```
