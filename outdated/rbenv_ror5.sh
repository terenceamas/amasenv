#!/bin/bash
rubyver=2.7.1
railver=5.2.4.2

echo "NOTICE: This script will install Ruby on Rails environment..."
echo "        Ruby "$rubyver" Rails "$railver

echo "installing rbenv..."
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init -)"' >> ~/.bashrc
#source ~/.bashrc
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"
git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
rbenv install 

echo "installing ruby and rails..."
rbenv install $rubyver
rbenv global $rubyver
rbenv rehash
ruby -v
gem install bundler
gem env home
gem install rails -v $railver --no-ri --no-rdoc
rbenv rehash
rails -v

exit 0
