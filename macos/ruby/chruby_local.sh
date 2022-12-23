##
# A non-root installation of the latest Ruby with chruby

VERSION="0.3.9"

# Install chruby (https://github.com/postmodern/chruby#readme)
mkdir -p $HOME/src
cd $HOME/src
wget -O chruby-$VERSION.tar.gz https://github.com/postmodern/chruby/archive/v$VERSION.tar.gz
tar -xzvf chruby-$VERSION.tar.gz
cd chruby-$VERSION/
PREFIX=$HOME/.chruby make install

# Add the source lines to your ~/.bashrc or ~/.zshrc
echo "source ~/.chruby/share/chruby/chruby.sh" >> ~/.bashrc
echo "source ~/.chruby/share/chruby/auto.sh" >> ~/.bashrc

# Then set whatever Ruby version you want as default
echo "ruby-2.3" > ~/.ruby-version
