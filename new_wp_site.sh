#!/bin/bash
# 本脚本自动安装 WP 站点
# 自动 添加 Nginx 配置
# 自动 添加 www.DOMAINNAME 证书
# 
CWD="/var/www/html/wordpress"
LOG="$CWD/wp_add.log"

[ $(id -u) == 0 ] && echo "Pls don't run this script as root user" && exit 1
# wp-cli 的命令名称
WP="/bin/wp"
# Nginx 模版
TPL="/etc/nginx/conf.d/wp.conf.tpl"

check_proxy () {
	export https_proxy="127.0.0.1:8888"
	nc -z $(echo $https_proxy|sed 's/:/ /g') >/dev/null 
	[ $? != 0 ] && echo "翻墙没打开" && unset https_proxy
}

nginx_add () {
	local dom=$1
	local conf=$(dirname $TPL)/wp.$dom.conf
	[ -f "$conf" ] && echo "Nginx 配置文件已经存在" && return
	sudo cp $TPL $conf
	[ $? != 0 ] && echo "创建 Nginx 配置文件失败" && exit 80
	sudo perl -p -i -e "s/DOMAIN/$dom/g" $conf
	[ $? != 0 ] && echo "编辑 Nginx 配置文件失败" && exit 81
	sudo nginx -t -c $conf 
	[ $? != 0 ] && echo "Nginx 配置校验失败" && exit 82
	sudo nginx reload
	[ $? != 0 ] && echo "Nginx 重启失败，请立即检查" && exit 89
}

cert_add () {
	local dom=$1
	[ -n "$(sudo certbot certificates|grep "Certificate Name:"|grep $dom)" ] && \
		echo "$dom 证书已经存在" && return
	sudo certbot --nginx --no-redirect certonly -d $dom
	[ $? != 0 ] && echo "添加证书失败" && exit 90 
}

check_beian() {
	# 检查网站备案是否搞定
	return
}

pre_verify_domain () {
	local dom=$1
	myip=$(https_proxy="" curl -sS https://ipv4bot.whatismyipaddress.com)
	domip=$(getent hosts $dom|awk '{print $1}')
	if [ "${myip}" != "${domip}" ] ; then
		echo "Domain $dom IP: ${domip} is not on this server [$myip]!" 
		exit 10
	fi
}

add_wp () {
	local dom=$1
	local cwd=$CWD/$dom
	if [ ! -d $cwd ]; then
	       	mkdir $cwd 
		[ $? != 0 ] && echo "创建 $cwd 目录失败" && exit 99
	fi
	# DB 参数
	db_user=$(echo $dom|sed -e 's/\./_/g')
	db_name="wp_"${db_user}
	db_host="localhost"
	db_pass=$(date +"%Y%m%d-%H:%M:%S"|sha256sum|base64|head -c 16)
	db_charset="utf8mb4"
	# Web 参数
	url="https://www."$dom
	title="$dom 博客"
	admin=$(echo $dom|cut -d '.' -f1)"_admin"
	email="albertxu@freelamp.com"
	passwd=$(date +%s | sha256sum | base64 | head -c 16)
	# 
	cd $cwd
	# 开始
	# 下载 WP
	$WP core download
	[ $? != 0 ] && echo "下载 WP core 失败！" && return 22
	# 创建数据库
	sudo mysql -e "create database $db_name; grant all on $db_name.* to $db_user@$db_host identified by \"$db_pass\";flush privileges;" 2>>$LOG
	[ $? != 0 ] && echo "创建 WP 数据库失败！" && return 23
	# 创建配置文件 wp-config.php
	$WP config create --dbhost="$db_host" --dbname="$db_name" \
	--dbcharset="$db_charset" --dbuser="$db_user" --dbpass="$db_pass" 2>>$LOG
	[ $? != 0 ] && echo "创建 WP 配置失败！" && return 24
	# 正式安装 WP，设置 URL，Title,登录用户信息
	$WP core install --url="$url" --title="$title" --admin_user="$admin" \
		--admin_email="$email" --admin_password="$passwd" 2>>$LOG
	[ $? != 0 ] && echo "安装 WP 失败！" && return 25
	sudo chmod 777 wp-content/uploads
	# 安装中文语言包
	$WP core language install zh_CN --activate 2>>$LOG
	[ $? != 0 ] && echo "安装 中文语言包 失败！" && return 26
	# 安装主题和插件
	# 主题只是示例
	$WP theme install optimizer --activate 2>>$LOG
	# 插件只是示例
	$WP plugin install w3-total-cache wordpress-seo --activate
	echo "成功的安装了 WP ,登录用户名 $admin，口令 $passwd，URL: $url"
}

# Main Prog.
DOMAIN=$1
WWW="www."$DOMAIN
[ -z "$DOMAIN" ] && echo "Syntax: $0 domain.name" && exit 1
[ "OK" != "$(sudo -s echo OK)" ] && echo "当前用户没有 sudo 权限" && exit 2
[ ! -d $CWD ] && echo "工作目录 $CWD 不存在"  && exit 3
[ ! -x $WP ] && echo "请确保 WP-CLI 的文件路径 $WP 正确" && exit 4
check_proxy
# 预校验域名
pre_verify_domain $WWW
# 先检查 Nginx 配置是否正常
sudo nginx -t
[ $? != 0 ] && echo "Nginx 配置有问题" && exit 9
# 先添加证书
cert_add $WWW
# 配置 Wordpress
add_wp $DOMAIN 
# 再添加 Nginx 配置
nginx_add $DOMAIN 
# 
