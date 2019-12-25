#!/bin/sh
# 
DOMAIN=$1
echo "www.$DOMAIN 网站信息："
[ -z "$DOMAIN" ] && echo "Syntax: $0 域名" && exit 0
# /usr/local/bin/curl -sSL --dns-servers "114.114.114.114" http://www.$DOMAIN/ 2>/dev/null \
/usr/local/bin/curl -sSL http://www.$DOMAIN/ 2>/dev/null \
	|xmllint --html --nowarning --encode 'UTF8' --xpath '//title' - 2>/dev/null 
echo
echo "$DOMAIN 域名信息："
whois -H $DOMAIN|egrep "^Registrar"|grep -v "Abuse" || whois -H $DOMAIN

# IP=$(host -t A www.$DOMAIN 114.114.114.114|tail -1|awk '{print $NF}')
IP=$(host -t A www.$DOMAIN|tail -1|awk '{print $NF}')
echo
echo "Web 服务器的 $IP 托管信息："
whois -H $IP|grep -i netname
