#!/bin/bash
rubyver=3.4.7
railver=7.2.3
nodever=22

echo "NOTICE: This script will install Ruby on Rails environment..."
echo "        Ruby "$rubyver" Rails "$railver
echo "NOTICE: This script should run after Apache2 was installed..."

ver=`lsb_release -r | awk '{print $2}'`
aptcode=`lsb_release -c | awk '{print $2}'`
aptexe=apt
if [ ${ver:0:1} == "2" ]; then
	echo "You are using Ubuntu $ver LTS "$aptcode
	ver=${ver:0:2}
elif [ ${ver:0:1} == "1" ]; then
	echo "Your Linux Release may be outdated for AMASPMS RoR... "$ver
	exit 0
else
	echo "Your Linux Release may not be well tested for AMASPMS RoR... "$ver
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

echo "install nvm script"
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash

#curl -sL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list

echo "updating apt source list..."
sudo apt update

echo "install nginx, mysql, php"
sudo apt install -y nginx-extras mysql-server mysql-client libmysqlclient-dev
sudo apt install -y php-fpm php-mysqli php-mbstring

echo "installing some tools..."
sudo apt install -y make cpp c++ git-core sqlite3
sudo apt install -y build-essential rustc libssl-dev libyaml-dev zlib1g-dev libgmp-dev
sudo apt install -y libreadline-dev libsqlite3-dev libxml2-dev libxslt1-dev libcurl4-openssl-dev software-properties-common libffi-dev
sudo apt install -y yarn

echo "installing mise..."
curl https://mise.run | bash
echo 'eval "$(~/.local/bin/mise activate)"' >> ~/.bashrc

echo "please run mise-install.sh rbenv to install ruby and rails..."
touch mise-install.sh
echo "#!/bin/bash" >> mise-install.sh
echo "mise use --global ruby@$rubyver" >> mise-install.sh
echo "ruby --version" >> mise-install.sh
echo "gem update --system" >> mise-install.sh
echo "nvm install $nodever" >> mise-install.sh
echo "mise use --global node@$nodever" >> mise-install.sh
echo "node --version" >> mise-install.sh
echo "gem install rails -v $railver" >> mise-install.sh
echo "rails --version" >> mise-install.sh

echo "make PROJ app run as system service"
touch ~/setup-puma.sh
echo "#!/bin/bash" >> ~/setup-puma.sh
echo "cd ~/PROJ" >> ~/setup-puma.sh
echo "mkdir tmp/sockets tmp/pids" >> ~/setup-puma.sh

touch ~/PROJ.service
echo "[Unit]" >> ~/PROJ.service
echo "Description=Rails-Puma Webserver" >> ~/PROJ.service
echo "" >> ~/PROJ.service
echo "[Service]" >> ~/PROJ.service
echo "Type=simple" >> ~/PROJ.service
echo "User=deploy" >> ~/PROJ.service
echo "WorkingDirectory=/home/deploy/PROJ" >> ~/PROJ.service
echo "ExecStart=/bin/bash -lc 'bundle exec puma -C config/puma.rb'" >> ~/PROJ.service
echo "TimeoutSec=15" >> ~/PROJ.service
echo "Restart=always" >> ~/PROJ.service
echo "" >> ~/PROJ.service
echo "[Install]" >> ~/PROJ.service
echo "WantedBy=multi-user.target" >> ~/PROJ.service

touch ~/make-service.sh
echo "#!/bin/bash" >> ~/make-service.sh
echo "sudo mv ~/PROJ.service /etc/systemd/system/" >> ~/make-service.sh
echo "sudo systemctl daemon-reload" >> ~/make-service.sh
echo "sudo systemctl enable PROJ" >> ~/make-service.sh
echo "sudo systemctl start PROJ" >> ~/make-service.sh

echo "deploy RoR to nginx (with puma)..."
touch ~/ror_puma
echo "upstream app {" >> ~/ror_puma
echo " server unix:/home/deploy/PROJ/tmp/sockets/PROJ.sock fail_timeout=0;" >> ~/ror_puma
echo "}" >> ~/ror_puma
echo "server {" >> ~/ror_puma
echo " listen 443 ssl;" >> ~/ror_puma
echo " listen [::]:443 ssl;" >> ~/ror_puma
echo " server_name _;" >> ~/ror_puma
echo " root /home/amastek/PROJ/public;" >> ~/ror_puma
echo " try_files $uri/index.html $uri @app;" >> ~/ror_puma
echo " location @app {" >> ~/ror_puma
echo "  proxy_pass http://app;" >> ~/ror_puma
echo "  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;" >> ~/ror_puma
echo "  proxy_set_header Host $http_host;" >> ~/ror_puma
echo "  proxy_redirect off;" >> ~/ror_puma
echo " }" >> ~/ror_puma
echo " error_page 500 502 503 504 /500.html;" >> ~/ror_puma
echo " client_max_body_size 4G;" >> ~/ror_puma
echo " keepalive_timeout 10;" >> ~/ror_puma
echo "}" >> ~/ror_puma
sudo mv ~/ror_puma /etc/nginx/sites-enabled/ror_puma

echo "NOTICE: after RoR is ready, modify scripts and systemctl reload nginx "
echo "NOTICE: remember to use command \"sudo mysql_secure_installation\" to setup mysql database"

exit 0
