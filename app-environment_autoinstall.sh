#!/bin/bash
#Auto Install Application
#version 1.6.5
#update 2017.06.30
#By YPC
remote_file="Tools/app-environment_autoinstall.sh"
remote_file_md5="Tools/app-environment_autoinstall.md5"
scp_name="app-environment_autoinstall"
#local_file_md5="app-environment_autoinstall.md5"

webdir=/data/SicentWebserver
appdir=/data/SicentApp
toolsdir=/data/SicentTools
dbdir=/data/SicentDB
logdir=/data/appinstall.log

#check net_type
default_route=$(ip route show)
default_interface=$(echo $default_route | sed -e 's/^.*dev \([^ ]*\).*$/\1/' | head -n 1)
address=$(ip addr show label $default_interface scope global | awk '$1 == "inet" { print $2,$4}')

#ip address 
ip=$(echo $address | awk '{print $1 }')
ip=${ip%%/*}

net_type=`echo $ip|cut -d . -f 1-2`

if [ $net_type = "10.34" ]
  then
    ftp_url='http://10.34.38.215:12124'
elif [ $net_type = "172.30" ]
 then
    ftp_url='http://tools.js-ops.com:12124'
else
  ftp_url='http://tools.js-ops.com:12124'
fi

echo "脚本自动更新已关闭"
#check scp_version
#echo "检查是否有新版本"
#rm -rf $scp_name.md5
#rm -rf $scp_name.local.md5
#wget $ftp_url/$remote_file_md5 -q
#md5sum $scp_name.sh>$scp_name.local.md5
#diff -r $scp_name.md5 $scp_name.local.md5
#if [ $? -ne 0 ]
#  then
#    echo "发现新版本,现在开始下载更新"
#    rm -rf $scp_name.sh
#    wget $ftp_url/$remote_file -q
#    chmod +x $scp_name.sh
#    if [ -x $scp_name.sh ]
#      then
#        echo "脚本更新检查完毕"
#    else
#       echo "脚本更新失败,请尝试从以下地址手动获取"
#       echo "$remote_file"
#    fi
#       echo "请重新执行脚本,已确保使用到最新版本"
#       exit 0
#  else
#   echo "脚本已是最新"
#fi

echo "-----------------------------------------------------------------------"

#Check basic_dir
function basic_dir () {
	ls -l $webdir && ls -l $toolsdir ls -l $appdir
	if [ $? -eq 0 ]
	then
        	echo -e "\e[1;32m规范目录已存在\e[0m"
	else
        	echo -e "\e[1;32m规范目录不存在,正在创建\e[0m"
	        mkdir -pv $webdir && mkdir -pv $toolsdir && mkdir -pv $appdir
	fi
}

#install basic_env
function basic_env () {
  rpm -qa|grep wget && rpm -qa|grep make && rpm -qa|grep gcc && rpm -qa|grep lftp > /dev/null
  if [ $? -eq 1 ]
  then
	yum -y install zlib-devel openssl-devel perl net-snmp lsof wget ntpdate make gcc gcc-c++ ncurses* telnet ftp openssh-clients vim lrzsz ntpdate
	rpm -qa|grep epel > /dev/null
	if [ $? -eq 1]
	then
		rpm -Uvh $ftp_url/Tools/Linux/epel-release-6-8.noarch.rpm
    yum --disablerepo=epel -y update ca-certificates
	fi
	echo -e "\e[1;32m基础环境已更新\e[0m"
  fi
}

function selinux () {
	setenforce 0
	sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
	echo -e "\e[1;32m已关闭Selinux\e[0m"
	/etc/init.d/iptables stop
	chkconfig iptables off
	echo -e "\e[1;32m已关闭Iptables\e[0m"
}

function ntp () {
	ntpdate t2.swomc.net
	echo "10 0 * * * /usr/sbin/ntpdate t2.swomc.net" > /tmp/ntp.cron
	crontab /tmp/ntp.cron
	echo -e "\e[1;32m时间已同步\e[0m"
}

function mnt_disk(){
	blkid /dev/sdb1 | awk -F'"' '{print "UUID="$2,"/data                   ext4    defaults        1 2"}' >> /etc/fstab
}

function jdk () {
JAVADIR=/data/SicentWebserver/jdk1.7.0_45
if [ ! -d $JAVADIR ]
then
  cat /etc/profile|grep "JAVA_HOME="|grep -v "#" > /dev/null
  if [ $? -eq 1 ]
  then 
    echo -e "\e[1;32m未发现JAVA,开始部署\e[0m"
    (
cat << EOF
JAVA_HOME=/data/SicentWebserver/jdk1.7.0_45
export JRE_HOME=/data/SicentWebserver/jdk1.7.0_45/jre
export CLASSPATH=.:\$JAVA_HOME/lib/dt.jar:\$JAVA_HOME/lib/tools.jar:\$JRE_HOME/lib:\$CLASSPATH
export PATH=\$JAVA_HOME/bin:\$JRE_HOME/bin:\$PATH
EOF
   )>>/etc/profile
   source /etc/profile
  fi
  wget $ftp_url/Tools/JDK/jdk1.7.0_45.tar.gz -P $toolsdir
  tar zxf $toolsdir/jdk1.7.0_45.tar.gz -C $webdir
else
  cat /etc/profile|grep "JAVA_HOME="|grep -v "#" > /dev/null
  if [ $? -eq 0 ]
  then
  echo -e "\e[1;32mJAVA环境已部署,无需重新部署\e[0m"
else
   (
cat << EOF
JAVA_HOME=/data/SicentWebserver/jdk1.7.0_45
export JRE_HOME=/data/SicentWebserver/jdk1.7.0_45/jre
export CLASSPATH=.:\$JAVA_HOME/lib/dt.jar:\$JAVA_HOME/lib/tools.jar:\$JRE_HOME/lib:\$CLASSPATH
export PATH=\$JAVA_HOME/bin:\$JRE_HOME/bin:\$PATH
EOF
   )>>/etc/profile
   source /etc/profile
  fi
source /etc/profile
echo -e "\e[1;32m目前Java版本为:\e[0m"
java -version
if [ $? -eq 1 ]
then
  echo -e "\e[1;32mJAVA部署失败\e[0m"
fi
fi
}

#insatll tomcat
function install_tomcat () {
	ls -l $webdir/apache-tomcat
	if [ $? -eq 0 ]
	then
		echo -e "\e[1;32mTomcat服务已安装\e[0m"
	else
		echo -e "\e[1;32mTomcat服务未安装,开始安装Tomcat\e[0m"
		wget $ftp_url/Tools/ApacheTomcat/apache-tomcat-7.0.53.tar.gz -P $toolsdir/
		tar zxf $toolsdir/apache-tomcat-7.0.53.tar.gz -C $webdir/
		mv $webdir/apache-tomcat-7.0.53 /$webdir/apache-tomcat
		chmod 755 $webdir/apache-tomcat/bin/*.sh
	fi
#check tomcat
	$webdir/apache-tomcat/bin/startup.sh
	if [ $? -eq 0 ]
	then
		echo -e "\e[1;32mTomcat启动成功\e[0m"
	else
		echo -e "\e[1;31mTomcat启动失败\e[0m"
		exit
	fi
}

#install nginx
function install_nginx () {
	ls -l $webdir/nginx
	if [ $? -eq 0 ]
	then
		echo -e "\e[1;32mNginx服务已安装\e[0m"
	else
		echo -e "\e[1;32mNginx未安装,开始安装Nginx\e[0m"
		wget $ftp_url/Tools/Nginx/nginx-1.5.8.tar.gz -P $toolsdir/
		wget $ftp_url/Tools/Nginx/pcre-8.36.tar.gz -P $toolsdir/
		cd $toolsdir
		tar -zxf nginx-1.5.8.tar.gz
		tar -zxf pcre-8.36.tar.gz
		cd $toolsdir/nginx-1.5.8
		./configure --prefix=$webdir/nginx --with-pcre=$toolsdir/pcre-8.36 --with-http_stub_status_module
		make && make install
		$webdir/nginx/sbin/nginx
	fi
#check nginx
	nginx=$(/bin/ps "-ef" |grep nginx|awk '{print $11}'|head -1|awk -F '/' '{print $6}')
	if  [ $nginx=nginx ]
	then
		echo -e "\e[1;32mNginx启动成功\e[0m"
	else
		echo -e "\e[1;31mNginx启动失败\e[0m"
	fi
}

function mysql () {
	mysqlpid=$(pidof mysqld)
	if [ ! -z "$mysqlpid" ]
	then
		echo -e "\e[1;32mMYSQL服务已安装,且已在运行\e[0m"
	else
		echo -e "\e[1;32mMYSQL服务未安装,开始安装MYSQL\e[0m"
		yum -y install sysstat cmake flex bison autoconf automake bzip2-devel ncurses-devel zlib-devel libjpeg-devel libpng-devel libtiff-devel freetype-devel libXpm-devel gettext-devel pam-devel libtool libtool-ltdl openssl openssl-devel fontconfig-devel libxml2-devel curl-devel libicu libicu-devel
		checkrc=$(cat /etc/rc.local|grep '^ulimit -SHn 65535')
		if [ ! -z "$checkrc" ]
		then
			echo "ulimit has been setted in /etc/rc.local"
		else
			echo "ulimit -SHn 65535" >> /etc/rc.local
		fi
		checkprofile=$(cat /etc/profile|grep '^ulimit -SHn 65535')
		if [ ! -z "$checkprofile" ]
		then
			echo "ulimit has been setted in /etc/profile"
		else
			echo "ulimit -SHn 65535" >> /etc/profile
		fi
		checklimit=$(cat /etc/security/limits.conf|grep '^* soft nofile 65535')
		if [ ! -z "$checklimit" ]
		then
			echo "ulimit has been setted in /etc/security/limits.conf"
		else
(
cat << EOF
* soft nofile 65535
* hard nofile 65535
EOF
)>>/etc/security/limits.conf
		fi
		groupadd mysql
		useradd -r -g mysql -s /sbin/nologin mysql
		mkdir -pv /data/SicentDB/{mysql,tmp_db,database}
		chown -R mysql:mysql $dbdir/
		wget $ftp_url/Tools/Mysql/mysql-5.5.27.tar.gz -P $toolsdir
		cd $toolsdir/
		tar zxf mysql-5.5.27.tar.gz -C $dbdir/
		cd $dbdir/mysql-5.5.27
		cmake -DCMAKE_INSTALL_PREFIX=$dbdir/mysql -DMYSQL_DATADIR=$dbdir/database -DDEFAULT_CHARSET=utf8 -DDEFAULT_COLLATION=utf8_unicode_ci -DWITH_READLINE=1 -DWITH_SSL=system -DWITH_EMBEDDED_SERVER=1 -DENABLED_LOCAL_INFILE=1 -DDEFAULT_COLLATION=utf8_general_ci -DWITH_MYISAM_STORAGE_ENGINE=1 -DWITH_INNOBASE_STORAGE_ENGINE=1 -DWITH_DEBUG=0
		make && make install
		mv /etc/my.cnf /etc/my.cnf.bak
		wget $ftp_url/Tools/Mysql/my.cnf -P /etc/
		$dbdir/mysql/scripts/mysql_install_db --user=mysql --basedir=$dbdir/mysql/ --datadir=$dbdir/database
		echo "PATH=\$PATH:\$HOME/bin:/data/SicentDB/mysql/bin:/data/SicentDB/mysql/lib">>/etc/profile
		source /etc/profile
		cp $dbdir/mysql/support-files/mysql.server /etc/init.d/mysql
		/etc/init.d/mysql start
	fi
#check mysql
	PID=$(pidof mysqld)
	if [ ! -z "$PID" ]
	then
		echo -e "\e[1;32mMYSQL服务已启动\e[0m"
	else
		echo -e "\e[1;31mMYSQL服务启动失败,请检查安装日志\e[0m"
	fi
}

function redis() {
  REDISDIR=/data/SicentApp/redis-2.8.10
  if [ ! -d $REDISDIR ]
  then
    ps -ef|grep redis|grep -v grep > /dev/null
    if [ $? -eq 1 ]
    then
      mkdir -p $appdir
      cd $toolsdir
      wget $ftp_url/Tools/Redis/Redis-2.8.10.tar.gz
      wget $ftp_url/Tools/Redis/redis_scripts.tar.gz
      tar zxf redis_scripts.tar.gz
      chmod +x $toolsdir/redis_start.sh
	    cp $toolsdir/redis_start.sh /etc/init.d/redis
      tar zxf $toolsdir/Redis-2.8.10.tar.gz -C $appdir
      cd $appdir/redis-2.8.10
      make
      make install
      sed -i "s/daemonize.*/daemonize yes/g" $appdir/redis-2.8.10/redis.conf
      /etc/init.d/redis start
    else
      echo -e "\e[1;32m已有Redis服务正在运行,无需再次部署\e[0m"
      exit
    fi
  else
    ps -ef|grep redis |grep -v grep> /dev/null
    if [ $? -eq 0 ]
    then
      echo -e "\e[1;32mRedis已按规范部署,服务运行中\e[0m"
      echo -e "\e[1;32mRedis启动脚本: /etc/init.d/redis\e[0m"
    else
      echo -e "\e[1;32mRedis已按规范部署,服务未启动\e[0m"
      echo -e "\e[1;32mRedis启动脚本: /etc/init.d/redis\e[0m"
    fi
  fi
}

