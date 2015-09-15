#!/bin/bash

function partition (){

  sudo mkdir -p /mnt/data
  sudo mkdir -p /mnt/commitlog
  (/bin/echo n; /bin/echo p; /bin/echo ;/bin/echo ;/bin/echo ;/bin/echo w) | sudo /sbin/fdisk /dev/xvdc
  (/bin/echo n; /bin/echo p; /bin/echo ;/bin/echo ;/bin/echo ;/bin/echo w) | sudo /sbin/fdisk /dev/xvdb
  sudo mkfs.ext4 /dev/xvdc
  sudo mkfs.ext4 /dev/xvdb
  sudo mount -t ext4 /dev/xvdc /mnt/commitlog
  sudo mount -t ext4 /dev/xvdb /mnt/data
}

function add_fstab () {
  SDC_UUID=`sudo blkid /dev/xvdc | cut -d "=" -f2 | cut -d "\"" -f2`
  SDD_UUID=`sudo blkid /dev/xvdb | cut -d "=" -f2 | cut -d "\"" -f2`

  sudo echo "UUID=${SDC_UUID} /mnt/commitlog ext4 defaults 1 2
UUID=${SDD_UUID} /mnt/data ext4 nobarrier 1 2" >> /etc/fstab
}

partition
add_fstab
