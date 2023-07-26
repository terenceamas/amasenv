#!/bin/bash
pkgfile=DemoBox.tar
prj=DemoBox
exe_user=scada
pmaver=4.9.0.1
pmaurl=https://files.phpmyadmin.net/phpMyAdmin/$pmaver/phpMyAdmin-$pmaver-all-languages.tar.gz
pmafile=phpMyAdmin-$pmaver-all-languages.tar.gz
pma=phpMyAdmin-$pmaver-all-languages

echo "NOTICE: This script will install AMASCORE environment for Ubuntu"

bit=`uname -i`
if [ "$bit" == "i686" -o "$bit" == "i386" ]; then
	echo "You are using 32bit system"
	bit=32
elif [ "$bit" == "x86_64" ]; then
	echo "You are using 64bit system"
	bit=64
else
	echo "You hardware platform may not be well tested for AMASCORE.... "$bit
	exit 0
fi

ver=`lsb_release -r | awk '{print $2}'`
aptcode=`lsb_release -c | awk '{print $2}'`
aptexe=apt
if [ ${ver:0:2} == "14" ]; then
	echo "You are using Ubuntu 14.04 LTS "$aptcode
	ver=14
	aptexe=apt-get
elif [ ${ver:0:2} == "16" ]; then
	echo "You are using Ubuntu 16.04 LTS "$aptcode
	ver=16
elif [ ${ver:0:2} == "18" ]; then
	echo "You are using Ubuntu 18.04 LTS "$aptcode
	ver=18
elif [ ${ver:0:2} == "12" ]; then
	echo "You are using Ubuntu 12.04 LTS "$aptcode
	ver=12
	aptexe=apt-get
	wget http://scada.amastek.com/v2/sources.list.nchc
	sudo cp /etc/apt/sources.list /etc/apt/sources.list.old
	sudo cp -f ./sources.list.nchc /etc/apt/sources.list
else
	echo "Your Linux Release may not be well tested for AMASCORE... "$ver
	exit 0
fi

cd ~

read -p "do you want to change apt source from UbuntuTW to NCHC? (y or n) " yn
if [ "$yn" == "Y" -o "$yn" == "y" ]; then 
	sudo cp /etc/apt/sources.list /etc/apt/sources.list_ubuntu
	sudo sed -i 's/archive.ubuntu.com/free.nchc.org.tw/g' /etc/apt/sources.list
elif [ "$yn" == "N" -o "$yn" == "n" ]; then 
	echo "OK. skipping this step" 
else
	echo "I don't know what is your choice...skipping this step" 
fi

echo "installing common utility..."
sudo $aptexe update
sudo $aptexe install -y git vim screen sqlite3
#sudo $aptexe install -y openssh-server

echo "installing service prerequisite... (A M P)"
if [ "$ver" == "16" ]; then
#	sudo $aptexe install -y apache2 mysql-server php php-mysql php-mcrypt php-mbstring libapache2-mod-php
elif [ "$ver" == "18" ]; then
#	sudo $aptexe install -y apache2 mysql-server php php-mysql php-mbstring libapache2-mod-php
else
#	sudo $aptexe install -y apache2 mysql-server php5 php5-mysql php5-mcrypt libapache2-mod-php5
fi

echo "installing coding prerequisite..."
sudo $aptexe install -y make gcc g++
sudo $aptexe install -y libmysqlclient-dev libcrypto++-dev libssl-dev libudev-dev libsqlite3-dev libmodbus-dev libcurl4-gnutls-dev libhpdf-dev zlibc 

#if [ "$bit" == "64" ]; then
#	sudo $aptexe install -y gcc-multilib g++-multilib lib32z1-dev
#fi

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

if [ ! "$ver" == "12" ]; then
	echo "NOTICE: change apache2 path from /var/www/html to /var/www (/etc/apache2/sites-available)"
fi
echo "NOTICE: change ssh server port to 605 (/etc/ssh/sshd_config)"
echo "NOTICE: to hide grub menu (/etc/default/grub) "
echo "        remove '#' before 'GRUB_HIDDEN_TIMEOUT=0' and set 'GRUB_HIDDEN_TIMEOUT_QUIET=true' and 'GRUB_RECORDFAIL_TIMEOUT=0'"
echo "        edit (/boot/grub/grub.cfg) change 'if[\"${recordfail}\"=1 ]; then set timeout=5'"
echo "NOTICE: if you wanna use Google Chrome, be sure to do 'sudo apt-get install libnss3'"

exit 0