function rabbitmq() {
		cd $appdir
		wget http://www.rabbitmq.com/releases/rabbitmq-server/v3.4.2/rabbitmq-server-3.4.2-1.noarch.rpm
		rpm --import http://www.rabbitmq.com/rabbitmq-signing-key-public.asc
		yum -y install rabbitmq-server-3.4.2-1.noarch.rpm
		echo RABBITMQ_NODE_PORT=21057 > /etc/rabbitmq/rabbitmq-env.conf
		echo [{rabbitmq_management,[{listener,[{port, 21058}]}]}]. > /etc/rabbitmq/rabbitmq.config
		/etc/init.d/rabbitmq-server start
		rabbitmq-plugins enable rabbitmq_management
		rabbitmqctl add_user sicent sicent
		rabbitmqctl add_vhost sicent_vhost
		rabbitmqctl set_permissions -p sicent_vhost sicent ".*" ".*" ".*"
#		rabbitmqctl set_user_tags sicent administrator
		rabbitmqctl add_user rbt_monitor rbt_monitor
		rabbitmqctl set_permissions -p sicent_vhost rbt_monitor ".*" ".*" ".*"
		rabbitmqctl set_user_tags rbt_monitor administrator
}

function salt_online() {
		cd /root/
		rpm -Uvh http://ftp.linux.ncsu.edu/pub/epel/6/i386/epel-release-6-8.noarch.rpm
		yum update -y python 
		yum install -y salt-minion
		chkconfig salt-minion on
		echo "输入主机ID,例: 172.30.1.138_qdd_servicemix"
		read id
		echo "id: $id" >> /etc/salt/minion
		echo "master: auth.salt.js-ops.com" >> /etc/salt/minion
		service salt-minion start
		echo "Slat客户端安装完成,请登录salt-master完成客户端认证"
}

