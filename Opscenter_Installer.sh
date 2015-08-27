#!/bin/bash

# *************************************************************************
# Author      : Mohammed Khusro Siddiqui
# Title       : Opscenter Installer
# Description : Install and configure Opscenter and its pre-requisites
# *************************************************************************

# Variables
opscenter_hostname=opscenter
datastax_username="<Enter Datastax Username>"
datastax_password="<Enter Datastax Password"
ipaddr=`hostname -I`
reponame=datastax
url=http://$datastax_username:$datastax_password@rpm.datastax.com/enterprise

# File Paths
ops=/etc/opscenter
ntp=/etc/ntp.conf

# Installing NTP 
echo " ***************** Checking if NTP is installed ***************** "
NTP_TEST=`sudo rpm -qa | grep ntp | wc -l`

if [ $NTP_TEST -eq 0 ]; then

  echo " ************************ Installing NTP ************************* "
  sudo yum clean all
  sudo yum install ntp -y

else
  echo " ******************* NTP is already installed ******************** "
fi

# Configuring and Starting NTP
echo " ***************** NTP installed. Configuring... ***************** "
server=$(cat $ntp | grep 'server 0' | cut -d' ' -f2)
ntpdate $server
/etc/init.d/ntpd start
/sbin/chkconfig ntpd on
echo " ************************ NTP configured ************************* "

# Installing and configuring Oracle JDK 1.8.0_45
echo " ***************** Checking if Java is installed ***************** "
java -version > /dev/null 2>&1
ret=$?
if [ $ret -ne 0 ];then

  echo " ****************** Installing Oracle JDK 1.8.0_45 ***************** "
  cd /usr
  sudo mkdir -p java
  cd java
  sudo wget --no-cookies --no-check-certificate --header "Cookie: oraclelicense=accept-securebackup-cookie" "http://download.oracle.com/otn-pub/java/jdk/8u45-b14/server-jre-8u45-linux-x64.tar.gz" -O "server-jre-8u45-linux-x64.tar.gz"

  sudo tar -xzf server-jre-8u45-linux-x64.tar.gz
  sudo rm -f server-jre-8u45-linux-x64.tar.gz
  sudo ln -s /usr/java/jdk1.8.0_45 latest
  sudo ln -s /usr/java/latest default

  # Installing JNA
  echo " ************************** Installing JNA ************************* "
  sudo yum install jna -y
  cd
else
  echo " ******************* JDK is already installed ********************** " 
fi

# Installing Opscenter
  echo " **************** Checking for Opscenter Installation ************** "
OPS_TEST=`sudo rpm -qa | grep opscenter | wc -l`

if [ ! -f /usr/share/opscenter ] && [ $OPS_TEST -eq 0 ];then

  # Creating Datastax Repo
  echo " **** Adding Datastax Repositoy for Username: $datastax_username **** "
  sudo touch /etc/yum.repos.d/$reponame.repo
  sudo chmod a+w /etc/yum.repos.d/$reponame.repo
  sudo echo -e "[$reponame]\nbaseurl=${url}\nenabled=1\ngpgcheck=0\nname=ISO" > /etc/yum.repos.d/$reponame.repo
  sudo chmod 644 /etc/yum.repos.d/$reponame.repo

  echo " *********************** Installing Opscenter *********************** "
  sudo yum clean all
  sudo yum -y install opscenter
  echo " ************************ Opscenter installed *********************** "

  echo " ********* Setting Java alterntives to use installed version ******** "
  sudo alternatives --install /usr/bin/java java /usr/java/jdk1.8.0_45/jre/bin/java 20000
  sudo alternatives --set java /usr/java/jdk1.8.0_45/jre/bin/java
  echo " **************** Opscenter installed. Configuring... *************** "
  cat >> $ops/opscenterd.conf <<EOF
[agents]
incoming_interface = $ipaddr
#
#
interval = 0
EOF
  sed -i "s/interface = 0.0.0.0/interface = $ipaddr/" $ops/opscenterd.conf
  echo " ******************* Starting Opscenter service... ****************** "
  service opscenterd start
  sleep 2
  echo " ********************** Opscenter Service Status ******************** "
  service opscenterd status
else
  echo " ****************** Opscenter is already installed ****************** "
fi

# Adding Hostname
cat >> /etc/hosts <<EOF
$ipaddr $opscenter_hostname.cloudwick.com $opscenter_hostname   
EOF
hostname $opscenter_hostname
bash
