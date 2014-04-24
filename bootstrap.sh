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
    plutil -convert "binary1" -o "$HOME/Library/Preferences/com.apple.Terminal.plist" "-" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Default Window Settings</key>
    <string>rcrowley</string>
    <key>DefaultProfilesVersion</key>
    <integer>1</integer>
    <key>HasMigratedDefaults</key>
    <true/>
    <key>NSColorPanelMode</key>
    <string>1</string>
    <key>NSColorPickerSlidersDefaults</key>
    <string>1</string>
    <key>NSFontPanelAttributes</key>
    <string>1, 4</string>
    <key>NSNavLastRootDirectory</key>
    <string>~/Documents</string>
    <key>NSWindow Frame NSColorPanel</key>
    <string>564 354 214 321 0 0 1440 878 </string>
    <key>NSWindow Frame NSFontPanel</key>
    <string>929 91 445 270 0 0 1440 878 </string>
    <key>NSWindow Frame TTAppPreferences</key>
    <string>757 233 590 478 0 0 1440 878 </string>
    <key>NSWindow Frame TTFindPanel</key>
    <string>926 548 483 144 0 0 1440 878 </string>
    <key>NSWindow Frame TTWindow</key>
    <string>65 67 1298 811 0 0 1440 878 </string>
    <key>NSWindow Frame TTWindow 18</key>
    <string>79 169 1298 709 0 0 1440 878 </string>
    <key>NSWindow Frame TTWindow Basic</key>
    <string>159 478 570 366 0 0 1440 878 </string>
    <key>NSWindow Frame TTWindow Pro</key>
    <string>79 169 1298 709 0 0 1440 878 </string>
    <key>NSWindow Frame TTWindow rcrowley</key>
    <string>70 62 1298 816 0 0 1440 878 </string>
    <key>ProfileCurrentVersion</key>
    <real>2.02</real>
    <key>SecureKeyboardEntry</key>
    <false/>
    <key>ShowTabBar</key>
    <true/>
    <key>Startup Window Settings</key>
    <string>rcrowley</string>
    <key>TTAppPreferences Selected Tab</key>
    <integer>1</integer>
    <key>Window Settings</key>
    <dict>
        <key>rcrowley</key>
        <dict>
            <key>ANSIBlackColor</key>
            <data>
            YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFy
            Y2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OViRjbGFz
            c1xOU0NvbG9yU3BhY2VVTlNSR0KAAhABTxAoMC4wMjc0NTA5ODAz
            OSAwLjIxMTc2NDcwNTkgMC4yNTg4MjM1Mjk0ANIQERITWiRjbGFz
            c25hbWVYJGNsYXNzZXNXTlNDb2xvcqISFFhOU09iamVjdF8QD05T
            S2V5ZWRBcmNoaXZlctEXGFRyb290gAEIERojLTI3O0FIT1xiZGaR
            lqGqsrW+0NPYAAAAAAAAAQEAAAAAAAAAGQAAAAAAAAAAAAAAAAAA
            ANo=
            </data>
            <key>ANSIBlueColor</key>
            <data>
            YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFy
            Y2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OViRjbGFz
            c1xOU0NvbG9yU3BhY2VVTlNSR0KAAhACTxAnMC4xNDkwMTk2MDc4
            IDAuNTQ1MDk4MDM5MiAwLjgyMzUyOTQxMTgA0hAREhNaJGNsYXNz
            bmFtZVgkY2xhc3Nlc1dOU0NvbG9yohIUWE5TT2JqZWN0XxAPTlNL
            ZXllZEFyY2hpdmVy0RcYVHJvb3SAAQgRGiMtMjc7QUhPXGJkZpCV
            oKmxtL3P0tcAAAAAAAABAQAAAAAAAAAZAAAAAAAAAAAAAAAAAAAA
            2Q==
            </data>
            <key>ANSIBrightBlackColor</key>
            <data>
            YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFy
            Y2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OViRjbGFz
            c1xOU0NvbG9yU3BhY2VVTlNSR0KAAhACTxAbMCAwLjE2ODYyNzQ1
            MSAwLjIxMTc2NDcwNTkA0hAREhNaJGNsYXNzbmFtZVgkY2xhc3Nl
            c1dOU0NvbG9yohIUWE5TT2JqZWN0XxAPTlNLZXllZEFyY2hpdmVy
            0RcYVHJvb3SAAQgRGiMtMjc7QUhPXGJkZoSJlJ2lqLHDxssAAAAA
            AAABAQAAAAAAAAAZAAAAAAAAAAAAAAAAAAAAzQ==
            </data>
            <key>ANSIBrightBlueColor</key>
            <data>
            YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFy
            Y2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OViRjbGFz
            c1xOU0NvbG9yU3BhY2VVTlNSR0KAAhACTxAnMC41MTM3MjU0OTAy
            IDAuNTgwMzkyMTU2OSAwLjU4ODIzNTI5NDEA0hAREhNaJGNsYXNz
            bmFtZVgkY2xhc3Nlc1dOU0NvbG9yohIUWE5TT2JqZWN0XxAPTlNL
            ZXllZEFyY2hpdmVy0RcYVHJvb3SAAQgRGiMtMjc7QUhPXGJkZpCV
            oKmxtL3P0tcAAAAAAAABAQAAAAAAAAAZAAAAAAAAAAAAAAAAAAAA
            2Q==
            </data>
            <key>ANSIBrightCyanColor</key>
            <data>
            YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFy
            Y2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OViRjbGFz
            c1xOU0NvbG9yU3BhY2VVTlNSR0KAAhACTxAlMC41NzY0NzA1ODgy
            IDAuNjMxMzcyNTQ5IDAuNjMxMzcyNTQ5ANIQERITWiRjbGFzc25h
            bWVYJGNsYXNzZXNXTlNDb2xvcqISFFhOU09iamVjdF8QD05TS2V5
            ZWRBcmNoaXZlctEXGFRyb290gAEIERojLTI3O0FIT1xiZGaOk56n
            r7K7zdDVAAAAAAAAAQEAAAAAAAAAGQAAAAAAAAAAAAAAAAAAANc=
            </data>
            <key>ANSIBrightGreenColor</key>
            <data>
            YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFy
            Y2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OViRjbGFz
            c1xOU0NvbG9yU3BhY2VVTlNSR0KAAhACTxAmMC4zNDUwOTgwMzky
            IDAuNDMxMzcyNTQ5IDAuNDU4ODIzNTI5NADSEBESE1okY2xhc3Nu
            YW1lWCRjbGFzc2VzV05TQ29sb3KiEhRYTlNPYmplY3RfEA9OU0tl
            eWVkQXJjaGl2ZXLRFxhUcm9vdIABCBEaIy0yNztBSE9cYmRmj5Sf
            qLCzvM7R1gAAAAAAAAEBAAAAAAAAABkAAAAAAAAAAAAAAAAAAADY
            </data>
            <key>ANSIBrightMagentaColor</key>
            <data>
            YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFy
            Y2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OViRjbGFz
            c1xOU0NvbG9yU3BhY2VVTlNSR0KAAhACTxAmMC40MjM1Mjk0MTE4
            IDAuNDQzMTM3MjU0OSAwLjc2ODYyNzQ1MQDSEBESE1okY2xhc3Nu
            YW1lWCRjbGFzc2VzV05TQ29sb3KiEhRYTlNPYmplY3RfEA9OU0tl
            eWVkQXJjaGl2ZXLRFxhUcm9vdIABCBEaIy0yNztBSE9cYmRmj5Sf
            qLCzvM7R1gAAAAAAAAEBAAAAAAAAABkAAAAAAAAAAAAAAAAAAADY
            </data>
            <key>ANSIBrightRedColor</key>
            <data>
            YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFy
            Y2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OViRjbGFz
            c1xOU0NvbG9yU3BhY2VVTlNSR0KAAhACTxAnMC43OTYwNzg0MzE0
            IDAuMjk0MTE3NjQ3MSAwLjA4NjI3NDUwOTgA0hAREhNaJGNsYXNz
            bmFtZVgkY2xhc3Nlc1dOU0NvbG9yohIUWE5TT2JqZWN0XxAPTlNL
            ZXllZEFyY2hpdmVy0RcYVHJvb3SAAQgRGiMtMjc7QUhPXGJkZpCV
            oKmxtL3P0tcAAAAAAAABAQAAAAAAAAAZAAAAAAAAAAAAAAAAAAAA
            2Q==
            </data>
            <key>ANSIBrightWhiteColor</key>
            <data>
            YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFy
            Y2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OViRjbGFz
            c1xOU0NvbG9yU3BhY2VVTlNSR0KAAhACTxAnMC45OTIxNTY4NjI3
            IDAuOTY0NzA1ODgyNCAwLjg5MDE5NjA3ODQA0hAREhNaJGNsYXNz
            bmFtZVgkY2xhc3Nlc1dOU0NvbG9yohIUWE5TT2JqZWN0XxAPTlNL
            ZXllZEFyY2hpdmVy0RcYVHJvb3SAAQgRGiMtMjc7QUhPXGJkZpCV
            oKmxtL3P0tcAAAAAAAABAQAAAAAAAAAZAAAAAAAAAAAAAAAAAAAA
            2Q==
            </data>
            <key>ANSIBrightYellowColor</key>
            <data>
            YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFy
            Y2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OViRjbGFz
            c1xOU0NvbG9yU3BhY2VVTlNSR0KAAhACTxAnMC4zOTYwNzg0MzE0
            IDAuNDgyMzUyOTQxMiAwLjUxMzcyNTQ5MDIA0hAREhNaJGNsYXNz
            bmFtZVgkY2xhc3Nlc1dOU0NvbG9yohIUWE5TT2JqZWN0XxAPTlNL
            ZXllZEFyY2hpdmVy0RcYVHJvb3SAAQgRGiMtMjc7QUhPXGJkZpCV
            oKmxtL3P0tcAAAAAAAABAQAAAAAAAAAZAAAAAAAAAAAAAAAAAAAA
            2Q==
            </data>
            <key>ANSICyanColor</key>
            <data>
            YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFy
            Y2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OViRjbGFz
            c1xOU0NvbG9yU3BhY2VVTlNSR0KAAhACTxAmMC4xNjQ3MDU4ODI0
            IDAuNjMxMzcyNTQ5IDAuNTk2MDc4NDMxNADSEBESE1okY2xhc3Nu
            YW1lWCRjbGFzc2VzV05TQ29sb3KiEhRYTlNPYmplY3RfEA9OU0tl
            eWVkQXJjaGl2ZXLRFxhUcm9vdIABCBEaIy0yNztBSE9cYmRmj5Sf
            qLCzvM7R1gAAAAAAAAEBAAAAAAAAABkAAAAAAAAAAAAAAAAAAADY
            </data>
            <key>ANSIGreenColor</key>
            <data>
            YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFy
            Y2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OViRjbGFz
            c1xOU0NvbG9yU3BhY2VVTlNSR0KAAhACTxATMC41MjE1Njg2Mjc1
            IDAuNiAwANIQERITWiRjbGFzc25hbWVYJGNsYXNzZXNXTlNDb2xv
            cqISFFhOU09iamVjdF8QD05TS2V5ZWRBcmNoaXZlctEXGFRyb290
            gAEIERojLTI3O0FIT1xiZGZ8gYyVnaCpu77DAAAAAAAAAQEAAAAA
            AAAAGQAAAAAAAAAAAAAAAAAAAMU=
            </data>
            <key>ANSIMagentaColor</key>
            <data>
            YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFy
            Y2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OViRjbGFz
            c1xOU0NvbG9yU3BhY2VVTlNSR0KAAhACTxAnMC44Mjc0NTA5ODA0
            IDAuMjExNzY0NzA1OSAwLjUwOTgwMzkyMTYA0hAREhNaJGNsYXNz
            bmFtZVgkY2xhc3Nlc1dOU0NvbG9yohIUWE5TT2JqZWN0XxAPTlNL
            ZXllZEFyY2hpdmVy0RcYVHJvb3SAAQgRGiMtMjc7QUhPXGJkZpCV
            oKmxtL3P0tcAAAAAAAABAQAAAAAAAAAZAAAAAAAAAAAAAAAAAAAA
            2Q==
            </data>
            <key>ANSIRedColor</key>
            <data>
            YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFy
            Y2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OViRjbGFz
            c1xOU0NvbG9yU3BhY2VVTlNSR0KAAhACTxArMC44Mjc0NTA5ODA0
            IDAuMDAzOTIxNTY4NjI3IDAuMDA3ODQzMTM3MjU1ANIQERITWiRj
            bGFzc25hbWVYJGNsYXNzZXNXTlNDb2xvcqISFFhOU09iamVjdF8Q
            D05TS2V5ZWRBcmNoaXZlctEXGFRyb290gAEIERojLTI3O0FIT1xi
            ZGaUmaSttbjB09bbAAAAAAAAAQEAAAAAAAAAGQAAAAAAAAAAAAAA
            AAAAAN0=
            </data>
            <key>ANSIWhiteColor</key>
            <data>
            YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFy
            Y2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OViRjbGFz
            c1xOU0NvbG9yU3BhY2VVTlNSR0KAAhACTxAnMC45MzMzMzMzMzMz
            IDAuOTA5ODAzOTIxNiAwLjgzNTI5NDExNzYA0hAREhNaJGNsYXNz
            bmFtZVgkY2xhc3Nlc1dOU0NvbG9yohIUWE5TT2JqZWN0XxAPTlNL
            ZXllZEFyY2hpdmVy0RcYVHJvb3SAAQgRGiMtMjc7QUhPXGJkZpCV
            oKmxtL3P0tcAAAAAAAABAQAAAAAAAAAZAAAAAAAAAAAAAAAAAAAA
            2Q==
            </data>
            <key>ANSIYellowColor</key>
            <data>
            YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFy
            Y2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OViRjbGFz
            c1xOU0NvbG9yU3BhY2VVTlNSR0KAAhACTxAbMC43MDk4MDM5MjE2
            IDAuNTM3MjU0OTAyIDAA0hAREhNaJGNsYXNzbmFtZVgkY2xhc3Nl
            c1dOU0NvbG9yohIUWE5TT2JqZWN0XxAPTlNLZXllZEFyY2hpdmVy
            0RcYVHJvb3SAAQgRGiMtMjc7QUhPXGJkZoSJlJ2lqLHDxssAAAAA
            AAABAQAAAAAAAAAZAAAAAAAAAAAAAAAAAAAAzQ==
            </data>
            <key>BackgroundBlur</key>
            <real>0.0</real>
            <key>BackgroundColor</key>
            <data>
            YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFy
            Y2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OViRjbGFz
            c1xOU0NvbG9yU3BhY2VVTlNSR0KAAhACTxAbMCAwLjE2ODYyNzQ1
            MSAwLjIxMTc2NDcwNTkA0hAREhNaJGNsYXNzbmFtZVgkY2xhc3Nl
            c1dOU0NvbG9yohIUWE5TT2JqZWN0XxAPTlNLZXllZEFyY2hpdmVy
            0RcYVHJvb3SAAQgRGiMtMjc7QUhPXGJkZoSJlJ2lqLHDxssAAAAA
            AAABAQAAAAAAAAAZAAAAAAAAAAAAAAAAAAAAzQ==
            </data>
            <key>CursorColor</key>
            <data>
            YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFy
            Y2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OViRjbGFz
            c1xOU0NvbG9yU3BhY2VVTlNSR0KAAhACTxAnMC45OTIxNTY4NjI3
            IDAuOTY0NzA1ODgyNCAwLjg5MDE5NjA3ODQA0hAREhNaJGNsYXNz
            bmFtZVgkY2xhc3Nlc1dOU0NvbG9yohIUWE5TT2JqZWN0XxAPTlNL
            ZXllZEFyY2hpdmVy0RcYVHJvb3SAAQgRGiMtMjc7QUhPXGJkZpCV
            oKmxtL3P0tcAAAAAAAABAQAAAAAAAAAZAAAAAAAAAAAAAAAAAAAA
            2Q==
            </data>
            <key>CursorType</key>
            <integer>1</integer>
            <key>Font</key>
            <data>
            YnBsaXN0MDDUAQIDBAUGGBlYJHZlcnNpb25YJG9iamVjdHNZJGFy
            Y2hpdmVyVCR0b3ASAAGGoKQHCBESVSRudWxs1AkKCwwNDg8QViRj
            bGFzc1ZOU05hbWVWTlNTaXplWE5TZkZsYWdzgAOAAiNAKgAAAAAA
            ABAQVk1vbmFjb9ITFBUWWiRjbGFzc25hbWVYJGNsYXNzZXNWTlNG
            b250ohUXWE5TT2JqZWN0XxAPTlNLZXllZEFyY2hpdmVy0RobVHJv
            b3SAAQgRGiMtMjc8QktSWWBpa212eH+Ej5ifoqu9wMUAAAAAAAAB
            AQAAAAAAAAAcAAAAAAAAAAAAAAAAAAAAxw==
            </data>
            <key>FontAntialias</key>
            <true/>
            <key>FontWidthSpacing</key>
            <real>0.99596774193548387</real>
            <key>Linewrap</key>
            <true/>
            <key>ProfileCurrentVersion</key>
            <real>2.02</real>
            <key>SelectionColor</key>
            <data>
            YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFy
            Y2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OViRjbGFz
            c1xOU0NvbG9yU3BhY2VVTlNSR0KAAhABTxAoMC4wMjc0NTA5ODAz
            OSAwLjIxMTc2NDcwNTkgMC4yNTg4MjM1Mjk0ANIQERITWiRjbGFz
            c25hbWVYJGNsYXNzZXNXTlNDb2xvcqISFFhOU09iamVjdF8QD05T
            S2V5ZWRBcmNoaXZlctEXGFRyb290gAEIERojLTI3O0FIT1xiZGaR
            lqGqsrW+0NPYAAAAAAAAAQEAAAAAAAAAGQAAAAAAAAAAAAAAAAAA
            ANo=
            </data>
            <key>ShowActiveProcessInTitle</key>
            <true/>
            <key>ShowCommandKeyInTitle</key>
            <true/>
            <key>ShowShellCommandInTitle</key>
            <false/>
            <key>ShowTTYNameInTitle</key>
            <true/>
            <key>ShowWindowSettingsNameInTitle</key>
            <false/>
            <key>TextBoldColor</key>
            <data>
            YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFy
            Y2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OViRjbGFz
            c1xOU0NvbG9yU3BhY2VVTlNSR0KAAhACTxAnMC45OTIxNTY4NjI3
            IDAuOTY0NzA1ODgyNCAwLjg5MDE5NjA3ODQA0hAREhNaJGNsYXNz
            bmFtZVgkY2xhc3Nlc1dOU0NvbG9yohIUWE5TT2JqZWN0XxAPTlNL
            ZXllZEFyY2hpdmVy0RcYVHJvb3SAAQgRGiMtMjc7QUhPXGJkZpCV
            oKmxtL3P0tcAAAAAAAABAQAAAAAAAAAZAAAAAAAAAAAAAAAAAAAA
            2Q==
            </data>
            <key>TextColor</key>
            <data>
            YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFy
            Y2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OViRjbGFz
            c1xOU0NvbG9yU3BhY2VVTlNSR0KAAhACTxAnMC45MzMzMzMzMzMz
            IDAuOTA5ODAzOTIxNiAwLjgzNTI5NDExNzYA0hAREhNaJGNsYXNz
            bmFtZVgkY2xhc3Nlc1dOU0NvbG9yohIUWE5TT2JqZWN0XxAPTlNL
            ZXllZEFyY2hpdmVy0RcYVHJvb3SAAQgRGiMtMjc7QUhPXGJkZpCV
            oKmxtL3P0tcAAAAAAAABAQAAAAAAAAAZAAAAAAAAAAAAAAAAAAAA
            2Q==
            </data>
            <key>UseBrightBold</key>
            <true/>
            <key>WindowTitle</key>
            <string>Terminal</string>
            <key>columnCount</key>
            <integer>161</integer>
            <key>name</key>
            <string>rcrowley</string>
            <key>rowCount</key>
            <integer>45</integer>
            <key>shellExitAction</key>
            <integer>2</integer>
            <key>type</key>
            <string>Window Settings</string>
            <key>useOptionAsMetaKey</key>
            <true/>
        </dict>
    </dict>
</dict>
</plist>
EOF

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
