#!/bin/bash
rubyver=2.5.3
railver=5.2.1

echo "installing rbenv..."
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init -)"' >> ~/.bashrc
export PATH="$HOME/.rbenv/bin:$PATH"
rbenv init
git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
echo 'export PATH="$HOME/.rbenv/plugins/ruby-build/bin:$PATH"' >> ~/.bashrc
export PATH="$HOME/.rbenv/plugins/ruby-build/bin:$PATH"

echo "installing ruby and rails..."
#rvm install $rubyver
#rvm use $rubyver --default
rbenv install $rubyver
rbenv global $rubyver
rbenv local $rubyver
rbenv init
ruby -v
gem install bundler
rbenv rehash
gem install rails -v $railver --no-ri --no-rdoc
rbenv rehash
rails -v

if [ ! -f ~/rbenv.sh ]
then
	echo "#!/bin/bash" >> ~/rbenv.sh
	echo "gem install bundler" >> ~/rbenv.sh
	echo "rbenv rehash" >> ~/rbenv.sh
	echo "gem install rails -v $railver" >> ~/rbenv.sh
	echo "rbenv rehash" >> ~/rbenv.sh
	echo "rails -v" >> ~/rbenv.sh
fi

echo "NOTICE: after RoR is ready, modify ror.conf and a2ensite ror.conf "
echo "        (if you deploy multiple site in Apache, remember to add port in ports.conf)"
echo "NOTICE: remember to add \"source /etc/profile.d/rvm.sh\" to every RoR user's bash profile"

exit 0
