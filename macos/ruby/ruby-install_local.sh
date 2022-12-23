# Install ruby-install (https://github.com/postmodern/ruby-install#readme)
mkdir -p $HOME/src
cd $HOME/src
wget -O ruby-install-0.6.0.tar.gz https://github.com/postmodern/ruby-install/archive/v0.6.0.tar.gz
tar -xzvf ruby-install-0.6.0.tar.gz
cd ruby-install-0.6.0/
PREFIX=$HOME/.ruby-install make install

# Install latest stable Ruby
$HOME/.ruby-install/bin/ruby-install --latest --no-install-deps ruby

# Now restart your terminal so chruby can detect your shiny new Ruby
