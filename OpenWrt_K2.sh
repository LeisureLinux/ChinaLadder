#!/bin/sh
# 本脚本为斐讯 K2 刷 OpenWrt 后，需要安装的一堆软件
# 初学者可以通过 Web 界面逐个搜索并安装
# 本文旨在具有一定 Linux 基础的人通过 Putty/SSH 等远程登录路由器
# 进入 OpenWrt 操作系统后一条命令安装所有需要的软件
#
# 命令行 wget 自动执行本脚本需要以下三个软件提前安装
# 即 刷机后首先命令行下运行：
# opkg update; opkg install libustream-openssl ca-bundle ca-certificates
# 然后用 wget 调用本脚本
# wget -4 --no-check-certificate -O -  \
#    https://raw.githubusercontent.com/ZenBoy999/ChinaLadder/master/OpenWrt_K2.sh |sh
echo "正在更新 opkg 库中，时间会比较长，请耐心等候 ..."
opkg -V0 update
[ $? != 0 ] && echo "更新软件包错误，请检查网络是否通畅" && exit 1
echo "安装 中文 Web 界面中 ..."
opkg -V0 install luci-i18n-base-zh-cn
[ $? != 0 ] && echo "安装中文 Web 界面出错" && exit 2
echo "安装 Polipo HTTP 代理中 ..."
opkg -V0 install polipo luci-app-polipo luci-i18n-polipo-zh-cn
[ $? != 0 ] && echo "安装 Polipo 出错"  && E=1
echo "安装 shadowsocks-libev-ss-local 中，请注意境外服务器端也要用 shadowsocks-libev，不能是 SSR ..."
opkg -V0 install shadowsocks-libev-ss-local luci-app-shadowsocks-libev
[ $? != 0 ] && echo "安装 shadowsocks-libev-local 出错"  && E=1
echo "安装 DNSCrypt-Proxy DNS 加密，广告屏蔽中 ..."
opkg -V0 install libustream-openssl dnscrypt-proxy luci-app-dnscrypt-proxy
[ $? != 0 ] && echo "安装 DNS 加密出错" && E=1
# echo "设置 wpad 主机名 ..."
[ "$E" = "1" ] && echo "安装过程有出错的步骤，请手工检查，或者尝试重新运行本脚本"
echo "接下来，您需要添加 shadowsocks-libev 的远程服务器，添加一条 wpad 的主机记录，\
	用 genpac 生成一个 wpad.dat 文件放到 /www 目录下"
echo "重启路由后，在 IE/Firefox/手机Wi-Fi配置/网络电视 等设备上，设置自动代理即可科学上网了"
echo "############  刷机愉快！ ##############"

