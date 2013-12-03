VERSION="1.1.2"
BUILD="rcrowley1"

set -e -x

# Add known hosts entries to make this program more headless.
mkdir -m"700" -p ".ssh"
if ! grep -q "github.com" ".ssh/known_hosts"
then ssh-keyscan "github.com" >>".ssh/known_hosts"
fi
if ! grep -q "rcrowley.org" ".ssh/known_hosts"
then ssh-keyscan "rcrowley.org" >>".ssh/known_hosts"
fi

# Copy authorized SSH public keys from the old rcrowley.org.
scp "rcrowley.org":".ssh/authorized_keys" ".ssh"

# Copy GPG key pairs from the old rcrowley.org.
ssh "rcrowley.org" gpg --armor --export "packages@rcrowley.org" | gpg --import
ssh "rcrowley.org" gpg --armor --export-secret-keys "packages@rcrowley.org" | gpg --import || :
ssh "rcrowley.org" gpg --armor --export "r@rcrowley.org" | gpg --import
ssh "rcrowley.org" gpg --armor --export-secret-keys "r@rcrowley.org" | gpg --import || :

# Copy files from the old rcrowley.org.
mkdir -p "src" "var/cache/freight" "var/lib" "var/www"
curl -o"var/cache/freight/keyring.gpg" -s "http://packages.rcrowley.org/keyring.gpg"
curl -o"var/cache/freight/pubkey.gpg" -s "http://packages.rcrowley.org/pubkey.gpg"
rsync -av "rcrowley.org":"src/git.squareup.com" "src"
rsync -av "rcrowley.org":"var/backups" "var"
rsync -av "rcrowley.org":"var/lib/Papers2" "var/lib"
rsync -Hav "rcrowley.org":"var/lib/freight" "var/lib"
rsync -av "rcrowley.org":"var/lib/git" "var/lib"
rsync -av "rcrowley.org":"var/www/arch" "var/www" || :
rsync -av "rcrowley.org":"var/www/work" "var/www" || :

# Add our Debian archive to APT.
cat >"/etc/apt/sources.list.d/rcrowley.list" <<EOF
deb http://packages.rcrowley.org $(lsb_release -sc) main
#deb-src http://packages.rcrowley.org $(lsb_release -sc) main
EOF
cp "var/cache/freight/keyring.gpg" "/etc/apt/trusted.gpg.d/rcrowley.gpg"
apt-get update
apt-get -y upgrade

# Install dependencies.
apt-get -y install "freight" "gnupg-agent" "mercurial" "pinentry-curses" "ruby" "rubygems" "tmux" "vim"
apt-get -y remove "pinentry-gtk2"
which "fpm" || gem install --no-rdoc --no-ri "fpm"

# Build the Debian package for Go if it doesn't already exist.
if [ ! -f "var/lib/freight/apt/$(lsb_release -sc)/go_${VERSION}-${BUILD}_amd64.deb" ]
then
    curl -O "http://go.googlecode.com/files/go$VERSION.linux-amd64.tar.gz"
    trap "rm -rf \"go\" \"go$VERSION.linux-amd64.tar.gz\"" EXIT INT QUIT TERM
    tar xf "go$VERSION.linux-amd64.tar.gz"
    fakeroot fpm -m"Richard Crowley <r@rcrowley.org>" -n"go" -p"var/lib/freight/apt/$(lsb_release -sc)/go_${VERSION}-${BUILD}_amd64.deb" --prefix="/usr" -s"dir" -t"deb" -v"$VERSION-$BUILD" "go"
    rm -rf "go" "go$VERSION.linux-amd64.tar.gz"
fi

# Clone the home directory.
apt-get -y install "git"
if [ ! -d ".git" ]
then
    git init
    git remote add "origin" "git@github.com:rcrowley/rcrowley.git"
fi
git remote update "origin"
git fetch "origin"
if [ ! -f ".git/refs/heads/master" ]
then rm -f ".profile" "bootstrap.sh"
fi
git merge "origin/master"

# Start a GPG agent and cache the Debian archive.
if [ -f ".gpg-agent-info" ]
then
    . "./.gpg-agent-info"
    export GPG_AGENT_INFO
fi
if ! gpg-agent
then gpg-agent --daemon --default-cache-ttl 315360000 --max-cache-ttl 315360000 --write-env-file ".gpg-agent-info"
fi
sleep 1
. "./.gpg-agent-info"
export GPG_AGENT_INFO
export GPG_TTY="$(tty)"
freight cache
apt-get update

# Install Go and clone dependencies.
apt-get install "go"
mkdir -p "src/github.com/rcrowley"
if [ ! -d "src/github.com/rcrowley/go-metrics" ]
then git clone "git@github.com:rcrowley/go-metrics.git" "src/github.com/rcrowley/go-metrics"
fi
if [ ! -d "src/github.com/rcrowley/go-tigertonic" ]
then git clone "git@github.com:rcrowley/go-tigertonic.git" "src/github.com/rcrowley/go-tigertonic"
fi

# Build, install, and start www.
. ".profile.d/go.sh"
go install "www"
cat >"/etc/init/www.conf" <<EOF
description "www"
start on runlevel [2345]
stop on runlevel [!2345]
respawn
chdir /root
env GOMAXPROCS="4"
env GOPATH="/root"
env GOROOT="/usr/go"
env PATH="/root/bin:/usr/bin:/bin:/usr/go/bin"
script
    set -e
    rm -f "/tmp/www.log"
    mkfifo "/tmp/www.log"
    (setsid logger -t"www" <"/tmp/www.log" &)
    exec >"/tmp/www.log" 2>"/tmp/www.log"
    rm "/tmp/www.log"
    exec /root/bin/www
end script
EOF
start "www" || restart "www"

# Remove the old rcrowley.org's SSH host key.
grep -v "rcrowley.org" ".ssh/known_hosts" >"known_hosts"
mv "known_hosts" ".ssh"