function salt_yfb() {
    cd /root/
    rpm -Uvh http://ftp.linux.ncsu.edu/pub/epel/6/i386/epel-release-6-8.noarch.rpm
		yum update -y python
    yum install -y salt-minion
    chkconfig salt-minion on
    echo "输入主机ID,例: 172.30.1.138_qdd_servicemix"
    read id
    echo "id: $id" >> /etc/salt/minion
    echo "master: 10.34.38.64" >> /etc/salt/minion
    service salt-minion start
    echo "Slat客户端安装完成,请登录salt-master完成客户端认证"
}

function zabbix() {
ZABBIX_PKG=zabbix-3.0.3.tar.gz
ZABBIX_CONF=/etc/zabbix/zabbix_agentd.conf

if [ ! -f /etc/init.d/zabbix_agentd ]
then
/usr/bin/lftp 172.30.134.249 -p 2122 -u 'sa,js!HZ!121' -e "cd Tools/linux && get zabbix-3.0.3.tar.gz ;exit"
if [ -f /root/$ZABBIX_PKG  ]
  then
  tar zxf /root/$ZABBIX_PKG -C /root/
  cd /root/zabbix-3.0.3/
  ./configure --prefix=/usr/local/zabbix --enable-agent
  make && make install
  ln -s /usr/local/zabbix/sbin/* /usr/local/sbin/
  ln -s /usr/local/zabbix/bin/* /usr/local/bin/
  ln -s /usr/local/zabbix/etc/ /etc/zabbix
  cp /root/zabbix-3.0.3/misc/init.d/tru64/zabbix_agentd /etc/init.d/zabbix_agentd
  chmod +x /etc/init.d/zabbix_agentd
  else
  echo "$ZABBIX_PKG NOT FOUND"
  exit
fi
  /usr/sbin/groupadd zabbix
  /usr/sbin/useradd zabbix -g zabbix
if [ ! -d /var/log/zabbix  ]
  then
    mkdir -pv /var/log/zabbix
    chown -R zabbix:zabbix /var/log/zabbix
fi

if [ ! -d /etc/zabbix/scripts ]
  then
    mkdir -pv /etc/zabbix/scripts
fi

if [ ! -d /etc/zabbix/alertscripts ]
  then
    mkdir -pv /etc/zabbix/alertscripts
fi

  sed -i "s/LogFile=.*/LogFile=\/var\/log\/zabbix\/zabbix_agentd.log/g" $ZABBIX_CONF
  #sed -i "s/Server=127.0.0.1/Server=172.30.134.106/g" $ZABBIX_CONF
  echo -e "\e[1;32m输入ZABBIX服务端IP,多个IP使用逗号分隔\e[0m" 
  read ZABBIX_SERVER_IP
  sed -i "s/Server=127.0.0.1/Server=$ZABBIX_SERVER_IP/g" $ZABBIX_CONF
  echo "Include=/etc/zabbix/scripts/*.conf" >> $ZABBIX_CONF
  /etc/init.d/zabbix_agentd restart 
else
  echo "Zabbix已安装,无需部署"
fi

}

