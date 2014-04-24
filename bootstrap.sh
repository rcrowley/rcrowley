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
        read -p"$(tput "bold")Go turn on FileVault; press <ENTER> to continue.$(tput "sgr0") " >&2
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
    brew install "git" "gnupg" "gpg-agent" "tmux"

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
    mkdir -p "tmp"

    if [ ! -d "/Applications/Google Chrome.app" ]
    then
        if [ ! -f "tmp/chrome.dmg" ]
        then curl -o"tmp/chrome.dmg" "https://dl.google.com/chrome/mac/stable/GGRO/googlechrome.dmg"
        fi
        if [ ! -d "/Volumes/Google Chrome" ]
        then hdiutil attach -nobrowse "tmp/chrome.dmg"
        fi
        ditto --rsrc "/Volumes/Google Chrome/Google Chrome.app" "/Applications/Google Chrome.app"
        hdiutil detach "/Volumes/Google Chrome"
    fi

    if [ ! -d "/Applications/Papers2.app" ]
    then
        if [ ! -f "tmp/papers.dmg" ]
        then curl -o"tmp/papers.dmg" "http://downloads.mekentosj.com/papers_273.dmg"
        fi
        if [ ! -d "/Volumes/Papers2" ]
        then yes | PAGER=":" hdiutil attach -nobrowse "tmp/papers.dmg"
        fi
        ditto --rsrc "/Volumes/Papers2/Papers2.app" "/Applications/Papers2.app"
        hdiutil detach "/Volumes/Papers2"
    fi

    if [ ! -d "/Applications/VirtualBox.app" ]
    then
        if [ ! -f "tmp/virtualbox.dmg" ]
        then
            curl -s "https://www.virtualbox.org/wiki/Downloads" |
            grep -E -o 'http://download.virtualbox.org/virtualbox/[0-9]+\.[0-9]+\.[0-9]+/VirtualBox-[0-9]+\.[0-9]+\.[0-9]+-[0-9]+-OSX.dmg' |
            xargs curl -L -o"tmp/virtualbox.dmg"
        fi
        if [ ! -d "/Volumes/VirtualBox" ]
        then hdiutil attach "tmp/virtualbox.dmg"
        fi
        installer -package "/Volumes/VirtualBox/VirtualBox.pkg" -target "/"
        hdiutil detach "/Volumes/VirtualBox"
    fi

    set +x
    echo >&2
    read -p"$(tput "bold")Install 1Password, Caffeine, Slack, and Textual from the Mac App Store; press <ENTER> to continue.$(tput "sgr0") "
    echo >&2
    set -x
    open -W "/Applications/App Store.app"

    # Configure Terminal.app with Solarized colors, 161 columns, and so on.
    # This could have beem much simpler but we need the PlistBuddy shenanigans
    # in order to make Terminal.app actually accept our desired window size.
    defaults write "com.apple.Terminal" "Window Settings" '
        {
            Basic =     {
                Font = <62706c69 73743030 d4010203 04050618 19582476 65727369 6f6e5824 6f626a65 63747359 24617263 68697665 72542474 6f701200 0186a0a4 07081112 55246e75 6c6cd409 0a0b0c0d 0e0f1056 4e535369 7a65584e 5366466c 61677356 4e534e61 6d655624 636c6173 73234026 00000000 00001010 80028003 5d4d656e 6c6f2d52 6567756c 6172d213 1415165a 24636c61 73736e61 6d655824 636c6173 73657356 4e53466f 6e74a215 17584e53 4f626a65 63745f10 0f4e534b 65796564 41726368 69766572 d11a1b54 726f6f74 80010811 1a232d32 373c424b 525b6269 72747678 868b969f a6a9b2c4 c7cc0000 00000000 01010000 00000000 001c0000 00000000 00000000 00000000 00ce>;
                FontAntialias = 1;
                FontWidthSpacing = 1;
                ProfileCurrentVersion = "2.02";
                name = Basic;
                type = "Window Settings";
            };
            rcrowley =     {
                ANSIBlackColor = <62706c69 73743030 d4010203 04050615 16582476 65727369 6f6e5824 6f626a65 63747359 24617263 68697665 72542474 6f701200 0186a0a3 07080f55 246e756c 6cd3090a 0b0c0d0e 554e5352 47425c4e 53436f6c 6f725370 61636556 24636c61 73734f10 28302e30 32373435 30393830 33392030 2e323131 37363437 30353920 302e3235 38383233 35323934 00100180 02d21011 12135a24 636c6173 736e616d 65582463 6c617373 6573574e 53436f6c 6f72a212 14584e53 4f626a65 63745f10 0f4e534b 65796564 41726368 69766572 d1171854 726f6f74 80010811 1a232d32 373b4148 4e5b628d 8f9196a1 aab2b5be d0d3d800 00000000 00010100 00000000 00001900 00000000 00000000 00000000 0000da>;
                ANSIBlueColor = <62706c69 73743030 d4010203 04050615 16582476 65727369 6f6e5824 6f626a65 63747359 24617263 68697665 72542474 6f701200 0186a0a3 07080f55 246e756c 6cd3090a 0b0c0d0e 554e5352 47425c4e 53436f6c 6f725370 61636556 24636c61 73734f10 27302e31 34393031 39363037 3820302e 35343530 39383033 39322030 2e383233 35323934 31313800 10028002 d2101112 135a2463 6c617373 6e616d65 5824636c 61737365 73574e53 436f6c6f 72a21214 584e534f 626a6563 745f100f 4e534b65 79656441 72636869 766572d1 17185472 6f6f7480 0108111a 232d3237 3b41484e 5b628c8e 9095a0a9 b1b4bdcf d2d70000 00000000 01010000 00000000 00190000 00000000 00000000 00000000 00d9>;
                ANSIBrightBlackColor = <62706c69 73743030 d4010203 04050615 16582476 65727369 6f6e5824 6f626a65 63747359 24617263 68697665 72542474 6f701200 0186a0a3 07080f55 246e756c 6cd3090a 0b0c0d0e 554e5352 47425c4e 53436f6c 6f725370 61636556 24636c61 73734f10 1b302030 2e313638 36323734 35312030 2e323131 37363437 30353900 10028002 d2101112 135a2463 6c617373 6e616d65 5824636c 61737365 73574e53 436f6c6f 72a21214 584e534f 626a6563 745f100f 4e534b65 79656441 72636869 766572d1 17185472 6f6f7480 0108111a 232d3237 3b41484e 5b628082 8489949d a5a8b1c3 c6cb0000 00000000 01010000 00000000 00190000 00000000 00000000 00000000 00cd>;
                ANSIBrightBlueColor = <62706c69 73743030 d4010203 04050615 16582476 65727369 6f6e5824 6f626a65 63747359 24617263 68697665 72542474 6f701200 0186a0a3 07080f55 246e756c 6cd3090a 0b0c0d0e 554e5352 47425c4e 53436f6c 6f725370 61636556 24636c61 73734f10 27302e35 31333732 35343930 3220302e 35383033 39323135 36392030 2e353838 32333532 39343100 10028002 d2101112 135a2463 6c617373 6e616d65 5824636c 61737365 73574e53 436f6c6f 72a21214 584e534f 626a6563 745f100f 4e534b65 79656441 72636869 766572d1 17185472 6f6f7480 0108111a 232d3237 3b41484e 5b628c8e 9095a0a9 b1b4bdcf d2d70000 00000000 01010000 00000000 00190000 00000000 00000000 00000000 00d9>;
                ANSIBrightCyanColor = <62706c69 73743030 d4010203 04050615 16582476 65727369 6f6e5824 6f626a65 63747359 24617263 68697665 72542474 6f701200 0186a0a3 07080f55 246e756c 6cd3090a 0b0c0d0e 554e5352 47425c4e 53436f6c 6f725370 61636556 24636c61 73734f10 25302e35 37363437 30353838 3220302e 36333133 37323534 3920302e 36333133 37323534 39001002 8002d210 1112135a 24636c61 73736e61 6d655824 636c6173 73657357 4e53436f 6c6f72a2 1214584e 534f626a 6563745f 100f4e53 4b657965 64417263 68697665 72d11718 54726f6f 74800108 111a232d 32373b41 484e5b62 8a8c8e93 9ea7afb2 bbcdd0d5 00000000 00000101 00000000 00000019 00000000 00000000 00000000 000000d7>;
                ANSIBrightGreenColor = <62706c69 73743030 d4010203 04050615 16582476 65727369 6f6e5824 6f626a65 63747359 24617263 68697665 72542474 6f701200 0186a0a3 07080f55 246e756c 6cd3090a 0b0c0d0e 554e5352 47425c4e 53436f6c 6f725370 61636556 24636c61 73734f10 26302e33 34353039 38303339 3220302e 34333133 37323534 3920302e 34353838 32333532 39340010 028002d2 10111213 5a24636c 6173736e 616d6558 24636c61 73736573 574e5343 6f6c6f72 a2121458 4e534f62 6a656374 5f100f4e 534b6579 65644172 63686976 6572d117 1854726f 6f748001 08111a23 2d32373b 41484e5b 628b8d8f 949fa8b0 b3bcced1 d6000000 00000001 01000000 00000000 19000000 00000000 00000000 00000000 d8>;
                ANSIBrightMagentaColor = <62706c69 73743030 d4010203 04050615 16582476 65727369 6f6e5824 6f626a65 63747359 24617263 68697665 72542474 6f701200 0186a0a3 07080f55 246e756c 6cd3090a 0b0c0d0e 554e5352 47425c4e 53436f6c 6f725370 61636556 24636c61 73734f10 26302e34 32333532 39343131 3820302e 34343331 33373235 34392030 2e373638 36323734 35310010 028002d2 10111213 5a24636c 6173736e 616d6558 24636c61 73736573 574e5343 6f6c6f72 a2121458 4e534f62 6a656374 5f100f4e 534b6579 65644172 63686976 6572d117 1854726f 6f748001 08111a23 2d32373b 41484e5b 628b8d8f 949fa8b0 b3bcced1 d6000000 00000001 01000000 00000000 19000000 00000000 00000000 00000000 d8>;
                ANSIBrightRedColor = <62706c69 73743030 d4010203 04050615 16582476 65727369 6f6e5824 6f626a65 63747359 24617263 68697665 72542474 6f701200 0186a0a3 07080f55 246e756c 6cd3090a 0b0c0d0e 554e5352 47425c4e 53436f6c 6f725370 61636556 24636c61 73734f10 27302e37 39363037 38343331 3420302e 32393431 31373634 37312030 2e303836 32373435 30393800 10028002 d2101112 135a2463 6c617373 6e616d65 5824636c 61737365 73574e53 436f6c6f 72a21214 584e534f 626a6563 745f100f 4e534b65 79656441 72636869 766572d1 17185472 6f6f7480 0108111a 232d3237 3b41484e 5b628c8e 9095a0a9 b1b4bdcf d2d70000 00000000 01010000 00000000 00190000 00000000 00000000 00000000 00d9>;
                ANSIBrightWhiteColor = <62706c69 73743030 d4010203 04050615 16582476 65727369 6f6e5824 6f626a65 63747359 24617263 68697665 72542474 6f701200 0186a0a3 07080f55 246e756c 6cd3090a 0b0c0d0e 554e5352 47425c4e 53436f6c 6f725370 61636556 24636c61 73734f10 27302e39 39323135 36383632 3720302e 39363437 30353838 32342030 2e383930 31393630 37383400 10028002 d2101112 135a2463 6c617373 6e616d65 5824636c 61737365 73574e53 436f6c6f 72a21214 584e534f 626a6563 745f100f 4e534b65 79656441 72636869 766572d1 17185472 6f6f7480 0108111a 232d3237 3b41484e 5b628c8e 9095a0a9 b1b4bdcf d2d70000 00000000 01010000 00000000 00190000 00000000 00000000 00000000 00d9>;
                ANSIBrightYellowColor = <62706c69 73743030 d4010203 04050615 16582476 65727369 6f6e5824 6f626a65 63747359 24617263 68697665 72542474 6f701200 0186a0a3 07080f55 246e756c 6cd3090a 0b0c0d0e 554e5352 47425c4e 53436f6c 6f725370 61636556 24636c61 73734f10 27302e33 39363037 38343331 3420302e 34383233 35323934 31322030 2e353133 37323534 39303200 10028002 d2101112 135a2463 6c617373 6e616d65 5824636c 61737365 73574e53 436f6c6f 72a21214 584e534f 626a6563 745f100f 4e534b65 79656441 72636869 766572d1 17185472 6f6f7480 0108111a 232d3237 3b41484e 5b628c8e 9095a0a9 b1b4bdcf d2d70000 00000000 01010000 00000000 00190000 00000000 00000000 00000000 00d9>;
                ANSICyanColor = <62706c69 73743030 d4010203 04050615 16582476 65727369 6f6e5824 6f626a65 63747359 24617263 68697665 72542474 6f701200 0186a0a3 07080f55 246e756c 6cd3090a 0b0c0d0e 554e5352 47425c4e 53436f6c 6f725370 61636556 24636c61 73734f10 26302e31 36343730 35383832 3420302e 36333133 37323534 3920302e 35393630 37383433 31340010 028002d2 10111213 5a24636c 6173736e 616d6558 24636c61 73736573 574e5343 6f6c6f72 a2121458 4e534f62 6a656374 5f100f4e 534b6579 65644172 63686976 6572d117 1854726f 6f748001 08111a23 2d32373b 41484e5b 628b8d8f 949fa8b0 b3bcced1 d6000000 00000001 01000000 00000000 19000000 00000000 00000000 00000000 d8>;
                ANSIGreenColor = <62706c69 73743030 d4010203 04050615 16582476 65727369 6f6e5824 6f626a65 63747359 24617263 68697665 72542474 6f701200 0186a0a3 07080f55 246e756c 6cd3090a 0b0c0d0e 554e5352 47425c4e 53436f6c 6f725370 61636556 24636c61 73734f10 13302e35 32313536 38363237 3520302e 36203000 10028002 d2101112 135a2463 6c617373 6e616d65 5824636c 61737365 73574e53 436f6c6f 72a21214 584e534f 626a6563 745f100f 4e534b65 79656441 72636869 766572d1 17185472 6f6f7480 0108111a 232d3237 3b41484e 5b62787a 7c818c95 9da0a9bb bec30000 00000000 01010000 00000000 00190000 00000000 00000000 00000000 00c5>;
                ANSIMagentaColor = <62706c69 73743030 d4010203 04050615 16582476 65727369 6f6e5824 6f626a65 63747359 24617263 68697665 72542474 6f701200 0186a0a3 07080f55 246e756c 6cd3090a 0b0c0d0e 554e5352 47425c4e 53436f6c 6f725370 61636556 24636c61 73734f10 27302e38 32373435 30393830 3420302e 32313137 36343730 35392030 2e353039 38303339 32313600 10028002 d2101112 135a2463 6c617373 6e616d65 5824636c 61737365 73574e53 436f6c6f 72a21214 584e534f 626a6563 745f100f 4e534b65 79656441 72636869 766572d1 17185472 6f6f7480 0108111a 232d3237 3b41484e 5b628c8e 9095a0a9 b1b4bdcf d2d70000 00000000 01010000 00000000 00190000 00000000 00000000 00000000 00d9>;
                ANSIRedColor = <62706c69 73743030 d4010203 04050615 16582476 65727369 6f6e5824 6f626a65 63747359 24617263 68697665 72542474 6f701200 0186a0a3 07080f55 246e756c 6cd3090a 0b0c0d0e 554e5352 47425c4e 53436f6c 6f725370 61636556 24636c61 73734f10 2b302e38 32373435 30393830 3420302e 30303339 32313536 38363237 20302e30 30373834 33313337 32353500 10028002 d2101112 135a2463 6c617373 6e616d65 5824636c 61737365 73574e53 436f6c6f 72a21214 584e534f 626a6563 745f100f 4e534b65 79656441 72636869 766572d1 17185472 6f6f7480 0108111a 232d3237 3b41484e 5b629092 9499a4ad b5b8c1d3 d6db0000 00000000 01010000 00000000 00190000 00000000 00000000 00000000 00dd>;
                ANSIWhiteColor = <62706c69 73743030 d4010203 04050615 16582476 65727369 6f6e5824 6f626a65 63747359 24617263 68697665 72542474 6f701200 0186a0a3 07080f55 246e756c 6cd3090a 0b0c0d0e 554e5352 47425c4e 53436f6c 6f725370 61636556 24636c61 73734f10 27302e39 33333333 33333333 3320302e 39303938 30333932 31362030 2e383335 32393431 31373600 10028002 d2101112 135a2463 6c617373 6e616d65 5824636c 61737365 73574e53 436f6c6f 72a21214 584e534f 626a6563 745f100f 4e534b65 79656441 72636869 766572d1 17185472 6f6f7480 0108111a 232d3237 3b41484e 5b628c8e 9095a0a9 b1b4bdcf d2d70000 00000000 01010000 00000000 00190000 00000000 00000000 00000000 00d9>;
                ANSIYellowColor = <62706c69 73743030 d4010203 04050615 16582476 65727369 6f6e5824 6f626a65 63747359 24617263 68697665 72542474 6f701200 0186a0a3 07080f55 246e756c 6cd3090a 0b0c0d0e 554e5352 47425c4e 53436f6c 6f725370 61636556 24636c61 73734f10 1b302e37 30393830 33393231 3620302e 35333732 35343930 32203000 10028002 d2101112 135a2463 6c617373 6e616d65 5824636c 61737365 73574e53 436f6c6f 72a21214 584e534f 626a6563 745f100f 4e534b65 79656441 72636869 766572d1 17185472 6f6f7480 0108111a 232d3237 3b41484e 5b628082 8489949d a5a8b1c3 c6cb0000 00000000 01010000 00000000 00190000 00000000 00000000 00000000 00cd>;
                BackgroundBlur = 0;
                BackgroundColor = <62706c69 73743030 d4010203 04050615 16582476 65727369 6f6e5824 6f626a65 63747359 24617263 68697665 72542474 6f701200 0186a0a3 07080f55 246e756c 6cd3090a 0b0c0d0e 554e5352 47425c4e 53436f6c 6f725370 61636556 24636c61 73734f10 1b302030 2e313638 36323734 35312030 2e323131 37363437 30353900 10028002 d2101112 135a2463 6c617373 6e616d65 5824636c 61737365 73574e53 436f6c6f 72a21214 584e534f 626a6563 745f100f 4e534b65 79656441 72636869 766572d1 17185472 6f6f7480 0108111a 232d3237 3b41484e 5b628082 8489949d a5a8b1c3 c6cb0000 00000000 01010000 00000000 00190000 00000000 00000000 00000000 00cd>;
                CursorColor = <62706c69 73743030 d4010203 04050615 16582476 65727369 6f6e5824 6f626a65 63747359 24617263 68697665 72542474 6f701200 0186a0a3 07080f55 246e756c 6cd3090a 0b0c0d0e 554e5352 47425c4e 53436f6c 6f725370 61636556 24636c61 73734f10 27302e39 39323135 36383632 3720302e 39363437 30353838 32342030 2e383930 31393630 37383400 10028002 d2101112 135a2463 6c617373 6e616d65 5824636c 61737365 73574e53 436f6c6f 72a21214 584e534f 626a6563 745f100f 4e534b65 79656441 72636869 766572d1 17185472 6f6f7480 0108111a 232d3237 3b41484e 5b628c8e 9095a0a9 b1b4bdcf d2d70000 00000000 01010000 00000000 00190000 00000000 00000000 00000000 00d9>;
                Font = <62706c69 73743030 d4010203 04050618 19582476 65727369 6f6e5824 6f626a65 63747359 24617263 68697665 72542474 6f701200 0186a0a4 07081112 55246e75 6c6cd409 0a0b0c0d 0e0f1056 4e535369 7a65584e 5366466c 61677356 4e534e61 6d655624 636c6173 73234028 00000000 00001010 80028003 564d6f6e 61636fd2 13141516 5a24636c 6173736e 616d6558 24636c61 73736573 564e5346 6f6e74a2 1517584e 534f626a 6563745f 100f4e53 4b657965 64417263 68697665 72d11a1b 54726f6f 74800108 111a232d 32373c42 4b525b62 69727476 787f848f 989fa2ab bdc0c500 00000000 00010100 00000000 00001c00 00000000 00000000 00000000 0000c7>;
                FontAntialias = 1;
                FontWidthSpacing = 1;
                ProfileCurrentVersion = "2.02";
                SelectionColor = <62706c69 73743030 d4010203 04050615 16582476 65727369 6f6e5824 6f626a65 63747359 24617263 68697665 72542474 6f701200 0186a0a3 07080f55 246e756c 6cd3090a 0b0c0d0e 554e5352 47425c4e 53436f6c 6f725370 61636556 24636c61 73734f10 28302e30 32373435 30393830 33392030 2e323131 37363437 30353920 302e3235 38383233 35323934 00100180 02d21011 12135a24 636c6173 736e616d 65582463 6c617373 6573574e 53436f6c 6f72a212 14584e53 4f626a65 63745f10 0f4e534b 65796564 41726368 69766572 d1171854 726f6f74 80010811 1a232d32 373b4148 4e5b628d 8f9196a1 aab2b5be d0d3d800 00000000 00010100 00000000 00001900 00000000 00000000 00000000 0000da>;
                TextBoldColor = <62706c69 73743030 d4010203 04050615 16582476 65727369 6f6e5824 6f626a65 63747359 24617263 68697665 72542474 6f701200 0186a0a3 07080f55 246e756c 6cd3090a 0b0c0d0e 554e5352 47425c4e 53436f6c 6f725370 61636556 24636c61 73734f10 27302e39 39323135 36383632 3720302e 39363437 30353838 32342030 2e383930 31393630 37383400 10028002 d2101112 135a2463 6c617373 6e616d65 5824636c 61737365 73574e53 436f6c6f 72a21214 584e534f 626a6563 745f100f 4e534b65 79656441 72636869 766572d1 17185472 6f6f7480 0108111a 232d3237 3b41484e 5b628c8e 9095a0a9 b1b4bdcf d2d70000 00000000 01010000 00000000 00190000 00000000 00000000 00000000 00d9>;
                TextColor = <62706c69 73743030 d4010203 04050615 16582476 65727369 6f6e5824 6f626a65 63747359 24617263 68697665 72542474 6f701200 0186a0a3 07080f55 246e756c 6cd3090a 0b0c0d0e 554e5352 47425c4e 53436f6c 6f725370 61636556 24636c61 73734f10 27302e39 33333333 33333333 3320302e 39303938 30333932 31362030 2e383335 32393431 31373600 10028002 d2101112 135a2463 6c617373 6e616d65 5824636c 61737365 73574e53 436f6c6f 72a21214 584e534f 626a6563 745f100f 4e534b65 79656441 72636869 766572d1 17185472 6f6f7480 0108111a 232d3237 3b41484e 5b628c8e 9095a0a9 b1b4bdcf d2d70000 00000000 01010000 00000000 00190000 00000000 00000000 00000000 00d9>;
                name = rcrowley;
                type = "Window Settings";
            };
        }
    '
    #killall "cfprefsd"
    /usr/libexec/PlistBuddy -c "Add :Window\ Settings:rcrowley:columnCount integer 161" "$HOME/Library/Preferences/com.apple.Terminal.plist"
    /usr/libexec/PlistBuddy -c "Add :Window\ Settings:rcrowley:rowCount integer 43" "$HOME/Library/Preferences/com.apple.Terminal.plist"
    defaults write "com.apple.Terminal" "Default Window Settings" "rcrowley"
    defaults write "com.apple.Terminal" "Startup Window Settings" "rcrowley"

    # FIXME Trackpad prefs.
    # FIXME Show home directory in Finder sidebar.
    # FIXME Don't show the clock in the menu bar.
    # FIXME Messages logins without storing passwords?
    # FIXME Dock contents.
    # FIXME Launch Caffeine.
    # FIXME Chrome extensions and bookmarks.  Maybe via Chrome itself?

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
then echo "$(tput "bold")FileVault is now enabled but you need to reboot.$(tput "sgr0")" >&2
else echo "$(tput "bold")Change the rcrowley.org A record to complete the change.$(tput "sgr0")" >&2
fi
