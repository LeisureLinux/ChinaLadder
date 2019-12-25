#!/bin/bash
# 添加 Proftpd 的数据库用户
# 参考 URL： https://tech.yj777.cn/centos7%e4%b8%8a-proftpd-%e6%94%af%e6%8c%81-mysql-%e8%99%9a%e6%8b%9f%e7%94%a8%e6%88%b7%e5%8a%a0%e5%af%86%e8%ae%a4%e8%af%81%e4%bb%a5%e5%8f%8a%e7%a3%81%e7%9b%98%e9%99%90%e9%a2%9dquota/
# 版权： 徐永久 @上海甬洁网络科技有限公司
# QQ: 8122093
# mkpasswd 命令需要安装  expect 软件包
# 请修改脚本里的数据库对应的配置
# 最近更新： 2019-12-25

usage () {
        echo ""
        echo "  USAGE: $0 username user_home_dir "
        echo "  e.g.: $0 albertxu /opt/ftphome/albertxu "
        echo ""
        echo "  Result:"
        echo "          UserName: albertxu"
        echo "          PassWord: N2Jy3Fqol"
        echo ""
	exit
}

# ==== MySQL ================================
MYSQL_USER=ftpd
MYSQL_PASS=YourMySQLDB_PASS
MYSQL_DB=ftpd
MYSQL_HOST=localhost
# ====请根据自己的情况修改以上数据库的配置====
FTP_USER=ftpuser
FTP_UID=`id -u ${FTP_USER}`
FTP_GID=`id -g ${FTP_USER}`
FTP_GRP=`id -gn ${FTP_USER}`
# ===============
userid=$1
[ -z "${userid}" ] && usage 
datetime=$(date +"%Y-%m-%d %H:%M:%S")
passwd=$(mkpasswd -l 9 -d 2 -c 3 -C 3 -s 1)
FTP_HOME=/opt/ftphome/${userid}

[ ! -d ${FTP_HOME} ] && mkdir -p ${FTP_HOME} && chown ${FTP_USER}.${FTP_GRP} ${FTP_HOME}

dst_passwd='{md5}'$(/bin/echo -n "$passwd" | openssl dgst -binary -md5 | openssl enc -base64)
shell='/sbin/nologin'
/bin/mysql -u ${MYSQL_USER} -p${MYSQL_PASS} -h ${MYSQL_HOST} ${MYSQL_DB}  \
	-e "INSERT INTO ftpuser (userid,passwd,uid,gid,homedir,shell,accessed) \
	VALUES ('$userid','$dst_passwd',${FTP_UID},${FTP_GID},'${FTP_HOME}','/sbin/nologin','$datetime')"
echo "UserName: $userid"
echo "PassWord: $passwd"
echo "userHome: ${FTP_HOME}"
echo 
