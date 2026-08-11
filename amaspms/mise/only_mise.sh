#!/bin/bash
rubyver=3.3.2
railver=7.2.3
nodever=22

echo "NOTICE: This script will install Ruby on Rails environment..."
echo "        Ruby "$rubyver" Rails "$railver

echo "install nvm script"
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash

echo "installing mise..."
curl https://mise.run | bash
echo 'eval "$(~/.local/bin/mise activate)"' >> ~/.bashrc

echo "please run mise-install.sh to install ruby and rails..."
touch mise-install.sh
echo "#!/bin/bash" > mise-install.sh
echo "mise use --global ruby@$rubyver" > mise-install.sh
echo "ruby --version" >> mise-install.sh
echo "gem update --system" >> mise-install.sh
echo "nvm install $nodever" >> mise-install.sh
echo "mise use --global node@$nodever" >> mise-install.sh
echo "node --version" >> mise-install.sh
echo "gem install rails -v $railver" >> mise-install.sh
echo "rails --version" >> mise-install.sh

echo "please relogin and run mise-install.sh to install ruby and rails..."

exit 0
