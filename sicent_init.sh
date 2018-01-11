#!/bin/bash
#Always get newest app_init_scp from ftp
#Date: 2017.12.25
#Auther: Yupengcheng

#check net_type
default_route=$(ip route show)
default_interface=$(echo $default_route | sed -e 's/^.*dev \([^ ]*\).*$/\1/' | head -n 1)
address=$(ip addr show label $default_interface scope global | awk '$1 == "inet" { print $2,$4 }')

#ip address 
ip=$(echo $address | awk '{print $1 }')
ip=${ip%%/*}

net_type=`echo $ip|cut -d . -f 1-2`

if [ $net_type = "10.34"  ]
then
  FTP_URL='http://10.34.38.215:12124'
elif [ $net_type = "172.30"  ]
then
  FTP_URL='http://tools.js-ops.com:12124'
else
  FTP_URL='http://tools.js-ops.com:12124'
fi


LOCALDIR=$(cd "$(dirname "$0")"&& pwd)
APPSCP="app-environment_autoinstall.sh"
SOURCEURL="$FTP_URL/Tools/init/app-environment_autoinstall.sh"
MD5URL="$FTP_URL/Tools/init/app-environment_autoinstall.md5"
NEWMD5=`curl -s $MD5URL|awk -F " " {'print $1'}`


function GET_SCP() {
    wget -q $SOURCEURL
    if [ $? -eq 0 ]
    then
    echo "更新完毕"
    chmod +x $LOCALDIR/$APPSCP
    sh $LOCALDIR/$APPSCP
    else
      echo "更新失败,请手动尝试从以下地址获取最新脚本"
      echo "$SOURCEURL"
    fi
}

clear


if [ -f $LOCALDIR/$APPSCP ]
then
LOCALMD5=`md5sum $LOCALDIR/$APPSCP|awk -F " " {'print $1'}`
  #check MD5
  if [ $LOCALMD5 = $NEWMD5 ]
  then
    echo "脚本已是最新"
    sh $LOCALDIR/$APPSCP
  else
    echo "发现新脚本,开始更新"
    rm -rf $LOCALDIR/$APPSCP
    GET_SCP
  fi
else
 GET_SCP
fi
