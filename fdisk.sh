#/bin/bash
#DISK_COUNTS=`fdisk -l|grep ^Disk|wc -l`
#while [ $DISK_COUNTS -gt 1 ];do
#     DISK_LISTS=`fdisk -l|grep ^Disk|cut -c6-13`
# echo -ne "\033[30;32m \n\nThese disks are available for use:\n$DISK_LISTS\n\n \033[0m"



fdisk  /dev/sdb << EOF
n
p
1


w
q
EOF
sleep 10

mkfs.ext4 /dev/sdb1

blkid /dev/sdb1 | awk -F '"' '{print "UUID="$2,"/data                   ext4    defaults        1 2"}' >> /etc/fstab

mount /dev/sdb1 /data/



