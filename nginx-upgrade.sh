echo "deb https://nginx.org/packages/ubuntu/ `lsb_release -cs` nginx" | sudo tee /etc/apt/sources.list.d/nginx.list
echo "deb-src https://nginx.org/packages/ubuntu/ `lsb_release -cs` nginx" | sudo tee /etc/apt/sources.list.d/nginx.list
#echo "deb http://nginx.org/packages/mainline/ubuntu `lsb_release -cs` nginx" | sudo tee /etc/apt/sources.list.d/nginx.list
curl -o /tmp/nginx_signing.key https://nginx.org/keys/nginx_signing.key
sudo mv /tmp/nginx_signing.key /etc/apt/trusted.gpg.d/nginx_signing.asc

#sudo apt update
#sudo apt install nginx
