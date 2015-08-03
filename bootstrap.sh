# rcrowley-ify a computer!

# TODO Chef install.sh, chef.patch, and `sudo /opt/chef/embedded/bin/gem install --no-rdoc --no-ri "knife-ec2" "unf"`

# Go version to install.
VERSION="1.4.2"
BUILD="rcrowley1"

#/ Usage: sh bootstrap.sh

set -e

usage() {
    grep "^#/" "$0" | cut -c"4-" >&2
    exit "$1"
}
while [ "$#" -gt 0 ]
do
    case "$1" in
        -h|--help) usage 0;;
        -*) usage 1;;
        *) break;;
    esac
done

if [ "$(uname)" = "Darwin" ]
then sudo -p"$0 requires %U privileges! Password: " -v
fi

set -x

# Add known hosts entries and an SSH control socket to make this program
# more headless.
mkdir -m"700" -p ".ssh"
if ! grep -q "github.com" ".ssh/known_hosts"
then ssh-keyscan "github.com" >>".ssh/known_hosts"
fi
if ! grep -q "rcrowley.org" ".ssh/known_hosts"
then ssh-keyscan "rcrowley.org" >>".ssh/known_hosts"
fi
if [ ! -f ".ssh/config" ]
then cat >".ssh/config" <<EOF
HashKnownHosts no
ServerAliveCountMax 4320
ServerAliveInterval 10
TCPKeepAlive no
Host rcrowley.org
    ControlMaster auto
    ControlPath /tmp/ssh-control-%r@%h:%p
    ControlPersist 43200
    ForwardAgent yes
    User ubuntu
EOF
fi

