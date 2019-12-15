#!/bin/sh
# 本脚本为斐讯 K2 刷 OpenWrt 后，需要安装的一堆软件
# 初学者可以通过 Web 界面逐个搜索并安装
# 本文旨在具有一定 Linux 基础的人通过 Putty/SSH 等远程登录路由器
# 进入 OpenWrt 操作系统后一条命令安装所有需要的软件
opkg update
[ $? != 0 ] && echo "更新软件包错误，请检查网络是否通畅" && exit 1
echo "安装中文 Web 界面 ..."
opkg install luci-i18n-base-zh-cn
echo "安装 Polipo HTTP 代理 ..."
opkg install polipo luci-app-polipo luci-i18n-polipo-zh-cn
echo "安装 shadowsocks-libev-ss-local，请注意境外服务器端也要用 shadowsocks-libev，不能是 SSR ..."
opkg install shadowsocks-libev-ss-local luci-app-shadowsocks-libev
echo "安装 DNSCrypt-Proxy DNS 加密，广告屏蔽 ..."
opkg install libustream-openssl dnscrypt-proxy luci-app-dnscrypt-proxy
# echo "设置 wpad 主机名 ..."
