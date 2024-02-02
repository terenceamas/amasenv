#!/bin/bash
rubyver=2.5.3
railver=5.2.6

echo "NOTICE: This script will install Ruby on Rails environment..."
echo "        Ruby "$rubyver" Rails "$railver
echo "NOTICE: This script should run after Apache2 was installed..."

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

echo "install nginx, mysql, php"
sudo $aptexe install -y nginx-extras mysql-server mysql-client libmysqlclient-dev
sudo $aptexe install -y php-fpm php-mysqli php-mbstring

echo "installing some tools..."
#sudo $aptexe install -y git-core curl zlib1g-dev build-essential libssl-dev libreadline-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt1-dev libcurl4-openssl-dev software-properties-common libffi-dev 
sudo $aptexe install -y make cpp c++
sudo $aptexe install -y git-core zlib1g-dev build-essential libssl-dev libreadline-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt1-dev libcurl4-openssl-dev software-properties-common libffi-dev

echo "installing nodejs and yarn..."
sudo $aptexe install -y nodejs yarn

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

echo "installing passenger (nginx mod)..."
sudo $aptexe install -y dirmngr gnupg
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 561F9B9CAC40B2F7
sudo $aptexe install -y apt-transport-https ca-certificates

#sudo sh -c 'echo deb https://oss-binaries.phusionpassenger.com/apt/passenger '$aptcode' main > /etc/apt/sources.list.d/passenger.list'
sudo sh -c 'echo deb https://oss-binaries.phusionpassenger.com/apt/passenger $(lsb_release -cs) main > /etc/apt/sources.list.d/passenger.list'

sudo $aptexe update
sudo $aptexe install -y libnginx-mod-http-passenger
#sudo a2enmod passenger
#sudo apache2ctl restart
if [ ! -f /etc/nginx/modules-enabled/50-mod-http-passenger.conf ]; then 
sudo ln -s /usr/share/nginx/modules-available/mod-http-passenger.load /etc/nginx/modules-enabled/50-mod-http-passenger.conf 
fi
sudo ls /etc/nginx/conf.d/mod-http-passenger.conf

echo "test passenger..."
#sudo /usr/bin/passenger-config validate-install
sudo /usr/bin/passenger-config about ruby-command

echo "deploy RoR to nginx (with passenger)..."
touch ~/ror
echo "server {" >> ~/ror
echo " listen 3000;" >> ~/ror
echo " listen [::]:3000;" >> ~/ror
echo " server_name _;" >> ~/ror
echo " root /home/amastek/myapp/current/public;" >> ~/ror
echo " passenger_enabled on;" >> ~/ror
echo " passenger_app_env production;" >> ~/ror
echo " passenger_ruby /home/amastek/.rbenv/shims/ruby;" >> ~/ror
echo " location /cable {" >> ~/ror
echo "  passenger_app_group_name myapp_websocket;" >> ~/ror
echo "  passenger_force_max_concurrent_requests_per_process 0;" >> ~/ror
echo " }" >> ~/ror
echo " # Allow uploads up to 100MB in size" >> ~/ror
echo " client_max_body_size 100m;" >> ~/ror
echo " location ~ ^/(assets|packs) {" >> ~/ror
echo "  expires max;" >> ~/ror
echo "  gzip_static on;" >> ~/ror
echo " }" >> ~/ror
echo "}" >> ~/ror
sudo mv ~/ror /etc/nginx/sites-enabled/ror

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

echo "#!/bin/bash" >> ~/rbenv7.sh
echo "VER7=3.1.4" >> ~/rbenv7.sh
echo "rbenv install \$VER7" >> ~/rbenv7.sh
echo "rbenv local \$VER7" >> ~/rbenv7.sh
echo "gem install bundler" >> ~/rbenv7.sh
echo "gem install rails -v 7.1.2" >> ~/rbenv7.sh
echo "rbenv rehash" >> ~/rbenv7.sh
echo "ruby -v" >> ~/rbenv7.sh
echo "rails -v" >> ~/rbenv7.sh

echo "NOTICE: after RoR is ready, modify ror and systemctl reload nginx "
echo "NOTICE: remember to use command \"sudo mysql_secure_installation\" to setup mysql database"

exit 0
