#!/bin/bash
# 用 AWS CLI 动态修改 EC2 IP 地址
# 详细使用说明请参见 Main Prog. 部分

release_ip () {
 aws ec2 release-address --allocation-id $AllocId
 [ $? == 0 ] && echo "IP $OLDIP 成功释放." || echo " :-( IP $OLDIP 释放失败"
}

new_ip () {
  NEWIP=$(aws ec2 allocate-address|jq -r '.PublicIp')
  [ -n "$NEWIP" ] && echo "拿到了新的 IP: $NEWIP" || (echo "取新 IP 地址失败了！";return)
}

associate_ip () {
  aws ec2 associate-address --instance-id ${INST} --public-ip ${NEWIP}
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
	aws ec2 describe-addresses >/dev/null
	[ $? != 0 ] && echo "看上去执行 aws 命令有错啊！先跑一下 aws configure 命令吧！" && exit 10
	for i in $(seq 0 9)
	do
		OLDIP=$(jq ".Addresses[$i]" $tmpJSON|jq -r '.PublicIp')
		[ "$OLDIP" == "null" ] && break
		AllocId=$(jq ".Addresses[$i]" $tmpJSON|jq -r '.AllocationId')
		INST=$(jq ".Addresses[$i]" $tmpJSON|jq -r '.InstanceId')
		[ "$INST" == "null" ] && release_ip
	done
}

check_port () {
	nc -4 -w 2 $OLDIP ${PORT}
	[ $? == 0 ] && echo "看上去端口是好的啊！请检查是否其他问题再更改 IP 吧！" && exit 99
}

check_command () {
	for cmd in jq nc aws;do
		which $cmd >/dev/nulll
		[ $? != 0 ] && echo "命令 $cmd 不存在，请检查！" && exit 1
	done
}

generate_json () {
	echo '[
  {
          "api_key": "your_api_key_here",
          "api_secret": "your_api_secret_here"
  }
]' > godaddy.json
	echo "请修改当前目录下的 godaddy.json 填写好 api_key/api_scret 的值"
}

GoDaddy() {
	[ ! -f "godaddy.json" ] && generate_json && return
	newIP=$1
	[ -z "$newIP" ] && return
	RECORD=$(echo $FQDN|awk -F"." '{print $1}')
	DOMAIN=$(echo $FQDN|awk -F"." '{print $(NF - 1) "." $NF}')
	API_URL="https://api.godaddy.com/v1/domains"
	URL=${API_URL}/${DOMAIN}/records/${TYPE}/${RECORD}
	API_KEY=$(cat godaddy.json |jq -r '.[] | .api_key')
	API_SECRET=$(cat godaddy.json |jq -r '.[] | .api_secret')
	CURR_IP=$(curl -sS -X GET -H "Authorization: sso-key $API_KEY:$API_SECRET" $URL|jq -r '.[] | .data')
	echo "域名 $FQDN 当前的 IP 是： $CURR_IP"
	curl -sS -X PUT $URL \
	-H  "accept: application/json"  \
	-H  "Content-Type: application/json"  \
	-H "Authorization: sso-key $API_KEY:$API_SECRET" \
	-d "[{\"data\": \"${newIP}\"}]"
	[ $? != 0 ] && echo " :-( 修改 IP 地址失败，请检查!" && return
	echo "恭喜：设置域名 $FQDN 为新的 IP：$newIP 成功，请稍后客户端 ping/nslookup"
}

syntax () {
	echo "$0 -p PORT [ -d FQDN -t TYPE ]"
	echo "	端口号 Port 为必须参数，用于检测对应的服务"
	echo "	FQDN 为服务器完整的域名，例如 hostname.domain.com"
	echo "	TYPE 为记录类型，默认 A"
	echo "	没有 FQDN 和 TYPE 时，不修改 DNS 记录"
	exit 2
}

# #######################################################################
# Main Prog.
# 本脚本用于自动更换 EC2 实例的公网 IP 地址
# 目前仅用于当前 AWS Profile 下只有一个实例的情况
# 运行本脚本前请先运行 aws configure 命令，根据要求配置好密钥
# https://docs.amazonaws.cn/cli/latest/userguide/cli-chap-configure.html#cli-quick-configuration
# 本脚本仅用于 bash 环境，适用于 Linux/MacOS
# 如果需要 Windows 上使用请参考以下 URL 安装 Cygwin/apt-cyg:
# https://tech.yj777.cn/cygwin-%e6%b8%85%e5%8d%8e%e9%95%9c%e5%83%8f/
# 再参照 AWS CLI 手册安装 Windows 上的 AWS CLI:
# https://docs.amazonaws.cn/cli/latest/userguide/install-windows.html
# 目前仅用于自动更新 GoDaddy 域名，命令行设置 -d FQDN 后，可自动更新
# 
# 本程序有条件的话可以定期执行，譬如每 5 分钟检查端口被封情况
# 退出码： 
#	1: 脚本需要的命令不存在
#	2: 输入参数有误
#	10: aws 没配置好
#	99: 端口能正常访问，无需更改
# #######################################################################

while getopts "p:t:d:" opt 2>/dev/null; do
  case $opt in
    p)
      # 这个 PORT 是你自己的 SS 侦听的端口，要根据你自己的配置传参数
      PORT=$OPTARG
      ;;
    d)
      # 要修改的 DNS 域名全称
      FQDN=$OPTARG
      ;;
    t)
      # 要修改的DNS 记录类型
      TYPE=$OPTARG
      ;;
    \?)
      echo "无效参数 -$OPTARG"
      syntax
      ;;
  esac
done
[ -z "$PORT" ] && syntax
[ -n "$FQDN" -a -z "$TYPE" ] && TYPE="A"

# 设置临时文件
tmpJSON="/tmp/awscli.json"
check_command
remove_floatIP
aws ec2 describe-instances >$tmpJSON
INST=$(cat $tmpJSON |jq  '.[]'|jq  -r '.[] | .Instances' |jq -r '.[] | .InstanceId')
OLDIP=$(cat $tmpJSON |jq  '.[]'|jq  -r '.[] | .Instances' |jq -r '.[] | .PublicIpAddress')
AllocId=$(aws ec2 describe-addresses --public-ips $OLDIP|jq -r '.Addresses[] | .AllocationId')

if [ -n "${OLDIP}" ];then
	echo "实例 $INST 当前的 IP 为 ${OLDIP} 分配到 $AllocId"
	check_port
	replace_ip
else
	echo "实例 $INST 当前没有分配公网 IP 地址"
	add_ip 
fi
[ -f "$tmpJSON" ] && rm $tmpJSON
echo "当前分配的所有地址："
aws ec2 describe-addresses 