function useradd() {
cat /etc/passwd|grep devs>/dev/null
if [ $? -eq 1 ]
  then
  /usr/sbin/useradd -p "aPApguhdYP2ks" devs
  echo "devs账号已创建"
else
  echo "devs账号已存在"

fi
cat /etc/passwd|grep ops>/dev/null
if [ $? -eq 1 ]
then
  /usr/sbin/useradd -p "6Jn8XyRkaMcQQ" ops
  echo "ops账号已创建"
else
  echo "ops账号已存在"
fi

}


echo -e "\e[1;32m选择要安装的服务类型,目前支持以下项目:\e[0m"
echo -e "\e[1;36m(1): 创建规范目录,安装基础库环境,关闭selinux,关闭iptables,配置时间同步
(2): 部署Tomcat-7.0.53,JDK-1.7.0_45
(3): 部署Nginx-1.5.8,PCRE-8.36
(4): 部署Mysql-5.5.27
(5): 部署Redis-2.8.10
(6): 部署Rabbitmq-3.4.2.1
(7): 部署salt客户端(线上环境)
(8): 部署salt客户端(测试环境)
(9): 部署JDK环境(JDK-1.7.0_45)
(z): 部署Zabbix 3.0.3客户端
(u): 添加devs和ops账号
(q): 退出\e[0m"

echo -e "\e[1;32m请输入序号:\e[0m"
read options

function main ()
{
	case "$options" in
	1)
		basic_dir
		basic_env
		selinux
		ntp
		echo -e "\e[1;32m基础环境安装完毕\e[0m"
		cd /root
		sh app-environment_autoinstall.sh
		;;
	2)
		basic_dir
		basic_env
		jdk
		install_tomcat
		echo -e "\e[1;32mTOMCAT安装完毕\e[0m"
		cd /root
		sh app-environment_autoinstall.sh
		;;
	3)
		basic_dir
		basic_env
		install_nginx
		echo -e "\e[1;32mNginx安装完毕\e[0m"
		cd /root
		sh app-environment_autoinstall.sh
		;;
	4)
		basic_dir
		basic_env
		mysql
		echo -e "\e[1;32mMYSQL安装完毕\e[0m"
		cd /root
		sh app-environment_autoinstall.sh
		;;
	5)
		basic_dir
		basic_env
		redis
		echo -e "\e[1;32mREDIS安装完毕\e[0m"
		cd /root
		sh app-environment_autoinstall.sh
		;;
	6)
		basic_dir
		basic_env
		rabbitmq
		echo -e "\e[1;32mRabbitMQ安装完毕\e[0m"
		cd /root
		sh app-environment_autoinstall.sh
		;;
	7)
		basic_dir
		basic_env
		salt_online
		echo -e "\e[1;32msalt客户端安装完毕\e[0m"
		cd /root
		sh app-environment_autoinstall.sh
		;;
	8)
		basic_dir
    basic_env
    salt_yfb
		echo -e "\e[1;32msalt客户端安装完毕\e[0m"
		cd /root
		sh app-environment_autoinstall.sh
		;;
	9)
		jdk
		cd /root
		sh app-environment_autoinstall.sh
		;;
  z)
    zabbix
		cd /root
    sh app-environment_autoinstall.sh
    ;;
  u)
    useradd
    cd /root
    sh app-environment_autoinstall.sh
    ;;
	q)
		exit
		;;
	*)
		echo -e "\e[1;31m请输入正确的选项\e[0m"
		sh app-environment_autoinstall.sh
	esac
}

main $@
exit $?
