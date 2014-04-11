# rcrowley-ify a computer!

VERSION="1.2.1"
BUILD="rcrowley1"

MAC_OS_X="$([ "$(uname)" = "Darwin" ] && echo "yes" || :)"

set -e

if [ "$MAC_OS_X" ]
then sudo -p"$0 requires %U privileges! Password: " -v
elif [ "$(whoami)" != "root" ]
then exec sudo -p"$0 requires %U privileges! Password: " env SSH_AUTH_SOCK="$SSH_AUTH_SOCK" sh "$0" "$@"
fi

set -x

# Setup FileVault and leave its recovery key in the home directory.
if [ "$MAC_OS_X" ]
then
    if which "fdesetup" >"/dev/null" 2>"/dev/null"
    then
        if ! sudo fdesetup list
        then sudo fdesetup enable -outputplist -user "$USER" | tee "filevault.plist"
        fi
    else
        set +x
        echo >&2
        echo "$(tput "bold")Make sure you turn on FileVault!$(tput "sgr0")" >&2
        echo >&2
        set -x
    fi
fi

# Add known hosts entries to make this program more headless.
mkdir -m"700" -p ".ssh"
if ! grep -q "github.com" ".ssh/known_hosts"
then ssh-keyscan "github.com" >>".ssh/known_hosts"
fi
if ! grep -q "rcrowley.org" ".ssh/known_hosts"
then ssh-keyscan "rcrowley.org" >>".ssh/known_hosts"
fi

# Add our Debian archive to APT.
if [ -z "$MAC_OS_X" ]
then
    cat >"/etc/apt/sources.list.d/rcrowley.list" <<EOF
deb http://packages.rcrowley.org $(lsb_release -sc) main
#deb-src http://packages.rcrowley.org $(lsb_release -sc) main
EOF
    cp "var/cache/freight/keyring.gpg" "/etc/apt/trusted.gpg.d/rcrowley.gpg"
    export APT_LISTBUGS_FRONTEND="none" APT_LISTCHANGES_FRONTEND="none" DEBIAN_FRONTEND="noninteractive"
    apt-get update
fi

# Build the Debian package for Go if it doesn't already exist.
if [ -z "$MAC_OS_X" ]
then
    if [ ! -f "var/lib/freight/apt/$(lsb_release -sc)/go_${VERSION}-${BUILD}_amd64.deb" ]
    then
        curl -O -f "http://go.googlecode.com/files/go$VERSION.linux-amd64.tar.gz"
        trap "rm -rf \"go\" \"go$VERSION.linux-amd64.tar.gz\"" EXIT INT QUIT TERM
        tar xf "go$VERSION.linux-amd64.tar.gz"
        fakeroot fpm -m"Richard Crowley <r@rcrowley.org>" -n"go" -p"var/lib/freight/apt/$(lsb_release -sc)/go_${VERSION}-${BUILD}_amd64.deb" --prefix="/usr" -s"dir" -t"deb" -v"$VERSION-$BUILD" "go"
        rm -rf "go" "go$VERSION.linux-amd64.tar.gz"
        trap "" EXIT INT QUIT TERM
    fi
fi

# Install dependencies.
if [ "$MAC_OS_X" ]
then
    if [ ! -f "/usr/local/bin/brew" ]
    then ruby -e "$(curl -fsSL "https://raw.github.com/Homebrew/homebrew/go/install")"
    fi
    if [ ! -d "/Library/Developer" ]
    then xcode-select --install
    fi
    brew install "git" "gnupg" "gpg-agent"

    # Go releases aren't necessarily tagged to every OS X release so we have to
    # be a bit more clever about finding the URL of the package to install.
    if [ ! -d "/usr/local/go" ]
    then
        seq "$(sw_vers -productVersion | cut -d"." -f"2")" "-1" "6" |
        while read MINOR
        do
            curl -O -f "http://go.googlecode.com/files/go$VERSION.darwin-amd64-osx10.$MINOR.pkg" || continue
            trap "rm -f \"go$VERSION.darwin-amd64-osx10.$MINOR.pkg\"" EXIT INT QUIT TERM
            sudo installer -package "go$VERSION.darwin-amd64-osx10.$MINOR.pkg" -target "/"
            rm -f "go$VERSION.darwin-amd64-osx10.$MINOR.pkg"
            trap "" EXIT INT QUIT TERM
            break
        done
    fi

