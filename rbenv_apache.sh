#!/bin/bash
rubyver=2.5.3
railver=5.2.6

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
	echo "You are using Ubuntu $ver LTS "$aptcode
	ver=14
	aptexe=apt-get
elif [ ${ver:0:2} == "16" ]; then
	echo "You are using Ubuntu $ver LTS "$aptcode
	ver=16
elif [ ${ver:0:2} == "18" ]; then
	echo "You are using Ubuntu $ver LTS "$aptcode
	ver=18
elif [ ${ver:0:1} == "1" ]; then
	echo "Your Linux Release may not be well tested for AMASCORE RoR... "$ver
	exit 0
elif [ ${ver:0:1} == "2" ]; then
	echo "You are using Ubuntu $ver LTS "$aptcode
	ver=${ver:0:2}
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

echo "install nvm"
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.3/install.sh | bash

curl -sL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list

echo "updating apt source list..."
sudo $aptexe update

echo "installing apache2..."
sudo $aptexe install -y apache2 libapache2-mod-php apache2-dev 
sudo $aptexe install -y mysql-server libmysqlclient-dev
sudo $aptexe install -y php php-mysql php-mbstring

echo "installing some tools..."
#sudo $aptexe install -y git-core curl zlib1g-dev build-essential libssl-dev libreadline-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt1-dev libcurl4-openssl-dev software-properties-common libffi-dev 
sudo $aptexe install -y git-core zlib1g-dev build-essential libssl-dev libreadline-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt1-dev libcurl4-openssl-dev software-properties-common libffi-dev nodejs yarn 

echo "installing rbenv..."
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init -)"' >> ~/.bashrc
export PATH="$HOME/.rbenv/bin:$PATH"
rbenv init
git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
echo 'export PATH="$HOME/.rbenv/plugins/ruby-build/bin:$PATH"' >> ~/.bashrc
export PATH="$HOME/.rbenv/plugins/ruby-build/bin:$PATH"

echo "please run rbenv.sh to install ruby and rails..."

echo "installing nodejs and yarn..."
sudo $aptexe install -y nodejs yarn

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

echo "#!/bin/bash" >> ~/rbenv.sh
echo "VER7=2.7.7" >> ~/rbenv.sh
echo "VER5=2.5.3" >> ~/rbenv.sh
echo "rbenv install \$VER7" >> ~/rbenv.sh
echo "rbenv install \$VER5" >> ~/rbenv.sh
echo "rbenv local \$VER7" >> ~/rbenv.sh
echo "gem install bundler" >> ~/rbenv.sh
echo "gem install nokogiri -v 1.15.3" >> ~/rbenv.sh
echo "gem install rails -v 5.2.1" >> ~/rbenv.sh
echo "rbenv local \$VER5" >> ~/rbenv.sh
echo "gem install bundler -v 2.3.25" >> ~/rbenv.sh
echo "#gem install rails -v 5.2.1" >> ~/rbenv.sh
echo "gem install net-protocol -v 0.1.2" >> ~/rbenv.sh
echo "gem install net-smtp -v 0.3.0" >> ~/rbenv.sh
echo "gem install net-imap -v 0.2.2" >> ~/rbenv.sh
echo "cp -r ~/.rbenv/versions/\$VER7/lib/ruby/gems/2.7.0/gems/nokogiri-1.15.3-x86_64-linux ~/.rbenv/versions/\$VER5/lib/ruby/gems/2.5.0/gems/" >> ~/rbenv.sh
echo "cp -r ~/.rbenv/versions/\$VER7/lib/ruby/gems/2.7.0/specifications/nokogiri-1.15.3-x86_64-linux.gemspec ~/.rbenv/versions/\$VER5/lib/ruby/gems/2.5.0/specifications/" >> ~/rbenv.sh
echo "gem install rails-html-sanitizer -v 1.5.0" >> ~/rbenv.sh
echo "gem install rails -v 5.2.1" >> ~/rbenv.sh
echo "rbenv global \$VER5" >> ~/rbenv.sh
echo "rbenv rehash" >> ~/rbenv.sh
echo "rails -v" >> ~/rbenv.sh

echo "NOTICE: after RoR is ready, modify ror.conf and a2ensite ror.conf "
echo "        (if you deploy multiple site in Apache, remember to add port in ports.conf)"

exit 0
