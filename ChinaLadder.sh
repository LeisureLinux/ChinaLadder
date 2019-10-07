#!/bin/bash
# 用 AWS CLI 动态修改 EC2 IP 地址

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
	echo "检查多余的 IP ..."
	aws ec2 describe-addresses >/dev/null
	[ $? != 0 ] && echo "看上去执行 aws 命令有错啊！先跑一下 aws configure 命令吧！" && exit 10
	for i in $(seq 0 9)
	do
		OLDIP=$(jq ".Addresses[$i]" $ADDR|jq -r '.PublicIp')
		[ "$OLDIP" == "null" ] && break
		AllocId=$(jq ".Addresses[$i]" $ADDR|jq -r '.AllocationId')
		INST=$(jq ".Addresses[$i]" $ADDR|jq -r '.InstanceId')
		[ "$INST" == "null" ] && release_ip
	done
}

check_port () {
	nc -4 -w 2 $OLDIP ${PORT}
	[ $? == 0 ] && echo "看上去是好的啊！" && exit 99
}

check_command () {
	for cmd in jq nc aws;do
		which $cmd >/dev/nulll
		[ $? != 0 ] && echo "命令 $cmd 不存在，请检查！" && exit 1
	done
}

# Main Prog.
# 本程序用于自动更换 EC2 实例的公网 IP 地址
# 运行本脚本前先运行 aws configure 命令，根据要求配置好密码
# https://docs.amazonaws.cn/cli/latest/userguide/cli-chap-configure.html#cli-quick-configuration
# 本脚本仅用于 bash 环境
# 如果需要 Windows 上使用请参考文章：
# https://tech.yj777.cn/cygwin-%e6%b8%85%e5%8d%8e%e9%95%9c%e5%83%8f/
# 安装 Cygwin ，再参照 AWS CLI 手册安装 Windows 上的 AWS CLI
# https://docs.amazonaws.cn/cli/latest/userguide/install-windows.html
# 
# 这个 PORT 是你自己的 SS 侦听的端口，要根据你自己的配置设定
# 本程序肯定是定期执行，譬如每 5 分钟检查端口被封情况
# -- Todo: GoDaddy DNS 自动注册
#
PORT=2019
ADDR="/tmp/awscli.json"
check_command
remove_floatIP
aws ec2 describe-instances >$ADDR
INST=$(cat $ADDR |jq  '.[]'|jq  -r '.[] | .Instances' |jq -r '.[] | .InstanceId')
OLDIP=$(cat $ADDR |jq  '.[]'|jq  -r '.[] | .Instances' |jq -r '.[] | .PublicIpAddress')
AllocId=$(aws ec2 describe-addresses --public-ips $OLDIP|jq -r '.Addresses[] | .AllocationId')

if [ -n "${OLDIP}" ];then
	echo "实例 $INST 当前的 IP 为 ${OLDIP} 分配到 $AllocId"
	check_port
	replace_ip
else
	echo "实例 $INST 当前没有分配公网 IP 地址"
	add_ip 
fi
echo "当前分配的所有地址："
aws ec2 describe-addresses 