else
    apt-get -y install "freight" "git" "gnupg-agent" "go" "mercurial" "pinentry-curses" "python-django" "ruby" "rubygems" "tmux" "vim"
    apt-get -y remove "pinentry-gtk2"
    which "fpm" || gem install --no-rdoc --no-ri "fpm"
fi

# Install and configure Mac GUI apps.
if [ "$MAC_OS_X" ]
then
    if [ ! -d "/Applications/Adium.app" ]
    then
        curl -O "http://softlayer-dal.dl.sourceforge.net/project/adium/Adium_1.5.9.dmg"
        # FIXME
    fi
    # FIXME Caffiene
    if [ ! -d "/Applications/Google Chrome.app" ]
    then
        curl -O "https://dl.google.com/chrome/mac/stable/GGRO/googlechrome.dmg"
        # FIXME
    fi
    if [ ! -d "/Applications/Papers2.app" ]
    then
        curl -O "http://downloads.mekentosj.com/papers_273.dmg"
        # FIXME
    fi
    # FIXME VirtualBox
    read -p"Install Slack and Textual from the Mac App Store; press <ENTER> to continue. "
    open "/Applications/App Store.app"
    # FIXME Pause until the App Store closes.
    # FIXME defaults write ...
fi

# Update everything aggressively.
if [ "$MAC_OS_X" ]
then sudo softwareupdate -i -a
else apt-get -y upgrade
fi

# Clone the home directory.
if [ ! -d ".git" ]
then
    git init
    git remote add "origin" "git@github.com:rcrowley/rcrowley.git"
fi
git remote update "origin"
if [ ! -f ".git/refs/heads/master" ]
then rm -f ".profile" "bootstrap.sh"
fi
git merge "origin/master"

# Clone www's dependencies, install www, and start it.
if [ -z "$MAC_OS_X" ]
then
    . ".profile.d/go.sh"
    go get "code.google.com/p/go.tools/cmd/goimports"
    mkdir -p "src/github.com/rcrowley"
    if [ ! -d "src/github.com/rcrowley/go-metrics" ]
    then git clone "git@github.com:rcrowley/go-metrics.git" "src/github.com/rcrowley/go-metrics"
    fi
    if [ ! -d "src/github.com/rcrowley/go-tigertonic" ]
    then git clone "git@github.com:rcrowley/go-tigertonic.git" "src/github.com/rcrowley/go-tigertonic"
    fi
    go install "www"
    cat >"/etc/init/www.conf" <<EOF
description "www"
start on runlevel [2345]
stop on runlevel [!2345]
respawn
chdir /root
env GOMAXPROCS="4"
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
fi

# Copy authorized SSH public keys from rcrowley.org.
if [ -z "$MAC_OS_X" ]
then scp "rcrowley.org":".ssh/authorized_keys" ".ssh"
fi

# Copy GPG key pairs from rcrowley.org.
ssh "rcrowley.org" gpg --armor --export "packages@rcrowley.org" | gpg --import
ssh "rcrowley.org" gpg --armor --export-secret-keys "packages@rcrowley.org" | gpg --import || :
ssh "rcrowley.org" gpg --armor --export "r@rcrowley.org" | gpg --import
ssh "rcrowley.org" gpg --armor --export-secret-keys "r@rcrowley.org" | gpg --import || :

# Copy files from the old rcrowley.org to the new rcrowley.org.
if [ -z "$MAC_OS_X" ]
then
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
fi

# Start a GPG agent and cache the Debian archive.
. ".profile.d/gpg.sh"
if [ -z "$MAC_OS_X" ]
then
    freight cache
    apt-get update
fi

# Remove the old rcrowley.org's SSH host key.
if [ -z "$MAC_OS_X" ]
then
    grep -v "rcrowley.org" ".ssh/known_hosts" >"known_hosts"
    mv "known_hosts" ".ssh"
fi

# Parting advice.
set +x
echo >&2
if [ "$MAC_OS_X" ]
then echo "FileVault is now enabled but you need to reboot." >&2
else echo "Change the rcrowley.org A record to complete the change." >&2
fi
