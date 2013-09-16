VERSION="1.1.2"
BUILD="rcrowley1"

set -e -x

scp -o StrictHostKeyChecking="no" "rcrowley.org":".ssh/authorized_keys" ".ssh"

ssh "rcrowley.org" gpg --armor --export --secret "packages@rcrowley.org" | gpg --import
ssh "rcrowley.org" gpg --armor --export-secret-key "packages@rcrowley.org" | gpg --import || :
ssh "rcrowley.org" gpg --armor --export --secret "r@rcrowley.org" | gpg --import
ssh "rcrowley.org" gpg --armor --export-secret-key "r@rcrowley.org" | gpg --import || :

mkdir -p "var/cache/freight"
curl -o"var/cache/freight/keyring.gpg" -s "http://packages.rcrowley.org/keyring.gpg"
curl -o"var/cache/freight/pubkey.gpg" -s "http://packages.rcrowley.org/pubkey.gpg"
mkdir -p "var/lib"
rsync -Hav "rcrowley.org":"var/lib/freight" "var/lib"

cat >"/etc/apt/sources.list.d/rcrowley.list" <<EOF
deb http://packages.rcrowley.org $(lsb_release -sc) main
#deb-src http://packages.rcrowley.org $(lsb_release -sc) main
EOF
cp "var/cache/freight/keyring.gpg" "/etc/apt/trusted.gpg.d/rcrowley.gpg"
apt-get update
apt-get -y upgrade

apt-get -y install "freight" "gnupg-agent" "pinentry-curses" "ruby" "rubygems"
apt-get -y remove "pinentry-gtk2"
which "fpm" || gem install --no-rdoc --no-ri "fpm"

if [ ! -f "go$VERSION.linux-amd64.tar.gz" ]
then curl -O "http://go.googlecode.com/files/go$VERSION.linux-amd64.tar.gz"
fi
if [ ! -f "go_${VERSION}-${BUILD}_amd64.deb" ]
then
    trap "rm -rf \"go\"" EXIT INT QUIT TERM
    tar xf "go$VERSION.linux-amd64.tar.gz"
    fakeroot fpm -m"Richard Crowley <r@rcrowley.org>" -n"go" -p"go_${VERSION}-${BUILD}_amd64.deb" --prefix="/usr" -s"dir" -t"deb" -v"$VERSION-$BUILD" "go"
    rm -rf "go"
    freight add "go_${VERSION}-${BUILD}_amd64.deb" "apt/$(lsb_release -sc)"
fi

if [ -f ".gpg-agent-info" ]
then . "./.gpg-agent-info"
fi
if ! gpg-agent
then gpg-agent --daemon --default-cache-ttl 315360000 --max-cache-ttl 315360000 --write-env-file ".gpg-agent-info"
fi
sleep 1
. "./.gpg-agent-info"
export GPG_AGENT_INFO
freight cache

apt-get -y install "git"
if [ ! -d ".git" ]
then
    git init
    git remote add "origin" "git@github.com:rcrowley/rcrowley.git"
fi
git remote update "origin"
git fetch "origin"
if [ ! -f ".git/refs/heads/master" ]
then rm -f ".profile"
fi
git merge "origin/master"

mkdir -p "src/github.com/rcrowley"
if [ ! -d "src/github.com/rcrowley/go-metrics" ]
then git clone "git@github.com:rcrowley/go-metrics.git" "src/github.com/rcrowley/go-metrics"
fi
if [ ! -d "src/github.com/rcrowley/go-tigertonic" ]
then git clone "git@github.com:rcrowley/go-tigertonic.git" "src/github.com/rcrowley/go-tigertonic"
fi

cat >"/etc/init/www.conf" <<EOF
description "www"
start on runlevel [2345]
stop on runlevel [!2345]
respawn
chdir /root
env GOPATH="/root"
env GOROOT="/usr/go"
env PATH="/root/bin:/usr/go/bin:/usr/bin:/bin"
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
start "www"
