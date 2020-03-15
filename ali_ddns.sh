#!/bin/bash
# 通过阿里云 aliyun cli 操作 阿里云 DNS 域名
# 作者：甬洁网络 <https://www.yj777.cn> 
# 语法：ali_ddns.sh record domain 
# 例如：在家里的路由器上定时跑 ali_ddns.sh home abcd.com 
#   就可以通过 home.abcd.com 访问家里的设备

getAllDomain () {
	$DNS DescribeDomains|jq '.Domains.Domain' |jq '.[].DomainName'
}

addRR () {
  # 添加记录
  local rr=$1
  local domain=$2
  local type=$3
  local value=$4
  local rrID=$(checkRR $domain $rr)
  [ -n "$rrID" ] && echo "记录 $rr.$domain 已经存在!" && return
  $DNS AddDomainRecord --DomainName $domain --RR $rr  --Type $type --Value $value
}

updateRR () {
  # 更新记录
  local rr=$1
  local domain=$2
  local type=$3
  local value=$4
  [ -z "$value" ] && echo "Wrong parameter" && return
  local rrID=$(checkRR $domain $rr)
  # 不存在则添加记录
  [ -z "$rrID" ] && addRR $rr $domain $type $value && echo "添加记录: $rr.$domain 为：$value" && return
  # 如果一样的 value 则不修改，直接调用 Update ，阿里会报错
  local rrValue=$(checkValue $domain $rr)
  [ "$rrValue" = "$value" ] && echo "$value 没有变动，无需更新记录" && return
  # 否则修改记录值
  $DNS UpdateDomainRecord --RecordId --RR $rr  --Type $type --Value $value || \
  echo "记录: $rr.$domain 更新为：$value"
}

checkValue () {
  # 返回 Record Value
  local domain=$1
  local rr=$2
  $DNS DescribeDomainRecords --DomainName $domain|jq '.DomainRecords.Record' \
	   |jq ".[] |select(.RR == \"$rr\")" | jq -r '.Value'
}

checkRR () {
  # 检查记录是否已经存在,返回 RecordId
  local domain=$1
  local rr=$2
  $DNS DescribeDomainRecords --DomainName $domain|jq '.DomainRecords.Record' \
	   |jq ".[] |select(.RR == \"$rr\")" | jq -r '.RecordId'
}

delRR () {
   local domain=$1
   local rr=$2
   local rrID=$(checkRR $domain $rr)
   [ -n "$rrID" ] && ( echo "记录: $rr.$domain 删除结果：" && $DNS DeleteDomainRecord --RecordId $rrID ) \
	   || echo "记录： $rr.$domain 不存在"
}

# ###########
# aliyun --profile default alidns DescribeDomains|jq '.Domains.Domain' |jq '.[]'>alldomain.txt
# certbot certonly --manual --preferred-challenges dns --server https://acme-v02.api.letsencrypt.org/directory -d ${DOMAIN}
# rr="_acme-challenge"
# ###########
# Main Prog.
# ###########
rr="$1"
domain="$2"
profile="$3"
[ -z "$profile" ] && profile="default"
RE=$(aliyun configure get region -p "$profile")
[ $? != 0 -o "$RE" = "" ] && echo "aliyun cli 配置有问题" && exit 0
DNS="aliyun -p $profile alidns"
URL="https://ipv4bot.whatismyipaddress.com/"
IP=$(curl -sS $URL)
[ -z "$IP" ] && echo "Failed to get current IP" && exit 1
rrType="A"
updateRR $rr $domain $rrType $IP
