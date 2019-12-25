#!/bin/sh
# 
# 这个脚本用来根据域名来检测网站的域名信息以及托管服务器的信息
# 需要的命令： curl, xmllint, whois, host
# 作者： 徐永久 @上海甬洁网络科技有限公司
# QQ: 8122093
# Date: 2019-12-25
# To Do: 可以添加爬取公司工商信息，备案信息的内容
# 
DOMAIN=$1
[ -z "$DOMAIN" ] && echo "Syntax: $0 域名" && exit 0
echo "www.$DOMAIN 网站信息："
# /usr/local/bin/curl -sSL --dns-servers "114.114.114.114" http://www.$DOMAIN/ 2>/dev/null 
curl -sSL http://www.$DOMAIN/ 2>/dev/null \
	|xmllint --html --nowarning --encode 'UTF8' --xpath '//title' - 2>/dev/null 
echo
echo "$DOMAIN 域名信息："
whois -H $DOMAIN|egrep "^Registrar"|grep -v "Abuse" || whois -H $DOMAIN

# IP=$(host -t A www.$DOMAIN 114.114.114.114|tail -1|awk '{print $NF}')
IP=$(host -t A www.$DOMAIN|tail -1|awk '{print $NF}')
echo
echo "Web 服务器的 $IP 托管信息："
whois -H $IP|grep -i netname
