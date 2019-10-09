#!/bin/bash
# 用 AWS CLI 动态修改 EC2 IP 地址
# 详细使用说明请参见 Main Prog. 部分
# 作者：徐永久 (Albert Xu <albertxu@freelamp.com>)
# 更新日期： 2019-10-10
# 

release_ip () {
 [ -z "$AllocId" ] && echo "释放地址所需要的 分配 ID 参数缺失" && return
 $AWS ec2 release-address --allocation-id $AllocId
 [ $? == 0 ] && echo "IP $OLDIP 成功释放." || echo " :-( IP $OLDIP 释放失败"
}

new_ip () {
  NEWIP=$($AWS ec2 allocate-address|jq -r '.PublicIp')
  [ -n "$NEWIP" ] && echo "拿到了新的 IP: $NEWIP" || (echo "取新 IP 地址失败了！";return)
}

associate_ip () {
  [ -z "$INST" -o -z "$NEWIP" ] && echo "绑定实例所需要的参数缺失" && return
  $AWS ec2 associate-address --instance-id ${INST} --public-ip ${NEWIP}
  [ $? == 0 ] && echo "IP $NEWIP 成功的绑定到了实例 $INST" || echo " :-( 绑定 IP:$NEWIP 到实例 $INST 失败"
  [ -n "$FQDN" ] && GoDaddy $NEWIP
}

replace_ip() {
	release_ip
	add_ip
}

add_ip () {
	new_ip
	associate_ip 
}

remove_floatIP () {
	# 删除多余的 IP 地址
	echo "检查当前 AWS Profile 下可能存在的浮动的(没有被分配的) IP ..."
	$AWS ec2 describe-addresses >$tmpJSON
	[ $? != 0 ] && echo "看上去执行 aws 命令有错啊！先跑一下 aws configure 命令吧！" && exit 10
	for i in $(seq 0 9)
	do
		OLDIP=$(jq ".Addresses[$i]" $tmpJSON|jq -r '.PublicIp')
		[ "$OLDIP" == "null" ] && break
		AllocId=$(jq ".Addresses[$i]" $tmpJSON|jq -r '.AllocationId')
		INST=$(jq ".Addresses[$i]" $tmpJSON|jq -r '.InstanceId')
		[ "$INST" == "null" ] && release_ip
	done
	rm $tmpJSON
}

check_command () {
	for cmd in jq nc aws curl;do
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
	[ -z "$newIP" ] && echo "修改 DNS 记录的新 IP 地址参数缺失" && return
	RECORD=$(echo $FQDN|awk -F"." '{print $1}')
	DOMAIN=$(echo $FQDN|awk -F"." '{print $(NF - 1) "." $NF}')
	API_URL="https://api.godaddy.com/v1/domains"
	URL=${API_URL}/${DOMAIN}/records/A/${RECORD}
	API_KEY=$(cat $GODADDY_KEY |jq -r '.[] | .api_key')
	API_SECRET=$(cat $GODADDY_KEY |jq -r '.[] | .api_secret')
	CURR_IP=$(curl -sS -X GET -H "Authorization: sso-key $API_KEY:$API_SECRET" $URL|jq -r '.[] | .data')
	echo "域名 $FQDN 当前的 IP 是： $CURR_IP"
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
	echo "$msg"|mail -s "$subject" -r "ChinaLadder@$(hostname).local"  \
	-a 'Content-Type: text/html; charset=UTF-8' \
	-a 'Content-Transfer-Encoding: 8bit' $MAIL_TO
}

check_port () {
	[ -z "$1" -o -z "$2" ] && echo  "检查端口所需要的主机名/IP 或者 端口号 参数缺失" && return 
	echo "检查 IP/主机: $1 上的端口 $2 ..."
	nc -4 -w 2 $1 $2
	[ $? == 0 ] && echo "看上去端口 $2 是好的啊！请检查是否其他问题再更改 IP 吧！" && exit 99
}

