#!/bin/bash
rubyver=2.5.3
railver=5.2.4.2

echo "NOTICE: This script will install Ruby on Rails environment..."
echo "        Ruby "$rubyver" Rails "$railver
echo "NOTICE: This script should run after Apache2 was installed..."

read -p "are you root? (y or n) " yn
if [ "$yn" == "Y" -o "$yn" == "y" ]; then 
	echo "OK! Let's start the rest things"
elif [ "$yn" == "N" -o "$yn" == "n" ]; then 
	echo "Please change to root" 
	exit 0
else
	echo "I don't know what is your choice" 
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
else
	echo "Your Linux Release may not be well tested for AMASCORE RoR... "$ver
	exit 0
fi

read -p "do you want to change apt source from UbuntuTW to NCHC? (y or n) " yn
if [ "$yn" == "Y" -o "$yn" == "y" ]; then 
	sudo cp /etc/apt/sources.list /etc/apt/sources.list_ubuntu
	sudo sed -i 's/tw.archive.ubuntu.com/free.nchc.org.tw/g' /etc/apt/sources.list
elif [ "$yn" == "N" -o "$yn" == "n" ]; then 
	echo "OK. skipping this step" 
else
	echo "I don't know what is your choice...skipping this step" 
fi

curl -sL https://deb.nodesource.com/setup_12.x | sudo -E bash -
curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list

echo "updating apt source list..."
$aptexe update

read -p "did you install apache2 web server? (y or n) " yn
if [ "$yn" == "Y" -o "$yn" == "y" ]; then 
	echo "installing apache2-dev..." 
	$aptexe install -y apache2-dev
elif [ "$yn" == "N" -o "$yn" == "n" ]; then 
	echo "installing apache2..."
	$aptexe install -y apache2 mysql-server php php-mysql php-mcrypt libapache2-mod-php apache2-dev libmysqlclient-dev
else
	echo "I don't know what is your choice...skipping this step" 
fi

echo "installing some tools..."
$aptexe install -y git-core curl zlib1g-dev build-essential libssl-dev libreadline-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt1-dev libcurl4-openssl-dev software-properties-common libffi-dev 

echo "installing rvm..."
$aptexe install -y libgdbm-dev libncurses5-dev automake libtool bison libffi-dev
gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
curl -sSL https://get.rvm.io | bash -s stable
source /etc/profile.d/rvm.sh

echo "installing ruby and rails..."
rvm install $rubyver
rvm use $rubyver --default
ruby -v
gem install bundler
gem install rails -v $railver --no-ri --no-rdoc
rails -v

echo "installing nodejs and yarn..."
$aptexe install -y nodejs yarn

echo "installing passenger (apache mod)..."
$aptexe install -y dirmngr gnupg
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 561F9B9CAC40B2F7
$aptexe install -y apt-transport-https ca-certificates

sh -c 'echo deb https://oss-binaries.phusionpassenger.com/apt/passenger '$aptcode' main > /etc/apt/sources.list.d/passenger.list'

$aptexe update
$aptexe install -y libapache2-mod-passenger
a2enmod passenger
apache2ctl restart

echo "test passenger..."
/usr/bin/passenger-config validate-install
/usr/bin/passenger-config about ruby-command

echo "deploy RoR to apache (with passenger)..."
#cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/ror.conf
touch /etc/apache2/sites-available/ror.conf
echo "<VirtualHost *:80>" >> /etc/apache2/sites-available/ror.conf
echo "    ServerAdmin webmaster@localhost" >> /etc/apache2/sites-available/ror.conf
echo "    DocumentRoot /home/scada/testapp/public" >> /etc/apache2/sites-available/ror.conf
echo "    RailsEnv development" >> /etc/apache2/sites-available/ror.conf
echo "    ErrorLog ${APACHE_LOG_DIR}/error.log" >> /etc/apache2/sites-available/ror.conf
echo "    CustomLog ${APACHE_LOG_DIR}/access.log combined" >> /etc/apache2/sites-available/ror.conf
echo "    <Directory \"/home/scada/testapp/public\">" >> /etc/apache2/sites-available/ror.conf
echo "        Options FollowSymLinks" >> /etc/apache2/sites-available/ror.conf
echo "        Require all granted" >> /etc/apache2/sites-available/ror.conf
echo "    </Directory>" >> /etc/apache2/sites-available/ror.conf
echo "</VirtualHost>" >> /etc/apache2/sites-available/ror.conf

echo "NOTICE: after RoR is ready, modify ror.conf and a2ensite ror.conf "
echo "        (if you deploy multiple site in Apache, remember to add port in ports.conf)"
echo "NOTICE: remember to add \"source /etc/profile.d/rvm.sh\" to every RoR user's bash profile"

exit 0
