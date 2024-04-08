#!/bin/bash
pkgfile=DemoBox.tar
prj=DemoBox
exe_user=scada
pmaver=5.2.1
pmaurl=https://files.phpmyadmin.net/phpMyAdmin/$pmaver/phpMyAdmin-$pmaver-all-languages.tar.gz
pmafile=phpMyAdmin-$pmaver-all-languages.tar.gz
pma=phpMyAdmin-$pmaver-all-languages

echo "NOTICE: This script will install AMASCORE environment for Ubuntu"

bit=`uname -i`
#if [ "$bit" == "i686" -o "$bit" == "i386" ]; then
#	echo "You are using 32bit system"
#	bit=32
#elif [ "$bit" == "x86_64" ]; then
#	echo "You are using 64bit system"
#	bit=64
#else
#	echo "You hardware platform may not be well tested for AMASCORE.... "$bit
#	exit 0
#fi
bit=64

ver=`lsb_release -r | awk '{print $2}'`
aptcode=`lsb_release -c | awk '{print $2}'`
aptexe=apt
if [ ${ver:0:2} == "18" ]; then
	echo "You are using Ubuntu 18.04 LTS "$aptcode
	ver=18
else
  ver=${ver:0:2}
	echo "Your Linux Release may not be well tested for AMASCORE... "$ver
	exit 0
fi

read -p "did you add the user '"$exe_user"'? (y or n) " yn
if [ "$yn" == "Y" -o "$yn" == "y" ]; then 
	echo "OK! Let's start the rest things"
elif [ "$yn" == "N" -o "$yn" == "n" ]; then 
	echo "Please add the user first" 
	sudo adduser $exe_user
else
	echo "I don't know what is your choice" 
	exit 0
fi

if [ -d /home/$exe_user ]; then 
#	read -p "are you in AMASTek network environment? (y or n)" yn
#	if [ "$yn" == "Y" -o "$yn" == "y" ]; then 
#		echo "OK! download project files"
#		cd /home/$exe_user
#		sudo wget ftp://upload:aq12345@192.168.26.210/Upload/$pkgfile
#		sudo tar xf $pkgfile
#		sudo chown -R $exe_user:$exe_user $prj
#	elif [ "$yn" == "N" -o "$yn" == "n" ]; then 
#		echo "Skipping downloading project files" 
#	else
#		echo "I don't know what is your choice. Skipping downloading project files" 
#	fi
	
	if [ -d /var/www/v2 ]; then
		echo "project prerequisite is met..."
	else
		echo "building project prerequisite..."
		sudo mkdir -p /var/www/v2/OBM1
		sudo chmod -R 755 /var/www/v2
		sudo chown -R $exe_user:$exe_user /var/www/v2
	fi
fi

if [ -d /var/www/.pma ]; then
	echo "phpMyAdmin is pre-installed"
else
	cd /var/www
	echo "installing phpMyAdmin..."
	sudo wget --no-check-certificate $pmaurl
	sudo tar zxf $pmafile
	sudo mv $pma .pma	
	sudo rm $pmafile
	cd .pma
	sudo mkdir tmp
	sudo chmod 777 tmp
fi

cd ~

#read -p "do you want to change apt source from UbuntuTW to NCHC? (y or n) " yn
#if [ "$yn" == "Y" -o "$yn" == "y" ]; then 
#	sudo cp /etc/apt/sources.list /etc/apt/sources.list_ubuntu
#	sudo sed -i 's/tw.archive.ubuntu.com/free.nchc.org.tw/g' /etc/apt/sources.list
#elif [ "$yn" == "N" -o "$yn" == "n" ]; then 
#	echo "OK. skipping this step" 
#else
#	echo "I don't know what is your choice...skipping this step" 
#fi

echo "installing common utility..."
sudo $aptexe update
sudo $aptexe install -y git vim screen sqlite3 openssh-server

echo "installing service prerequisite... (A M P)"
sudo $aptexe install -y apache2 mysql-server php php-mysql php-mbstring libapache2-mod-php

echo "installing coding prerequisite..."
sudo $aptexe install -y make gcc g++
if [ "$ver" == "18" ]; then
	sudo $aptexe install -y libmysqlclient-dev libcrypto++-dev libssl-dev libudev-dev libsqlite3-dev libmodbus-dev libcurl4-gnutls-dev libhpdf-dev zlibc 
else
	sudo $aptexe install -y libmysqlclient-dev libcrypto++-dev libssl-dev libudev-dev libsqlite3-dev libmodbus-dev libcurl4-gnutls-dev libhpdf-dev libmysql++-dev libjwt-dev
fi

if [ "$bit" == "64" ]; then
	sudo $aptexe install -y gcc-multilib g++-multilib lib32z1-dev
fi

echo "apply http timeout setting..."
if [ -f /etc/sysctl.d/10-ipv4-timeout.conf ]; then
	sudo mv /etc/sysctl.d/10-ipv4-timeout.conf /etc/sysctl.d/10-ipv4-timeout.conf_old
fi

cd ~
touch ./10-ipv4-timeout.conf
echo "net.ipv4.tcp_fin_timeout = 3" >> ./10-ipv4-timeout.conf
echo "net.ipv4.tcp_tw_reuse = 1" >> ./10-ipv4-timeout.conf
echo "net.ipv4.tcp_tw_recycle = 1" >> ./10-ipv4-timeout.conf
echo "net.ipv4.tcp_keepalive_time = 2400" >> ./10-ipv4-timeout.conf
echo "net.ipv4.tcp_keepalive_probes = 2" >> ./10-ipv4-timeout.conf
echo "net.ipv4.tcp_keepalive_intvl = 30" >> ./10-ipv4-timeout.conf
sudo cp ./10-ipv4-timeout.conf /etc/sysctl.d/10-ipv4-timeout.conf

echo "NOTICE: change apache2 path from /var/www/html to /var/www (/etc/apache2/sites-available)"
echo "NOTICE: change ssh server port to 605 (/etc/ssh/sshd_config)"
echo "NOTICE: to hide grub menu (/etc/default/grub) "
echo "        remove '#' before 'GRUB_HIDDEN_TIMEOUT=0' and set 'GRUB_HIDDEN_TIMEOUT_QUIET=true' and 'GRUB_RECORDFAIL_TIMEOUT=0'"
echo "        edit (/boot/grub/grub.cfg) change 'if[\"${recordfail}\"=1 ]; then set timeout=5'"
echo "NOTICE: if you wanna use Google Chrome, be sure to do 'sudo apt-get install libnss3'"
echo "NOTICE: be sure to add this line below into your mysqld.cnf"
echo "        sql_mode = STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION"

exit 0
