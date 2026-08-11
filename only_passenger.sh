#!/bin/bash

echo "installing passenger (nginx mod)..."
# Install our PGP key and add HTTPS support for APT
sudo apt install -y dirmngr gnupg apt-transport-https ca-certificates curl

curl https://oss-binaries.phusionpassenger.com/auto-software-signing-gpg-key.txt | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/phusion.gpg >/dev/null

# Add our APT repository
sudo sh -c 'echo deb https://oss-binaries.phusionpassenger.com/apt/passenger noble main > /etc/apt/sources.list.d/passenger.list'
sudo apt update

# Install Passenger
sudo apt install -y passenger

read -p "do you want to install nginx passenger mod? (y or n) " yn
if [ "$yn" == "Y" -o "$yn" == "y" ]; then 
	sudo apt install -y libnginx-mod-http-passenger
	if [ ! -f /etc/nginx/modules-enabled/50-mod-http-passenger.conf ]; then 
		sudo ln -s /usr/share/nginx/modules-available/mod-http-passenger.load /etc/nginx/modules-enabled/50-mod-http-passenger.conf 
	fi
	sudo ls /etc/nginx/conf.d/mod-http-passenger.conf
elif [ "$yn" == "N" -o "$yn" == "n" ]; then 
	echo "OK. skipping this step" 
else
	echo "I don't know what is your choice...skipping this step" 
fi

echo "test passenger..."
sudo /usr/bin/passenger-config validate-install

echo "deploy RoR to nginx (with passenger)..."
touch ~/ror-nginx-passenger
echo "server {" >> ~/ror-nginx-passenger
echo " listen 3000;" >> ~/ror-nginx-passenger
echo " listen [::]:3000;" >> ~/ror-nginx-passenger
echo " server_name _;" >> ~/ror-nginx-passenger
echo " root /home/amastek/myapp/current/public;" >> ~/ror-nginx-passenger
echo " passenger_enabled on;" >> ~/ror-nginx-passenger
echo " passenger_app_env production;" >> ~/ror-nginx-passenger
echo " passenger_ruby /home/amastek/.rbenv/shims/ruby;" >> ~/ror-nginx-passenger
echo " location /cable {" >> ~/ror-nginx-passenger
echo "  passenger_app_group_name myapp_websocket;" >> ~/ror-nginx-passenger
echo "  passenger_force_max_concurrent_requests_per_process 0;" >> ~/ror-nginx-passenger
echo " }" >> ~/ror-nginx-passenger
echo " # Allow uploads up to 100MB in size" >> ~/ror-nginx-passenger
echo " client_max_body_size 100m;" >> ~/ror-nginx-passenger
echo " location ~ ^/(assets|packs) {" >> ~/ror-nginx-passenger
echo "  expires max;" >> ~/ror-nginx-passenger
echo "  gzip_static on;" >> ~/ror-nginx-passenger
echo " }" >> ~/ror-nginx-passenger
echo "}" >> ~/ror-nginx-passenger

echo "NOTICE: after RoR is ready, modify ror and systemctl reload nginx "

exit 0
