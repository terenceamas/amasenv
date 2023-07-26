#!/bin/bash
rubyver=3.1.1
railver=7.0.1

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
else
	echo "Your are using Ubuntu "$ver
#	exit 0
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

curl -sL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list

echo "updating apt source list..."
sudo $aptexe update
sudo $aptexe install -y make gcc g++ curl openssh-server openssh-client htop 
sudo $aptexe install -y libmysqlclient-dev libcrypto++-dev libssl-dev libudev-dev libsqlite3-dev libmodbus-dev libcurl4-gnutls-dev libhpdf-dev zlibc libmysqlcppconn-dev

read -p "did you install apache2 web server? (y or n) " yn
if [ "$yn" == "Y" -o "$yn" == "y" ]; then 
	sudo $aptexe install -y apache2-dev
elif [ "$yn" == "N" -o "$yn" == "n" ]; then 
	echo "installing apache2..."
	sudo $aptexe install -y apache2 mysql-server php php-mysql php-mcrypt php-mbstring libapache2-mod-php apache2-dev libmysqlclient-dev
else
	echo "I don't know what is your choice...skipping this step" 
fi

echo "installing some tools..."
#sudo $aptexe install -y git-core curl zlib1g-dev build-essential libssl-dev libreadline-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt1-dev libcurl4-openssl-dev software-properties-common libffi-dev 
sudo $aptexe install -y git-core zlib1g-dev build-essential libssl-dev libreadline-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt1-dev libcurl4-openssl-dev software-properties-common libffi-dev nodejs yarn 

#echo "installing rvm..."
#$aptexe install -y libgdbm-dev libncurses5-dev automake libtool bison libffi-dev
#gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
#curl -sSL https://get.rvm.io | bash -s stable
#source /etc/profile.d/rvm.sh

echo "installing asdf..."
cd
git clone https://github.com/excid3/asdf.git ~/.asdf
echo '. "$HOME/.asdf/asdf.sh"' >> ~/.bashrc
echo '. "$HOME/.asdf/completions/asdf.bash"' >> ~/.bashrc
echo 'legacy_version_file = yes' >> ~/.asdfrc
echo 'export EDITOR="code --wait"' >> ~/.bashrc
exec $SHELL

echo "installing ruby and rails..."
asdf plugin add ruby
asdf plugin add nodejs
asdf install $rubyver
asdf global $rubyve
which ruby
gem update --system
asdf install nodejs 18.15.0
asdf global nodejs 18.15.0
which node
npm install -g yarn

gem install bundler
gem install rails -v $railver
rails -v

#echo 'export EDITOR="code --wait"' >> ~/.bashrc
#exec $SHELL

echo "installing passenger (apache mod)..."
sudo $aptexe install -y dirmngr gnupg
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 561F9B9CAC40B2F7
sudo $aptexe install -y apt-transport-https ca-certificates

sudo sh -c 'echo deb https://oss-binaries.phusionpassenger.com/apt/passenger '$aptcode' main > /etc/apt/sources.list.d/passenger.list'

sudo $aptexe update
sudo $aptexe install -y libapache2-mod-passenger
sudo a2enmod passenger
sudo apache2ctl restart

echo "test passenger..."
sudo /usr/bin/passenger-config validate-install
sudo /usr/bin/passenger-config about ruby-command

if [ ! -f /etc/apache2/sites-available/ror.conf ]
then
	echo "deploy RoR to apache (with passenger)..."
	#cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/ror.conf
	touch ~/ror.conf
	echo "<VirtualHost *:80>" >> ~/ror.conf
	echo "    ServerAdmin webmaster@localhost" >> ~/ror.conf
	echo "    DocumentRoot /home/scada/testapp/public" >> ~/ror.conf
	echo "    RailsEnv development" >> ~/ror.conf
	echo "    ErrorLog ${APACHE_LOG_DIR}/error.log" >> ~/ror.conf
	echo "    CustomLog ${APACHE_LOG_DIR}/access.log combined" >> ~/ror.conf
	echo "    <Directory \"/home/scada/testapp/public\">" >> ~/ror.conf
	echo "        Options FollowSymLinks" >> ~/ror.conf
	echo "        Require all granted" >> ~/ror.conf
	echo "    </Directory>" >> ~/ror.conf
	echo "</VirtualHost>" >> ~/ror.conf
	sudo mv ~/ror.conf /etc/apache2/sites-available/ror.conf
fi

echo "NOTICE: after RoR is ready, modify ror.conf and a2ensite ror.conf "
echo "        (if you deploy multiple site in Apache, remember to add port in ports.conf)"
echo "NOTICE: remember to add \"source /etc/profile.d/rvm.sh\" to every RoR user's bash profile"

exit 0
