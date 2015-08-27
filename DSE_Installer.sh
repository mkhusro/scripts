#!/bin/bash

# *************************************************************************
# Author 		: Mohammed Khusro Siddiqui
# Title			: DSE Installer
# Description	: Install and configure DSE and its pre-requisites
#*************************************************************************

# Variables
datastax_username="<Enter Datastax Username>"
datastax_password="<Enter Datastax Password>"
dse_version="<Enter version>"
reponame=datastax
url=http://$datastax_username:$datastax_password@rpm.datastax.com/enterprise
cluster_name=<Enter Cluster Name>
ip_addr=`hostname -I`
seed_ip=<Enter Seed IP>
opscenter_ip=<Enter Opscenter IP>

# File Paths
ntp=/etc/ntp.conf
path=/etc/dse/cassandra
address_path=/var/lib/datastax-agent/conf

# Installing NTP 
echo " ***************** Checking if NTP is installed **************** "
NTP_TEST=`sudo rpm -qa | grep ntp | wc -l`

if [ $NTP_TEST -eq 0 ]; then
  	
  	echo " ************************ Installing NTP *********************** "
  	sudo yum clean all
  	sudo yum install ntp -y

else
	echo " ******************* NTP is already installed ****************** "
fi

# Configuring and Starting NTP
echo " ***************** NTP installed. Configuring... ***************** "
server=$(cat $ntp | grep 'server 0' | cut -d' ' -f2)
ntpdate $server
/etc/init.d/ntpd start
/sbin/chkconfig ntpd on
echo " ************************ NTP configured ************************* "

# Installing and configuring Oracle JDK 1.8.0_45
echo " **************** Checking if Java is installed **************** "
java -version > /dev/null 2>&1
ret=$?
if [ $ret -ne 0 ];then
  	
  	echo " **************** Installing Oracle JDK 1.8.0_45 *************** "
  	cd /usr
  	sudo mkdir -p java
  	cd java
  	sudo wget --no-cookies --no-check-certificate --header "Cookie: oraclelicense=accept-securebackup-cookie" "http://download.oracle.com/otn-pub/java/jdk/8u45-b14/server-jre-8u45-linux-x64.tar.gz" -O "server-jre-8u45-linux-x64.tar.gz"

  	sudo tar -xzf server-jre-8u45-linux-x64.tar.gz
  	sudo rm -f server-jre-8u45-linux-x64.tar.gz
  	sudo ln -s /usr/java/jdk1.8.0_45 latest
  	sudo ln -s /usr/java/latest default

  	# Installing JNA
  	echo " ************************ Installing JNA *********************** "
  	sudo yum install jna -y
  	cd

else
  	echo " ***************** JDK is already installed ******************** " 
fi

# Installing DSE
echo " ***************** Checking for DSE Installation **************** "
DSE_TEST=`sudo rpm -qa | grep dse | wc -l`
if [ ! -f /usr/share/dse ] && [ $DSE_TEST -eq 0 ];then
    
    # Creating Datastax Repo
  	echo " ** Adding Datastax Repositoy for Username: $datastax_username ** "
  	sudo touch /etc/yum.repos.d/$reponame.repo
  	sudo chmod a+w /etc/yum.repos.d/$reponame.repo
  	sudo echo -e "[$reponame]\nbaseurl=${url}\nenabled=1\ngpgcheck=0\nname=ISO" > /etc/yum.repos.d/$reponame.repo
  	sudo chmod 644 /etc/yum.repos.d/$reponame.repo
  
  	echo " ******************* Installing DSE $dse_version ******************** "
  	sudo yum clean all
  	sudo yum -y install dse-full-$dse_version
  	sudo swapoff --all
  	echo " ************************** DSE installed *************************** "
    
    echo " ******** Setting Java alterntives to use installed version ********* "
	  sudo alternatives --install /usr/bin/java java /usr/java/jdk1.8.0_45/jre/bin/java 20000
	  sudo alternatives --set java /usr/java/jdk1.8.0_45/jre/bin/java

  	# Setting mount locations. Uncomment or add/remove if required
  	#sudo chown -R cassandra:cassandra /mnt/commitlog
  	#sudo chown -R cassandra:cassandra /mnt/data01
  	#sudo chown -R cassandra:cassandra /mnt/data02
  	#sudo chown -R cassandra:cassandra /mnt/resource
  	#sudo rm -rf /var/lib/cassandra/commitlog
  	#sudo ln -s /mnt/commitlog /var/lib/cassandra/commitlog
  	#sudo ln -s /mnt/data01 /var/lib/cassandra/data01
  	#sudo ln -s /mnt/data02 /var/lib/cassandra/data02

	  # Configuring cassandra.yaml file. Add more if required
	  echo " ***************** Configuring cassandra.yaml file ****************** "
	
	  sudo cp $path/cassandra.yaml $path/cassandra.yaml.original
  	sudo sed -i "s/cluster_name:.*/cluster_name: '$cluster_name'/" $path/cassandra.yaml
  	sudo sed -i "s/# num_tokens: 256/num_tokens: 64/" $path/cassandra.yaml
  	sudo sed -i "s/- seeds: \"127.0.0.1\"/- seeds: \"$seed_ip\"/" $path/cassandra.yaml
  	sudo sed -i "s/listen_address: localhost/listen_address: $ip_addr/" $path/cassandra.yaml
  	sudo sed -i "s/rpc_address: localhost/rpc_address: $ip_addr/" $path/cassandra.yaml
  	sudo sed -i "s/endpoint_snitch: com.datastax.bdp.snitch.DseSimpleSnitch/endpoint_snitch: GossipingPropertyFileSnitch/" $path/cassandra.yaml
  	echo " ******************** cassandra.yaml file Configured ***************** "

  	# Installing Datastax Agent
  	echo " ************* Installing and configuring datastax-agent ************* "
  	sudo yum install datastax-agent -y
	
	  # Manually copy agentKeyStore from /var/lib/opscenter/ssl/agentKeyStore file onto home directory of DSE Search node
 	  scp $opscenter_ip:/var/lib/opscenter/ssl/agentKeyStore /var/lib/datastax-agent/ssl/
    sudo chown cassandra:cassandra /var/lib/datastax-agent/ssl/agentKeyStore

    sudo touch $address_path/address.yaml
	  sudo chmod a+w $address_path/address.yaml
	  sudo echo -e "stomp_interface: $opscenter_ip\nhosts: ["`hostname -i`"]\nuse_ssl: 1\nthrift_max_conns: 10\nasync_pool_size: 10\nasync_queue_size: 20000" > $address_path/address.yaml
    sudo chown cassandra:cassandra $address_path/address.yaml

    echo " ******************* Datastax-agent installed ******************* "

else
    echo " ***************** DSE is already installed ********************* "
fi
