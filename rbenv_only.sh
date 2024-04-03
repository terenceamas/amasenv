#!/bin/bash
rubyver=2.5.3
railver=5.2.6
rubyver7=3.1.4
railver7=7.1.3

echo "NOTICE: This script will install Ruby on Rails environment..."
echo "        Ruby "$rubyver" Rails "$railver
echo "NOTICE: This script should run after Apache2 was installed..."

echo "install nvm"
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.3/install.sh | bash

echo "installing rbenv..."
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init -)"' >> ~/.bashrc
export PATH="$HOME/.rbenv/bin:$PATH"
rbenv init
git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
echo 'export PATH="$HOME/.rbenv/plugins/ruby-build/bin:$PATH"' >> ~/.bashrc
export PATH="$HOME/.rbenv/plugins/ruby-build/bin:$PATH"

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

echo "#!/bin/bash" >> ~/rbenv5.sh
echo "VER7=2.7.8" >> ~/rbenv5.sh
echo "rbenv install \$VER7" >> ~/rbenv5.sh
echo "rbenv local \$VER7" >> ~/rbenv5.sh
echo "gem install bundler -v 2.3.25" >> ~/rbenv5.sh
echo "gem install nokogiri -v 1.15.6" >> ~/rbenv5.sh
echo "gem install rails -v 5.2.8" >> ~/rbenv5.sh
echo "rbenv rehash" >> ~/rbenv5.sh
echo "ruby -v" >> ~/rbenv5.sh
echo "rails -v" >> ~/rbenv5.sh

echo "#!/bin/bash" >> ~/rbenv7.sh
echo "VER7=3.1.4" >> ~/rbenv7.sh
echo "rbenv install \$VER7" >> ~/rbenv7.sh
echo "rbenv local \$VER7" >> ~/rbenv7.sh
echo "gem install bundler" >> ~/rbenv7.sh
echo "gem install rails -v 7.1.2" >> ~/rbenv7.sh
echo "rbenv rehash" >> ~/rbenv7.sh
echo "ruby -v" >> ~/rbenv7.sh
echo "rails -v" >> ~/rbenv7.sh

echo "please relogin and run rbenv.sh to install ruby and rails..."

exit 0
