#!/bin/bash
#update 2017.03.08
#update 2017.12.25
#add sicent_init.sh

dir=/data/SicentTools/script_update
ftp_path=downloads/Tools/init
file1=app-environment_autoinstall.sh
file2=app-environment_autoinstall.md5
file3=sicent_init.sh
md5sum $file1 > $file2
md5sum $file3 > $file3.md5

cd $dir
  echo "[开始上传]"
  /usr/bin/lftp -u 'sa','sa!121' 10.34.38.215/$ftp_path -e "put $file1 ;exit"
  /usr/bin/lftp -u 'sa','sa!121' 10.34.38.215/$ftp_path -e "put $file2 ;exit"
  /usr/bin/lftp -u 'sa','sa!121' 10.34.38.215/$ftp_path -e "put $file3 ;exit"
  /usr/bin/lftp -u 'sa','sa!121' 10.34.38.215/$ftp_path -e "put $file3.md5 ;exit"
  echo "[上传完成]"