###############################################################################
# Begin universal Mac bootstrapping.
(

if [ "$(uname)" != "Darwin" ]
then exit
fi

# Setup FileVault and leave its recovery key in the home directory.
FDESETUP=""
if ! sudo fdesetup list
then
    sudo fdesetup enable -outputplist -user "$USER" | tee "filevault.plist"
    FDESETUP="yes"
fi

# Ensure we have an SSH private key available to us.
if [ ! -f "$HOME/.ssh/id_rsa" ]
then
    ssh-keygen -f"$HOME/.ssh/id_rsa"
    cat "$HOME/.ssh/id_rsa.pub"
    read -p"$(tput "bold")Authorize this SSH public key on rcrowley.org; press <ENTER> to continue.$(tput "sgr0") " >&2
fi
ssh-add -l || ssh-add

# Configure the built-in SSH agent to forget decrypted keys after ten minutes
# of inactivity.
sudo tee "/usr/local/bin/ssh" >"/dev/null" <<'EOF'
#!/bin/sh

set -e

# Mark the SSH agent as having been used to stave off purging private keys.
touch "$HOME/.ssh-agent-last-used"

exec "/usr/bin/ssh" "$@"
EOF
sudo chmod 755 "/usr/local/bin/ssh"
sudo tee "/usr/local/bin/empty-unused-ssh-agent" >"/dev/null" <<'EOF'
#!/bin/sh

set -e

# Don't bother if the SSH agent's been used in the last ten minutes.
if ! find "$HOME/.ssh-agent-last-used" -mmin "+10" | grep -q ".ssh-agent-last-used"
then
    echo "empty-unused-ssh-agent: not expired" >&2
    exit
fi

# Empty the SSH agent of all decrypted private keys.
find -L "/tmp" -name "launch-*" 2>"/dev/null" |
xargs -I"_" find "_" -name "Listeners" |
while read SSH_AUTH_SOCK
do SSH_AUTH_SOCK="$SSH_AUTH_SOCK" ssh-add -D
done
EOF
sudo chmod 755 "/usr/local/bin/empty-unused-ssh-agent"
#EDITOR="tee" crontab -e <<'EOF'
#MAILTO=""
#* * * * * /usr/local/bin/empty-unused-ssh-agent
#EOF

# Reorder the PATH environment variable to put /usr/local ahead of /usr.
sudo tee "/etc/paths" >"/dev/null" <<EOF
/usr/local/bin
/usr/local/sbin
/usr/bin
/usr/sbin
/bin
/sbin
EOF

# Install Homebrew.
if [ ! -f "/usr/local/bin/brew" ]
then ruby -e "$(curl -LSfs "https://raw.githubusercontent.com/Homebrew/install/master/install")"
fi

# Install the XCode command-line tools.  This purposely comes after
# Homebrew because Homebrew behaves erratically when compilers are
# already available.
if [ ! -d "/Library/Developer" ]
then xcode-select --install
fi

# Various dependencies and nice-to-haves.
brew upgrade "git" "gnupg" "gpg-agent" "markdown" "mercurial" "node" "s3cmd" "tmux" "watch" || :
brew upgrade "homebrew/php/php54-mcrypt" || :
npm install "keybase"
sudo easy_install "pip"
sudo pip install "awscli"
sudo pip install "virtualenv"

# Go releases aren't necessarily tagged to every OS X release so we have to
# be a bit more clever about finding the URL of the package to install.
if [ ! -d "/usr/local/go" ]
then
    cd "tmp"
    seq "$(sw_vers -productVersion | cut -d"." -f"2")" "-1" "6" |
    while read MINOR
    do
        curl -O -f "https://storage.googleapis.com/golang/go$VERSION.darwin-amd64-osx10.$MINOR.pkg" || continue
        sudo installer -package "go$VERSION.darwin-amd64-osx10.$MINOR.pkg" -target "/"
        break
    done
    cd ".."
fi

# Heroku toolbelt.
if [ ! -f "/usr/bin/heroku" ]
then
    if [ ! -f "tmp/heroku.pkg" ]
    then curl -L -o"tmp/heroku.pkg" "https://toolbelt.heroku.com/download/osx"
    fi
    sudo installer -package "tmp/heroku.pkg" -target "/"
fi

# Java 6 from Apple <http://support.apple.com/kb/dl1572>.
if [ ! -d "/System/Library/Frameworks/JavaVM.framework" ]
then
    if [ ! -f "tmp/java6.dmg" ]
    then curl -L -o"tmp/java6.dmg" "http://support.apple.com/downloads/DL1572/en_US/JavaForOSX2013-05.dmg"
    fi
    if [ ! -d "/Volumes/Java for OS X 2013-005" ]
    then hdiutil attach -nobrowse "tmp/java6.dmg"
    fi
    sudo installer -package "/Volumes/Java for OS X 2013-005/JavaForOSX.pkg" -target "/"
    hdiutil detach "/Volumes/Java for OS X 2013-005"
fi

# Java 7 from Oracle <http://www.oracle.com/technetwork/java/javase/downloads/jdk7-downloads-1880260.html>.
if [ ! -d "/Library/Java/JavaVirtualMachines/jdk1.7.0_55.jdk/Contents/Home" ]
then
    if [ ! -f "tmp/java7.dmg" ]
    then curl -L -o"tmp/java7.dmg" "http://download.oracle.com/otn-pub/java/jdk/7u55-b13/jdk-7u55-macosx-x64.dmg?AuthParam=1398831473_a6ff4463d1f0ed16478723a653a7befe" # XXX This link may expire.
    fi
    if [ ! -d "/Volumes/JDK 7 Update 55" ]
    then hdiutil attach -nobrowse "tmp/java7.dmg"
    fi
    ls -l "/Volumes/JDK 7 Update 55"
    sudo installer -package "/Volumes/JDK 7 Update 55/JDK 7 Update 55.pkg" -target "/"
    hdiutil detach "/Volumes/JDK 7 Update 55"
fi

# TODO Java 8 from Oracle.

# Update all installed software aggressively.
sudo softwareupdate -i -a

)
# End universal Mac bootstrapping.
###############################################################################
# Begin rcrowley Mac bootstrapping.
(

if [ "$(uname)" != "Darwin" ]
then exit
fi

mkdir -p "tmp"

# Dropbox
if [ ! -d "/Applications/Dropbox.app" ]
then
    if [ ! -f "tmp/dropbox.dmg" ]
    then
        curl -s "https://www.dropbox.com/release_notes" |
        grep "release_type_stable" |
        head -n"1" |
        sed -E 's/^.*>([0-9]+\.[0-9]+\.[0-9]+)<.*$/\1/' |
        xargs -I"_" curl -o"tmp/dropbox.dmg" "https://d1ilhw0800yew8.cloudfront.net/client/Dropbox%20_.dmg"
    fi
    if [ ! -d "/Volumes/Dropbox Installer" ]
    then hdiutil attach -nobrowse "tmp/dropbox.dmg"
    fi
    ditto --rsrc "/Volumes/Dropbox Installer/Dropbox.app" "/Applications/Dropbox.app"
    hdiutil detach "/Volumes/Dropbox Installer"
fi

# Google Chrome
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

# OmniGraffle
if [ ! -d "/Applications/OmniGraffle.app" ]
then
    if [ ! -f "tmp/omnigraffle.dmg" ]
    then curl -L -o"tmp/omnigraffle.dmg" "https://www.omnigroup.com/download/latest/omnigraffle"
    fi
    if [ ! -d "/Volumes/OmniGraffle" ]
    then yes | PAGER=":" hdiutil attach -nobrowse "tmp/omnigraffle.dmg"
    fi
    ditto --rsrc "/Volumes/OmniGraffle/OmniGraffle.app" "/Applications/OmniGraffle.app"
    hdiutil detach "/Volumes/OmniGraffle"
fi

# Papers 3
if [ ! -d "/Applications/Papers.app" ]
then
    if [ ! -f "tmp/papers.dmg" ]
    then curl -L -o"tmp/papers.dmg" "http://papersapp.com/downloads/mac/3"
    fi
    if [ ! -d "/Volumes/Papers3" ]
    then yes | PAGER=":" hdiutil attach -nobrowse "tmp/papers.dmg"
    fi
    ditto --rsrc "/Volumes/Papers3/Papers.app" "/Applications/Papers.app"
    hdiutil detach "/Volumes/Papers3"
fi

# Skype
if [ ! -d "/Applications/Skype.app" ]
then
    if [ ! -f "tmp/skype.dmg" ]
    then curl -L -o"tmp/skype.dmg" "http://www.skype.com/go/getskype-macosx"
    fi
    if [ ! -d "/Volumes/Skype" ]
    then hdiutil attach -nobrowse "tmp/skype.dmg"
    fi
    ditto --rsrc "/Volumes/Skype/Skype.app" "/Applications/Skype.app"
    hdiutil detach "/Volumes/Skype"
fi

# VirtualBox
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

# Viscosity
if [ ! -d "/Applications/Viscosity.app" ]
then
    if [ ! -f "tmp/viscosity.dmg" ]
    then curl -L -o"tmp/viscosity.dmg" "http://www.sparklabs.com/downloads/Viscosity.dmg"
    fi
    if [ ! -d "/Volumes/Viscosity" ]
    then hdiutil attach "tmp/viscosity.dmg"
    fi
    ditto --rsrc "/Volumes/Viscosity/Viscosity.app" "/Applications/Viscosity.app"
    hdiutil detach "/Volumes/Viscosity"
fi

# Wickr
if [ ! -d "/Applications/Wickr.app" ]
then
    if [ ! -f "tmp/wickr.dmg" ]
    then curl -o"tmp/wickr.dmg" "https://mywickr.info/download.php?p=2"
    fi
    if [ ! -d "/Volumes/Wickr Installer" ]
    then hdiutil attach "tmp/wickr.dmg"
    fi
    ditto --rsrc "/Volumes/Wickr Installer/Wickr.app" "/Applications/Wickr.app"
    hdiutil detach "/Volumes/Wickr Installer"
fi

# The rest come from the Mac App Store.
if [ ! -d "/Applications/1Password.app" -o ! -d "/Applications/Caffeine.app" -o ! -d "/Applications/Slack.app" -o ! -d "/Applications/Textual.app" ]
then
    set +x
    echo >&2
    read -p"$(tput "bold")Install 1Password, Caffeine, Slack, and Textual from the Mac App Store; press <ENTER> to continue.$(tput "sgr0") "
    echo >&2
    set -x
    open -W "/Applications/App Store.app"
fi

# Launch Caffeine.
open "/Applications/Caffeine.app"

# Export a PATH that includes PlistBuddy.
export PATH="$PATH:/usr/libexec"

# Configure Terminal.app with Solarized colors, 161 columns, and so on.
cat >"tmp/rcrowley.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
<key>rcrowley</key>
<dict>
    <key>ANSIBlackColor</key>
    <data>
    YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFy
    Y2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OVU5TUkdC
    XE5TQ29sb3JTcGFjZVYkY2xhc3NPECgwLjAyNzQ1MDk4MDM5IDAu
    MjExNzY0NzA1OSAwLjI1ODgyMzUyOTQAEAGAAtIQERITWiRjbGFz
    c25hbWVYJGNsYXNzZXNXTlNDb2xvcqISFFhOU09iamVjdF8QD05T
    S2V5ZWRBcmNoaXZlctEXGFRyb290gAEIERojLTI3O0FITltijY+R
    lqGqsrW+0NPYAAAAAAAAAQEAAAAAAAAAGQAAAAAAAAAAAAAAAAAA
    ANo=
    </data>
    <key>ANSIBlueColor</key>
    <data>
    YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFy
    Y2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OVU5TUkdC
    XE5TQ29sb3JTcGFjZVYkY2xhc3NPECcwLjE0OTAxOTYwNzggMC41
    NDUwOTgwMzkyIDAuODIzNTI5NDExOAAQAoAC0hAREhNaJGNsYXNz
    bmFtZVgkY2xhc3Nlc1dOU0NvbG9yohIUWE5TT2JqZWN0XxAPTlNL
    ZXllZEFyY2hpdmVy0RcYVHJvb3SAAQgRGiMtMjc7QUhOW2KMjpCV
    oKmxtL3P0tcAAAAAAAABAQAAAAAAAAAZAAAAAAAAAAAAAAAAAAAA
    2Q==
    </data>
    <key>ANSIBrightBlackColor</key>
    <data>
    YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFy
    Y2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OVU5TUkdC
    XE5TQ29sb3JTcGFjZVYkY2xhc3NPEBswIDAuMTY4NjI3NDUxIDAu
    MjExNzY0NzA1OQAQAoAC0hAREhNaJGNsYXNzbmFtZVgkY2xhc3Nl
    c1dOU0NvbG9yohIUWE5TT2JqZWN0XxAPTlNLZXllZEFyY2hpdmVy
    0RcYVHJvb3SAAQgRGiMtMjc7QUhOW2KAgoSJlJ2lqLHDxssAAAAA
    AAABAQAAAAAAAAAZAAAAAAAAAAAAAAAAAAAAzQ==
    </data>
    <key>ANSIBrightBlueColor</key>
    <data>
    YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFy
    Y2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OVU5TUkdC
    XE5TQ29sb3JTcGFjZVYkY2xhc3NPECcwLjUxMzcyNTQ5MDIgMC41
    ODAzOTIxNTY5IDAuNTg4MjM1Mjk0MQAQAoAC0hAREhNaJGNsYXNz
    bmFtZVgkY2xhc3Nlc1dOU0NvbG9yohIUWE5TT2JqZWN0XxAPTlNL
    ZXllZEFyY2hpdmVy0RcYVHJvb3SAAQgRGiMtMjc7QUhOW2KMjpCV
    oKmxtL3P0tcAAAAAAAABAQAAAAAAAAAZAAAAAAAAAAAAAAAAAAAA
    2Q==
    </data>
    <key>ANSIBrightCyanColor</key>
    <data>
    YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFy
    Y2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OVU5TUkdC
    XE5TQ29sb3JTcGFjZVYkY2xhc3NPECUwLjU3NjQ3MDU4ODIgMC42
    MzEzNzI1NDkgMC42MzEzNzI1NDkAEAKAAtIQERITWiRjbGFzc25h
    bWVYJGNsYXNzZXNXTlNDb2xvcqISFFhOU09iamVjdF8QD05TS2V5
    ZWRBcmNoaXZlctEXGFRyb290gAEIERojLTI3O0FITltiioyOk56n
    r7K7zdDVAAAAAAAAAQEAAAAAAAAAGQAAAAAAAAAAAAAAAAAAANc=
    </data>
    <key>ANSIBrightGreenColor</key>
    <data>
    YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFy
    Y2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OVU5TUkdC
    XE5TQ29sb3JTcGFjZVYkY2xhc3NPECYwLjM0NTA5ODAzOTIgMC40
    MzEzNzI1NDkgMC40NTg4MjM1Mjk0ABACgALSEBESE1okY2xhc3Nu
    YW1lWCRjbGFzc2VzV05TQ29sb3KiEhRYTlNPYmplY3RfEA9OU0tl
    eWVkQXJjaGl2ZXLRFxhUcm9vdIABCBEaIy0yNztBSE5bYouNj5Sf
    qLCzvM7R1gAAAAAAAAEBAAAAAAAAABkAAAAAAAAAAAAAAAAAAADY
    </data>
    <key>ANSIBrightMagentaColor</key>
    <data>
    YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFy
    Y2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OVU5TUkdC
    XE5TQ29sb3JTcGFjZVYkY2xhc3NPECYwLjQyMzUyOTQxMTggMC40
    NDMxMzcyNTQ5IDAuNzY4NjI3NDUxABACgALSEBESE1okY2xhc3Nu
    YW1lWCRjbGFzc2VzV05TQ29sb3KiEhRYTlNPYmplY3RfEA9OU0tl
    eWVkQXJjaGl2ZXLRFxhUcm9vdIABCBEaIy0yNztBSE5bYouNj5Sf
    qLCzvM7R1gAAAAAAAAEBAAAAAAAAABkAAAAAAAAAAAAAAAAAAADY
    </data>
    <key>ANSIBrightRedColor</key>
    <data>
    YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFy
    Y2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OVU5TUkdC
    XE5TQ29sb3JTcGFjZVYkY2xhc3NPECcwLjc5NjA3ODQzMTQgMC4y
    OTQxMTc2NDcxIDAuMDg2Mjc0NTA5OAAQAoAC0hAREhNaJGNsYXNz
    bmFtZVgkY2xhc3Nlc1dOU0NvbG9yohIUWE5TT2JqZWN0XxAPTlNL
    ZXllZEFyY2hpdmVy0RcYVHJvb3SAAQgRGiMtMjc7QUhOW2KMjpCV
    oKmxtL3P0tcAAAAAAAABAQAAAAAAAAAZAAAAAAAAAAAAAAAAAAAA
    2Q==
    </data>
    <key>ANSIBrightWhiteColor</key>
    <data>
    YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFy
    Y2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OVU5TUkdC
    XE5TQ29sb3JTcGFjZVYkY2xhc3NPECcwLjk5MjE1Njg2MjcgMC45
    NjQ3MDU4ODI0IDAuODkwMTk2MDc4NAAQAoAC0hAREhNaJGNsYXNz
    bmFtZVgkY2xhc3Nlc1dOU0NvbG9yohIUWE5TT2JqZWN0XxAPTlNL
    ZXllZEFyY2hpdmVy0RcYVHJvb3SAAQgRGiMtMjc7QUhOW2KMjpCV
    oKmxtL3P0tcAAAAAAAABAQAAAAAAAAAZAAAAAAAAAAAAAAAAAAAA
    2Q==
    </data>
    <key>ANSIBrightYellowColor</key>
    <data>
    YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFy
    Y2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OVU5TUkdC
    XE5TQ29sb3JTcGFjZVYkY2xhc3NPECcwLjM5NjA3ODQzMTQgMC40
    ODIzNTI5NDEyIDAuNTEzNzI1NDkwMgAQAoAC0hAREhNaJGNsYXNz
    bmFtZVgkY2xhc3Nlc1dOU0NvbG9yohIUWE5TT2JqZWN0XxAPTlNL
    ZXllZEFyY2hpdmVy0RcYVHJvb3SAAQgRGiMtMjc7QUhOW2KMjpCV
    oKmxtL3P0tcAAAAAAAABAQAAAAAAAAAZAAAAAAAAAAAAAAAAAAAA
    2Q==
    </data>
    <key>ANSICyanColor</key>
    <data>
    YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFy
    Y2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OVU5TUkdC
    XE5TQ29sb3JTcGFjZVYkY2xhc3NPECYwLjE2NDcwNTg4MjQgMC42
    MzEzNzI1NDkgMC41OTYwNzg0MzE0ABACgALSEBESE1okY2xhc3Nu
    YW1lWCRjbGFzc2VzV05TQ29sb3KiEhRYTlNPYmplY3RfEA9OU0tl
    eWVkQXJjaGl2ZXLRFxhUcm9vdIABCBEaIy0yNztBSE5bYouNj5Sf
    qLCzvM7R1gAAAAAAAAEBAAAAAAAAABkAAAAAAAAAAAAAAAAAAADY
    </data>
    <key>ANSIGreenColor</key>
    <data>
    YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFy
    Y2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OVU5TUkdC
    XE5TQ29sb3JTcGFjZVYkY2xhc3NPEBMwLjUyMTU2ODYyNzUgMC42
    IDAAEAKAAtIQERITWiRjbGFzc25hbWVYJGNsYXNzZXNXTlNDb2xv
    cqISFFhOU09iamVjdF8QD05TS2V5ZWRBcmNoaXZlctEXGFRyb290
    gAEIERojLTI3O0FITltieHp8gYyVnaCpu77DAAAAAAAAAQEAAAAA
    AAAAGQAAAAAAAAAAAAAAAAAAAMU=
    </data>
    <key>ANSIMagentaColor</key>
    <data>
    YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFy
    Y2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OVU5TUkdC
    XE5TQ29sb3JTcGFjZVYkY2xhc3NPECcwLjgyNzQ1MDk4MDQgMC4y
    MTE3NjQ3MDU5IDAuNTA5ODAzOTIxNgAQAoAC0hAREhNaJGNsYXNz
    bmFtZVgkY2xhc3Nlc1dOU0NvbG9yohIUWE5TT2JqZWN0XxAPTlNL
    ZXllZEFyY2hpdmVy0RcYVHJvb3SAAQgRGiMtMjc7QUhOW2KMjpCV
    oKmxtL3P0tcAAAAAAAABAQAAAAAAAAAZAAAAAAAAAAAAAAAAAAAA
    2Q==
    </data>
    <key>ANSIRedColor</key>
    <data>
    YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFy
    Y2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OVU5TUkdC
    XE5TQ29sb3JTcGFjZVYkY2xhc3NPECswLjgyNzQ1MDk4MDQgMC4w
    MDM5MjE1Njg2MjcgMC4wMDc4NDMxMzcyNTUAEAKAAtIQERITWiRj
    bGFzc25hbWVYJGNsYXNzZXNXTlNDb2xvcqISFFhOU09iamVjdF8Q
    D05TS2V5ZWRBcmNoaXZlctEXGFRyb290gAEIERojLTI3O0FITlti
    kJKUmaSttbjB09bbAAAAAAAAAQEAAAAAAAAAGQAAAAAAAAAAAAAA
    AAAAAN0=
    </data>
    <key>ANSIWhiteColor</key>
    <data>
    YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFy
    Y2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OVU5TUkdC
    XE5TQ29sb3JTcGFjZVYkY2xhc3NPECcwLjkzMzMzMzMzMzMgMC45
    MDk4MDM5MjE2IDAuODM1Mjk0MTE3NgAQAoAC0hAREhNaJGNsYXNz
    bmFtZVgkY2xhc3Nlc1dOU0NvbG9yohIUWE5TT2JqZWN0XxAPTlNL
    ZXllZEFyY2hpdmVy0RcYVHJvb3SAAQgRGiMtMjc7QUhOW2KMjpCV
    oKmxtL3P0tcAAAAAAAABAQAAAAAAAAAZAAAAAAAAAAAAAAAAAAAA
    2Q==
    </data>
    <key>ANSIYellowColor</key>
    <data>
    YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFy
    Y2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OVU5TUkdC
    XE5TQ29sb3JTcGFjZVYkY2xhc3NPEBswLjcwOTgwMzkyMTYgMC41
    MzcyNTQ5MDIgMAAQAoAC0hAREhNaJGNsYXNzbmFtZVgkY2xhc3Nl
    c1dOU0NvbG9yohIUWE5TT2JqZWN0XxAPTlNLZXllZEFyY2hpdmVy
    0RcYVHJvb3SAAQgRGiMtMjc7QUhOW2KAgoSJlJ2lqLHDxssAAAAA
    AAABAQAAAAAAAAAZAAAAAAAAAAAAAAAAAAAAzQ==
    </data>
    <key>BackgroundBlur</key>
    <string>0</string>
    <key>BackgroundColor</key>
    <data>
    YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFy
    Y2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OVU5TUkdC
    XE5TQ29sb3JTcGFjZVYkY2xhc3NPEBswIDAuMTY4NjI3NDUxIDAu
    MjExNzY0NzA1OQAQAoAC0hAREhNaJGNsYXNzbmFtZVgkY2xhc3Nl
    c1dOU0NvbG9yohIUWE5TT2JqZWN0XxAPTlNLZXllZEFyY2hpdmVy
    0RcYVHJvb3SAAQgRGiMtMjc7QUhOW2KAgoSJlJ2lqLHDxssAAAAA
    AAABAQAAAAAAAAAZAAAAAAAAAAAAAAAAAAAAzQ==
    </data>
    <key>CursorColor</key>
    <data>
    YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFy
    Y2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OVU5TUkdC
    XE5TQ29sb3JTcGFjZVYkY2xhc3NPECcwLjk5MjE1Njg2MjcgMC45
    NjQ3MDU4ODI0IDAuODkwMTk2MDc4NAAQAoAC0hAREhNaJGNsYXNz
    bmFtZVgkY2xhc3Nlc1dOU0NvbG9yohIUWE5TT2JqZWN0XxAPTlNL
    ZXllZEFyY2hpdmVy0RcYVHJvb3SAAQgRGiMtMjc7QUhOW2KMjpCV
    oKmxtL3P0tcAAAAAAAABAQAAAAAAAAAZAAAAAAAAAAAAAAAAAAAA
    2Q==
    </data>
    <key>Font</key>
    <data>
    YnBsaXN0MDDUAQIDBAUGGBlYJHZlcnNpb25YJG9iamVjdHNZJGFy
    Y2hpdmVyVCR0b3ASAAGGoKQHCBESVSRudWxs1AkKCwwNDg8QVk5T
    U2l6ZVhOU2ZGbGFnc1ZOU05hbWVWJGNsYXNzI0AoAAAAAAAAEBCA
    AoADVk1vbmFjb9ITFBUWWiRjbGFzc25hbWVYJGNsYXNzZXNWTlNG
    b250ohUXWE5TT2JqZWN0XxAPTlNLZXllZEFyY2hpdmVy0RobVHJv
    b3SAAQgRGiMtMjc8QktSW2JpcnR2eH+Ej5ifoqu9wMUAAAAAAAAB
    AQAAAAAAAAAcAAAAAAAAAAAAAAAAAAAAxw==
    </data>
    <key>FontAntialias</key>
    <string>1</string>
    <key>FontWidthSpacing</key>
    <string>1</string>
    <key>Linewrap</key>
    <true/>
    <key>ProfileCurrentVersion</key>
    <string>2.02</string>
    <key>SelectionColor</key>
    <data>
    YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFy
    Y2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OVU5TUkdC
    XE5TQ29sb3JTcGFjZVYkY2xhc3NPECgwLjAyNzQ1MDk4MDM5IDAu
    MjExNzY0NzA1OSAwLjI1ODgyMzUyOTQAEAGAAtIQERITWiRjbGFz
    c25hbWVYJGNsYXNzZXNXTlNDb2xvcqISFFhOU09iamVjdF8QD05T
    S2V5ZWRBcmNoaXZlctEXGFRyb290gAEIERojLTI3O0FITltijY+R
    lqGqsrW+0NPYAAAAAAAAAQEAAAAAAAAAGQAAAAAAAAAAAAAAAAAA
    ANo=
    </data>
    <key>TextBoldColor</key>
    <data>
    YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFy
    Y2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OVU5TUkdC
    XE5TQ29sb3JTcGFjZVYkY2xhc3NPECcwLjk5MjE1Njg2MjcgMC45
    NjQ3MDU4ODI0IDAuODkwMTk2MDc4NAAQAoAC0hAREhNaJGNsYXNz
    bmFtZVgkY2xhc3Nlc1dOU0NvbG9yohIUWE5TT2JqZWN0XxAPTlNL
    ZXllZEFyY2hpdmVy0RcYVHJvb3SAAQgRGiMtMjc7QUhOW2KMjpCV
    oKmxtL3P0tcAAAAAAAABAQAAAAAAAAAZAAAAAAAAAAAAAAAAAAAA
    2Q==
    </data>
    <key>TextColor</key>
    <data>
    YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFy
    Y2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OVU5TUkdC
    XE5TQ29sb3JTcGFjZVYkY2xhc3NPECcwLjkzMzMzMzMzMzMgMC45
    MDk4MDM5MjE2IDAuODM1Mjk0MTE3NgAQAoAC0hAREhNaJGNsYXNz
    bmFtZVgkY2xhc3Nlc1dOU0NvbG9yohIUWE5TT2JqZWN0XxAPTlNL
    ZXllZEFyY2hpdmVy0RcYVHJvb3SAAQgRGiMtMjc7QUhOW2KMjpCV
    oKmxtL3P0tcAAAAAAAABAQAAAAAAAAAZAAAAAAAAAAAAAAAAAAAA
    2Q==
    </data>
    <key>columnCount</key>
    <integer>161</integer>
    <key>name</key>
    <string>rcrowley</string>
    <key>rowCount</key>
    <integer>42</integer>
    <key>type</key>
    <string>Window Settings</string>
    <key>useOptionAsMetaKey</key>
    <true/>
</dict>
</dict>
</plist>
EOF
PlistBuddy -c "Merge tmp/rcrowley.plist :Window\ Settings" "$HOME/Library/Preferences/com.apple.Terminal.plist"
killall "cfprefsd"
defaults write "com.apple.Terminal" "Default Window Settings" "rcrowley"
defaults write "com.apple.Terminal" "Startup Window Settings" "rcrowley"

# Trackpad:  Don't tap to click.  Don't two-finger tap to right-click.
# FIXME How do I make the OS pay attention to these settings immediately?
defaults write "com.apple.AppleMultitouchTrackpad" "Clicking" -integer "0"
defaults write "com.apple.AppleMultitouchTrackpad" "TrackpadRightClick" -integer "0"
defaults write "com.apple.driver.AppleBluetoothMultitouch.trackpad" "Clicking" -integer "0"
defaults write "com.apple.driver.AppleBluetoothMultitouch.trackpad" "TrackpadRightClick" -integer "0"

# Finder:  Show all file extensions.  Show ~ in the sidebar.  Show
# ~/Library in Finder windows.
# FIXME How do I make the OS pay attention to these settings immediately?
defaults write ".GlobalPreferences" "AppleShowAllExtensions" -integer "1"
: <<EOFEOF
defaults write "com.apple.sidebarlists" "favoriteitems" '
    {
        Controller = CustomListItems;
        CustomListItems =     (
                    {
                Alias = <00000000 011a0003 00010000 cf28a298 0000482b 00000000 00022817 00022818 0000cefe 5c850000 00000920 fffe0000 00000000 0000ffff ffff0001 001c0002 28170002 26cc0002 26c70002 26c60000 002f0000 002c0000 002b000e 00320018 006d0079 0044006f 00630075 006d0065 006e0074 0073002e 00630061 006e006e 00650064 00530065 00610072 00630068 000f001a 000c004d 00610063 0069006e 0074006f 00730068 00200048 00440012 005e5379 7374656d 2f4c6962 72617279 2f436f72 65536572 76696365 732f4669 6e646572 2e617070 2f436f6e 74656e74 732f5265 736f7572 6365732f 4d794c69 62726172 6965732f 6d79446f 63756d65 6e74732e 63616e6e 65645365 61726368 00130001 2f00ffff 0000>;
                CustomItemProperties =             {
                    "com.apple.LSSharedFileList.Binding" = <646e6962 00000000 02000000 00000000 00000000 00000000 00000000 67000000 00000000 66696c65 3a2f2f2f 53797374 656d2f4c 69627261 72792f43 6f726553 65727669 6365732f 46696e64 65722e61 70702f43 6f6e7465 6e74732f 5265736f 75726365 732f4d79 4c696272 61726965 732f6d79 446f6375 6d656e74 732e6361 6e6e6564 53656172 63682f00 00000000 00000000 00000000 00000000 00000000 00000000 000000>;
                    "com.apple.LSSharedFileList.TemplateSystemSelector" = 1935819078;
                };
                Name = "All My Files";
            },
                    {
                CustomItemProperties =             {
                    "com.apple.LSSharedFileList.SpecialItemIdentifier" = "com.apple.LSSharedFileList.IsMeetingRoom";
                };
                Name = "domain-AirDrop";
                URL = "nwnode://domain-AirDrop";
            },
                    {
                Alias = <00000000 00940003 00010000 cf28a298 0000482b 00000000 00000002 00000051 0000cdc1 84210000 00000920 fffe0000 00000000 0000ffff ffff0001 0000000e 001a000c 00410070 0070006c 00690063 00610074 0069006f 006e0073 000f001a 000c004d 00610063 0069006e 0074006f 00730068 00200048 00440012 000c4170 706c6963 6174696f 6e730013 00012f00 ffff0000>;
                CustomItemProperties =             {
                    "com.apple.LSSharedFileList.Binding" = <646e6962 00000000 01000000 00000000 00000000 00000000 00000000 00000000 00000000 73707061 02000000 00000000>;
                    "com.apple.LSSharedFileList.TemplateSystemSelector" = 1935819120;
                };
                Name = Applications;
            },
                    {
                Alias = <00000000 00a20003 00010000 cf28a298 0000482b 00000000 0008fd85 0008fe02 0000cf28 a3a20000 00000920 fffe0000 00000000 0000ffff ffff0001 00080008 fd850002 65d9000e 00100007 00440065 0073006b 0074006f 0070000f 001a000c 004d0061 00630069 006e0074 006f0073 00680020 00480044 00120016 55736572 732f7263 726f776c 65792f44 65736b74 6f700013 00012f00 00150002 000fffff 0000>;
                CustomItemProperties =             {
                    "com.apple.LSSharedFileList.Binding" = <646e6962 00000000 01000000 00000000 00000000 00000000 00000000 00000000 00000000 6b736564 02000000 00000000>;
                    "com.apple.LSSharedFileList.TemplateSystemSelector" = 1935819892;
                };
                Name = Desktop;
            },
                    {
                Alias = <00000000 00a80003 00010000 cf28a298 0000482b 00000000 0008fd85 0008fd86 0000cf28 a3a20000 00000920 fffe0000 00000000 0000ffff ffff0001 00080008 fd850002 65d9000e 00140009 0044006f 00630075 006d0065 006e0074 0073000f 001a000c 004d0061 00630069 006e0074 006f0073 00680020 00480044 00120018 55736572 732f7263 726f776c 65792f44 6f63756d 656e7473 00130001 2f000015 0002000f ffff0000>;
                CustomItemProperties =             {
                    "com.apple.LSSharedFileList.Binding" = <646e6962 00000000 01000000 00000000 00000000 00000000 00000000 00000000 00000000 73636f64 02000000 00000000>;
                    "com.apple.LSSharedFileList.TemplateSystemSelector" = 1935819875;
                };
                Name = Documents;
            },
                    {
                Alias = <00000000 00a80003 00010000 cf28a298 0000482b 00000000 0008fd85 0008fd88 0000cf28 a3a20000 00000920 fffe0000 00000000 0000ffff ffff0001 00080008 fd850002 65d9000e 00140009 0044006f 0077006e 006c006f 00610064 0073000f 001a000c 004d0061 00630069 006e0074 006f0073 00680020 00480044 00120018 55736572 732f7263 726f776c 65792f44 6f776e6c 6f616473 00130001 2f000015 0002000f ffff0000>;
                CustomItemProperties =             {
                    "com.apple.LSSharedFileList.Binding" = <646e6962 00000000 01000000 00000000 00000000 00000000 00000000 00000000 00000000 666e7764 02000000 00000000>;
                    "com.apple.LSSharedFileList.TemplateSystemSelector" = 1935819884;
                };
                Name = Downloads;
            },
                    {
                Alias = <00000000 00980003 00010000 cf28a298 0000482b 00000000 000265d9 0008fd85 0000cf7b 58e60000 00000920 fffe0000 00000000 0000ffff ffff0001 00040002 65d9000e 00120008 00720063 0072006f 0077006c 00650079 000f001a 000c004d 00610063 0069006e 0074006f 00730068 00200048 00440012 000e5573 6572732f 7263726f 776c6579 00130001 2f000015 0002000f ffff0000>;
                CustomItemProperties =             {
                    "com.apple.LSSharedFileList.Binding" = <646e6962 00000000 01000000 00000000 00000000 00000000 00000000 00000000 00000000 646c6675 02000000 00000000>;
                    "com.apple.LSSharedFileList.TemplateSystemSelector" = 1935820909;
                };
                Name = rcrowley;
            }
        );
        CustomListProperties =     {
            "com.apple.LSSharedFileList.Restricted.upgraded" = 9027;
        };
    }
'
EOFEOF
chflags "nohidden" "$HOME/Library"

# Don't show the clock in the menu bar.
defaults write "com.apple.systemuiserver" "menuExtras" "$(defaults read "com.apple.systemuiserver" "menuExtras" | grep -v "Clock.menu")"

# Dock:  Chrome, Terminal, Slack, Messages, Skype, Papers, Downloads.
defaults write "com.apple.Dock" "persistent-apps" '
    (
            {
            GUID = 160385472;
            "tile-data" =         {
                "bundle-identifier" = "com.google.Chrome";
                "dock-extra" = 0;
                "file-data" =             {
                    "_CFURLAliasData" = <00000000 00b40003 00010000 cf28a298 0000482b 00000000 00000051 0009a5ee 0000cf61 04310000 00000920 fffe0000 00000000 0000ffff ffff0001 00040000 0051000e 00240011 0047006f 006f0067 006c0065 00200043 00680072 006f006d 0065002e 00610070 0070000f 001a000c 004d0061 00630069 006e0074 006f0073 00680020 00480044 0012001e 4170706c 69636174 696f6e73 2f476f6f 676c6520 4368726f 6d652e61 70700013 00012f00 ffff0000>;
                    "_CFURLString" = "file:///Applications/Google%20Chrome.app/";
                    "_CFURLStringType" = 15;
                };
                "file-label" = "Google Chrome";
                "file-mod-date" = 3488253291;
                "file-type" = 41;
                "parent-mod-date" = 3489781405;
            };
            "tile-type" = "file-tile";
        },
            {
            GUID = 160385473;
            "tile-data" =         {
                "bundle-identifier" = "com.apple.Terminal";
                "dock-extra" = 0;
                "file-data" =             {
                    "_CFURLAliasData" = <00000000 00b40003 00010000 cf28a298 0000482b 00000000 00000052 0000289e 0000ce3f 41d50000 00000920 fffe0000 00000000 0000ffff ffff0001 00080000 00520000 0051000e 001a000c 00540065 0072006d 0069006e 0061006c 002e0061 00700070 000f001a 000c004d 00610063 0069006e 0074006f 00730068 00200048 00440012 00234170 706c6963 6174696f 6e732f55 74696c69 74696573 2f546572 6d696e61 6c2e6170 70000013 00012f00 ffff0000>;
                    "_CFURLString" = "file:///Applications/Utilities/Terminal.app/";
                    "_CFURLStringType" = 15;
                };
                "file-label" = Terminal;
                "file-mod-date" = 3460252117;
                "file-type" = 41;
                "parent-mod-date" = 3475548489;
            };
            "tile-type" = "file-tile";
        },
            {
            GUID = 160385474;
            "tile-data" =         {
                "bundle-identifier" = "com.tinyspeck.slackmacgap";
                "dock-extra" = 0;
                "file-data" =             {
                    "_CFURLAliasData" = <00000000 009c0003 00010000 cf28a298 0000482b 00000000 00000051 0018c41b 0000cf85 c0450000 00000920 fffe0000 00000000 0000ffff ffff0001 00040000 0051000e 00140009 0053006c 00610063 006b002e 00610070 0070000f 001a000c 004d0061 00630069 006e0074 006f0073 00680020 00480044 00120016 4170706c 69636174 696f6e73 2f536c61 636b2e61 70700013 00012f00 ffff0000>;
                    "_CFURLString" = "file:///Applications/Slack.app/";
                    "_CFURLStringType" = 15;
                };
                "file-label" = Slack;
                "file-mod-date" = 3483360537;
                "file-type" = 41;
                "parent-mod-date" = 3489781405;
            };
            "tile-type" = "file-tile";
        },
            {
            GUID = 607466720;
            "tile-data" =         {
                "bundle-identifier" = "com.codeux.irc.textual";
                "dock-extra" = 0;
                "file-data" =             {
                    "_CFURLAliasData" = <00000000 00a20003 00010000 cf28a298 0000482b 00000000 00000051 004e53f3 0000cfe6 ece60000 00000920 fffe0000 00000000 0000ffff ffff0001 00040000 0051000e 0018000b 00540065 00780074 00750061 006c002e 00610070 0070000f 001a000c 004d0061 00630069 006e0074 006f0073 00680020 00480044 00120018 4170706c 69636174 696f6e73 2f546578 7475616c 2e617070 00130001 2f00ffff 0000>;
                    "_CFURLString" = "file:///Applications/Textual.app/";
                    "_CFURLStringType" = 15;
                };
                "file-label" = Textual;
                "file-mod-date" = 3488660195;
                "file-type" = 41;
                "parent-mod-date" = 3489781405;
            };
            "tile-type" = "file-tile";
        },
            {
            GUID = 160385475;
            "tile-data" =         {
                "bundle-identifier" = "com.apple.iChat";
                "dock-extra" = 1;
                "file-data" =             {
                    "_CFURLAliasData" = <00000000 00a60003 00010000 cf28a298 0000482b 00000000 00000051 0002f055 0000cbcd ed3f0000 00000920 fffe0000 00000000 0000ffff ffff0001 00040000 0051000e 001a000c 004d0065 00730073 00610067 00650073 002e0061 00700070 000f001a 000c004d 00610063 0069006e 0074006f 00730068 00200048 00440012 00194170 706c6963 6174696f 6e732f4d 65737361 6765732e 61707000 00130001 2f00ffff 0000>;
                    "_CFURLString" = "file:///Applications/Messages.app/";
                    "_CFURLStringType" = 15;
                };
                "file-label" = Messages;
                "file-mod-date" = 3419270463;
                "file-type" = 41;
                "parent-mod-date" = 3489781405;
            };
            "tile-type" = "file-tile";
        },
            {
            GUID = 4035391174;
            "tile-data" =         {
                "bundle-identifier" = "com.skype.skype";
                "dock-extra" = 0;
                "file-data" =             {
                    "_CFURLAliasData" = <00000000 009c0003 00010000 cf28a298 0000482b 00000000 00000051 0053f60e 0000cfd8 8e8f0000 00000920 fffe0000 00000000 0000ffff ffff0001 00040000 0051000e 00140009 0053006b 00790070 0065002e 00610070 0070000f 001a000c 004d0061 00630069 006e0074 006f0073 00680020 00480044 00120016 4170706c 69636174 696f6e73 2f536b79 70652e61 70700013 00012f00 ffff0000>;
                    "_CFURLString" = "file:///Applications/Skype.app/";
                    "_CFURLStringType" = 15;
                };
                "file-label" = Skype;
                "file-mod-date" = 3487075983;
                "file-type" = 41;
                "parent-mod-date" = 3489781405;
            };
            "tile-type" = "file-tile";
        },
            {
            GUID = 1004879293;
            "tile-data" =         {
                "bundle-identifier" = "com.mekentosj.papers3";
                "dock-extra" = 0;
                "file-data" =             {
                    "_CFURLAliasData" = <00000000 00a00003 00010000 cf28a298 0000482b 00000000 00000051 0054ffe8 0000cf05 4f610000 00000920 fffe0000 00000000 0000ffff ffff0001 00040000 0051000e 0016000a 00500061 00700065 00720073 002e0061 00700070 000f001a 000c004d 00610063 0069006e 0074006f 00730068 00200048 00440012 00174170 706c6963 6174696f 6e732f50 61706572 732e6170 70000013 00012f00 ffff0000>;
                    "_CFURLString" = "file:///Applications/Papers.app/";
                    "_CFURLStringType" = 15;
                };
                "file-label" = Papers;
                "file-mod-date" = 3473231713;
                "file-type" = 41;
                "parent-mod-date" = 3489781405;
            };
            "tile-type" = "file-tile";
        }
    )
'

defaults write "com.apple.Dock" "persistent-others" '
    (
            {
            GUID = 160385476;
            "tile-data" =         {
                arrangement = 1;
                displayas = 0;
                "file-data" =             {
                    "_CFURLAliasData" = <00000000 00a80003 00010000 cf28a298 0000482b 00000000 0008fd85 0008fd88 0000cf28 a3a20000 00000920 fffe0000 00000000 0000ffff ffff0001 00080008 fd850002 65d9000e 00140009 0044006f 0077006e 006c006f 00610064 0073000f 001a000c 004d0061 00630069 006e0074 006f0073 00680020 00480044 00120018 55736572 732f7263 726f776c 65792f44 6f776e6c 6f616473 00130001 2f000015 0002000f ffff0000>;
                    "_CFURLString" = "file:///Users/rcrowley/Downloads/";
                    "_CFURLStringType" = 15;
                };
                "file-label" = Downloads;
                "file-mod-date" = 3481548132;
                "file-type" = 2;
                "parent-mod-date" = 3481551879;
                preferreditemsize = "-1";
                showas = 0;
            };
            "tile-type" = "directory-tile";
        }
    )
'
defaults write "com.apple.Dock" "tilesize" -integer "29"

# Ask for password immediately after the screen saver begins.
defaults write "com.apple.screensaver" "askForPassword" -integer "1"
defaults write "com.apple.screensaver" "askForPasswordDelay" -integer "0"

# Bottom right hot corner starts the screensaver.
#defaults write "com.apple.dock" "wvous-br-corner" -integer "5"
#defaults write "com.apple.dock" "wvous-br-modifier" -integer "0"

# TODO Configure Messages.app to login to AIM and Google Talk.

# Refresh the dock, Finder, and menu bar.
killall "Dock" "Finder" "SystemUIServer"

EDITOR="tee" crontab -e <<'EOF'
MAILTO=""

# TODO.txt metrics.
* * * * * COUNT="$(grep -c "." "$HOME/TODO.txt")" DATE="$(date +"\%Y-\%m-\%d")"; grep -F -q "$DATE" "$HOME/TODO.csv" && sed -i "" "s/^$DATE,[0-9]*\$/$DATE,$COUNT/" "$HOME/TODO.csv" || echo "$DATE,$COUNT" >>"$HOME/TODO.csv"

# Remove identities from the SSH agent after 10 minutes of inactivity.
* * * * * /usr/local/bin/empty-unused-ssh-agent
EOF

)
# End rcrowley Mac bootstrapping.
###############################################################################
# Begin universal Linux bootstrapping.
(

if [ "$(uname)" != "Linux" ]
then exit
fi

# Blacklist the overlayfs kernel module per CVE-2015-1328.
sudo tee "/etc/modprobe.d/blacklist-overlayfs.conf" <<EOF
blacklist overlay
blacklist overlayfs
EOF

# Add our Debian archive to APT.
sudo tee "/etc/apt/sources.list.d/rcrowley.list" <<EOF
deb http://packages.rcrowley.org $(lsb_release -sc) main
#deb-src http://packages.rcrowley.org $(lsb_release -sc) main
EOF
curl -s "http://packages.rcrowley.org/keyring.gpg" | sudo tee "/etc/apt/trusted.gpg.d/rcrowley.gpg" >"/dev/null"
export APT_LISTBUGS_FRONTEND="none" APT_LISTCHANGES_FRONTEND="none" DEBIAN_FRONTEND="noninteractive"
sudo apt-get update

# Various dependencies and nice-to-haves.
sudo apt-get -y install "build-essential" "freight" "git" "gnupg-agent" "go" "graphviz" "mercurial" "php5-cli" "pinentry-curses" "python-django" "ruby" "ruby-dev" "tmux" "vim"
sudo apt-get -y remove "pinentry-gtk2"
which "fpm" || sudo gem install --no-rdoc --no-ri "fpm"

# Upgrade all installed software aggressively.
sudo apt-get -y upgrade

)
# End universal Linux bootstrapping.
###############################################################################
# Begin rcrowley bootstrapping.
(

# Clone or pull the home directory.
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

# Start a GPG agent.
. ".profile.d/gpg.sh"

# Install goimports everywhere.
. ".profile.d/go.sh"
go get "code.google.com/p/go.tools/cmd/goimports"

# Copy GPG key pairs from rcrowley.org.
ssh "rcrowley.org" gpg --armor --export "packages@rcrowley.org" | gpg --import
ssh "rcrowley.org" gpg --armor --export-secret-keys "packages@rcrowley.org" | gpg --import || :
ssh "rcrowley.org" gpg --armor --export "r@rcrowley.org" | gpg --import
ssh "rcrowley.org" gpg --armor --export-secret-keys "r@rcrowley.org" | gpg --import || :

# Make ready to work on Slack.
sudo mkdir -p "/etc/slack"
sudo touch "/etc/slack/credentials.php"

)
# End rcrowley bootstrapping.
###############################################################################
# Begin rcrowley Linux bootstrapping.
(

if [ "$(uname)" != "Linux" ]
then exit
fi

# Copy authorized SSH public keys from rcrowley.org.
scp "rcrowley.org":".ssh/authorized_keys" ".ssh"

# Clone www's dependencies, install www, and start it.
mkdir -p "src/github.com/rcrowley"
if [ ! -d "src/github.com/rcrowley/go-metrics" ]
then git clone "git@github.com:rcrowley/go-metrics.git" "src/github.com/rcrowley/go-metrics"
fi
if [ ! -d "src/github.com/rcrowley/go-tigertonic" ]
then git clone "git@github.com:rcrowley/go-tigertonic.git" "src/github.com/rcrowley/go-tigertonic"
fi
. ".profile.d/go.sh"
go install "www"
sudo tee "/etc/init/www.conf" <<EOF
description "www"
start on runlevel [2345]
stop on runlevel [!2345]
respawn
chdir $HOME
env GOMAXPROCS="4"
script
    set -e
    rm -f "/tmp/www.log"
    mkfifo "/tmp/www.log"
    (setsid logger -t"www" <"/tmp/www.log" &)
    exec >"/tmp/www.log" 2>"/tmp/www.log"
    rm "/tmp/www.log"
    exec "$HOME/bin/www"
end script
EOF
sudo start "www" || sudo restart "www"

# Copy files from the old rcrowley.org to the new rcrowley.org.
mkdir -p "src" "var/cache/freight" "var/lib" "var/www"
curl -o"var/cache/freight/keyring.gpg" -s "http://packages.rcrowley.org/keyring.gpg"
curl -o"var/cache/freight/pubkey.gpg" -s "http://packages.rcrowley.org/pubkey.gpg"
rsync -av "rcrowley.org":"git" "."
rsync -av "rcrowley.org":"var/backups" "var"
rsync -Hav "rcrowley.org":"var/lib/freight" "var/lib"
rsync -av "rcrowley.org":"var/www/arch" "var/www" || :
rsync -av "rcrowley.org":"var/www/work" "var/www" || :

# Build the Debian package for Go if it doesn't already exist and cache the
# local Debian archive.
if [ ! -f "var/lib/freight/apt/$(lsb_release -sc)/go_${VERSION}-${BUILD}_amd64.deb" ]
then
    curl -L -O -f "http://golang.org/dl/go$VERSION.linux-amd64.tar.gz"
    trap "rm -rf \"go\" \"go$VERSION.linux-amd64.tar.gz\"" EXIT INT QUIT TERM
    tar xf "go$VERSION.linux-amd64.tar.gz"
    fakeroot fpm -m"Richard Crowley <r@rcrowley.org>" -n"go" -p"var/lib/freight/apt/$(lsb_release -sc)/go_${VERSION}-${BUILD}_amd64.deb" --prefix="/usr" -s"dir" -t"deb" -v"$VERSION-$BUILD" "go"
    rm -rf "go" "go$VERSION.linux-amd64.tar.gz"
    trap "" EXIT INT QUIT TERM
fi
freight cache
sudo apt-get update

# Remove the old rcrowley.org's SSH host key.
grep -v "rcrowley.org" ".ssh/known_hosts" >"known_hosts"
mv "known_hosts" ".ssh"

)
# End rcrowley Linux bootstrapping.
###############################################################################

# Parting advice.
set +x
echo >&2
tput "bold"
if [ "$(uname)" = "Darwin" ]
then
    if [ "$FDESETUP" ]
    then echo "FileVault is now enabled but you need to reboot." >&2
    else echo "Good to go!" >&2
    fi
else echo "Change the rcrowley.org A record to complete the change." >&2
fi
tput "sgr0"
