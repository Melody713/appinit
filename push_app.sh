#!/bin/bash
#update 2017.03.08

dir=/data/SicentTools/script_update
ftp_path=downloads/Tools
file1=app-environment_autoinstall.sh
file2=app-environment_autoinstall.md5
md5sum $file1 > $file2

cd $dir
  echo "[开始上传]"
  /usr/bin/lftp -u 'sa','sa!121' 10.34.38.215/$ftp_path -e "put $file1 ;exit"
  /usr/bin/lftp -u 'sa','sa!121' 10.34.38.215/$ftp_path -e "put $file2 ;exit"
  echo "[上传完成]"

