#!/bin/bash
# 根据当前办公室的公网 IP ，自动注册 GoDaddy DNS
# 详细使用说明请参见 Main Prog. 部分
# 作者：徐永久 (Albert Xu <albertxu@freelamp.com>)
# 更新日期： 2019-10-10
# 

check_command () {
	for cmd in jq curl;do
		which $cmd >/dev/nulll
		[ $? != 0 ] && echo "命令 $cmd 不存在，请检查！" && exit 1
	done
	if [ -n "$MAIL_TO" ];then
		which mail >/dev/nulll
		[ $? != 0 ] && echo "命令 $cmd 不存在，请检查！" && exit 1
	fi
}

generate_json () {
	echo '[
  {
          "api_key": "your_api_key_here",
          "api_secret": "your_api_secret_here"
  }
]' > $GODADDY_KEY
	echo "请修改当前目录下的 godaddy.json 填写好 api_key/api_scret 的值"
}

GoDaddy() {
	[ ! -f "$GODADDY_KEY" ] && generate_json && return
	newIP=$1
	[ -z "$newIP" -o -z "$FQDN" ] && echo "修改 DNS 记录的新 IP 地址参数缺失" && return
	RECORD=$(echo $FQDN|awk -F"." '{print $1}')
	DOMAIN=$(echo $FQDN|awk -F"." '{print $(NF - 1) "." $NF}')
	API_URL="https://api.godaddy.com/v1/domains"
	URL=${API_URL}/${DOMAIN}/records/A/${RECORD}
	API_KEY=$(cat $GODADDY_KEY |jq -r '.[] | .api_key')
	API_SECRET=$(cat $GODADDY_KEY |jq -r '.[] | .api_secret')
	CURR_IP=$(curl -sS -X GET -H "Authorization: sso-key $API_KEY:$API_SECRET" $URL|jq -r '.[] | .data')
	echo "域名 $FQDN 当前的 IP 是： $CURR_IP"
	[ "$newIP" = "$CURR_IP" ] && return
	curl -sS -X PUT $URL \
	-H  "accept: application/json"  \
	-H  "Content-Type: application/json"  \
	-H "Authorization: sso-key $API_KEY:$API_SECRET" \
	-d "[{\"data\": \"${newIP}\"}]"
	[ $? != 0 ] && echo " :-( 修改 IP 地址失败，请检查!" && return
	msg="恭喜：设置域名 $FQDN 为新的 IP：$newIP 成功，请稍后在客户端 ping/nslookup"
	subject="设置域名 $FQDN 为新的 IP：$newIP"
	echo $msg
	send_mail
}

send_mail () {
	[ -z "$MAIL_TO" -o -z "$msg" -o -z "$subject" ] && echo "发送邮件所需要的参数缺失" && return
	echo "$msg"|mail -s "$subject" -r "MyOffice@$(hostname).local"  \
	-a 'Content-Type: text/html; charset=UTF-8' \
	-a 'Content-Transfer-Encoding: 8bit' $MAIL_TO
}

syntax () {
	echo "$0 -d FQDN [-t mailtoaddress]"
	echo "	FQDN 为服务器完整的域名，例如 hostname.domain.com"
	exit 2
}

is_all_digits () {
  case $1 in 
	  *[!0-9]*) echo "0";; 
	         *) echo "1";;
  esac
}

# #######################################################################
# Main Prog.
# 自动更新公司内动态 IP 注册到固定的 DNS 域名
# 也即：能通过固定的名字访问公司内部服务器
# 本程序有条件的话可以定期执行，譬如每 2 分钟检查:
# */2 * * * * /bin/MyOffice.sh -d office.domain.com -t email_address@qq.com
# 退出码： 
#	1: 脚本需要的命令不存在
#	2: 输入参数有误
#	9: 取公网地址失败
# #######################################################################

while getopts "t:d:" opt 2>/dev/null; do
  case $opt in
    d)
      # 要修改的 DNS 域名全称
      FQDN=$OPTARG
      ;;
    t)
      # 收件人邮件地址
      MAIL_TO=$OPTARG
      ;;
    \?)
      echo "无效参数 -$OPTARG"
      syntax
      ;;
  esac
done
check_command
[ -z "$FQDN" ] && syntax
GODADDY_KEY="$(dirname $0)/godaddy.json"
myIP=$(curl -sS ipv4bot.whatismyipaddress.com)
[ -z "$myIP" ] && echo "取当前公网 IP 失败！" && exit 9
GoDaddy $myIP