syntax () {
	echo "$0 -p PORT [ -d FQDN ]"
	echo "	端口号 Port 为必须参数，用于检测对应的服务"
	echo "	FQDN 为服务器完整的域名，例如 hostname.domain.com"
	echo "	没有 FQDN 时，不修改 DNS 记录"
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
# 本脚本用于自动更换 EC2 实例的公网 IP 地址
# 运行本脚本前请先运行 aws configure 命令，根据要求配置好密钥
# https://docs.amazonaws.cn/cli/latest/userguide/cli-chap-configure.html#cli-quick-configuration
# 如果需要多个 profile ，用 aws configure --profile profilename1 来配置
#     运行脚本时用 -P profilename 来使用不同的 AWS Profile.
#     目前仅支持一个 Profile 下一个实例，一个实例下一个 Public IP
#     如果一个 Profile 有多个实例，可以把 Profile 拆分成多个，每个下面只管理一个实例
# 本脚本仅用于 bash 环境，适用于 Linux/MacOS，但是已经在 Cygwin 上测试成功
# 如果需要 Windows Cygwin 上使用请参考以下 URL 安装 Cygwin/apt-cyg:
#     https://tech.yj777.cn/cygwin-%e6%b8%85%e5%8d%8e%e9%95%9c%e5%83%8f/
#     安装相关的软件包：apt-cyg install jq nc curl git 即可
#     git clone 本脚本后如果遇到不能运行是因为文件末尾添加了 ^M，用 vim -b 去掉回车(^M) 即可
#     再参照 AWS CLI 手册安装 Windows 上的 AWS CLI:
#     https://docs.amazonaws.cn/cli/latest/userguide/install-windows.html
#     Windows 10 的用户也可以跑 wsl，直接使用 Linux 子系统，或者用 Hyper-V 安装 Linux 虚拟机
#     Widndows 7 之后的操作系统也可以用 VirtualBox 之类安装 Linux 虚拟机
# 目前仅用于自动更新 GoDaddy 域名，命令行设置 -d FQDN 后，可自动更新
# 
# 本程序有条件的话可以定期执行，譬如每 12 分钟检查端口被封情况，crontab 例子：
# */12 * * * * /bin/ChinaLadder.sh -p 2019 -P profilename -d ladder.domain.com -t email_address@qq.com
# 退出码： 
#	1: 脚本需要的命令不存在
#	2: 输入参数有误
#	10: aws 没配置好
#	99: 端口能正常访问，无需更改
# #######################################################################

while getopts "P:p:t:d:" opt 2>/dev/null; do
  case $opt in
    p)
      # 这个 PORT 是你自己的 SS 侦听的端口，要根据你自己的配置传参数
      PORT=$OPTARG
      ;;
    P)
      # 大写 P，添加 AWS Profile 参数, 可以用 aws configure --profile name 生成多个 profile
      PROFILE=$OPTARG
      ;;
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
[ -z "$PORT" ] && syntax
[ $(is_all_digits $PORT) -eq 0 ] &&  echo "端口号 $PORT 不是数字!"  && syntax
[ -n "$FQDN" ] && check_port $FQDN $PORT
[ -n "$PROFILE" ] && AWS="aws --profile $PROFILE " || AWS="aws"

# 临时文件
tmpJSON="/tmp/awscli.json"
# 放当前目录下的 GoDaddy Key文件 
GODADDY_KEY="$(dirname $0)/godaddy.json"
# 检查需要的命令是否存在
check_command
# 删除多余的浮动 IP，如果不要这个步骤，请注释掉
remove_floatIP
# 取出当前 Profile 下的实例
$AWS ec2 describe-instances >$tmpJSON
INST=$(cat $tmpJSON |jq  '.[]'|jq  -r '.[] | .Instances' |jq -r '.[] | .InstanceId')
OLDIP=$(cat $tmpJSON |jq  '.[]'|jq  -r '.[] | .Instances' |jq -r '.[] | .PublicIpAddress')
[ -n "$OLDIP" ] && AllocId=$($AWS ec2 describe-addresses --public-ips $OLDIP|jq -r '.Addresses[] | .AllocationId')

if [ -n "${OLDIP}" ];then
	echo "实例 $INST 当前的 IP 为 ${OLDIP} 分配到 $AllocId"
	check_port $OLDIP $PORT
	replace_ip
else
	echo "实例 $INST 当前没有分配公网 IP 地址"
	add_ip 
fi
[ -f "$tmpJSON" ] && rm $tmpJSON
echo "当前分配的所有地址："
$AWS ec2 describe-addresses 
