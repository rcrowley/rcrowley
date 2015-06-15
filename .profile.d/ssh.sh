for PATHNAME in "/tmp/ssh-"*"/agent."* # "/tmp/launch-"*"/Listeners"
do
    if [ ! -w "$PATHNAME" ]
    then continue
    fi
    if SSH_AUTH_SOCK="$PATHNAME" ssh-add -l >"/dev/null"
    then export SSH_AUTH_SOCK="$PATHNAME"
    else
        rm -f "$PATHNAME"
        rmdir "$(dirname "$PATHNAME")" 2>"/dev/null" || :
    fi
done
if [ -z "$SSH_AUTH_SOCK" ]
then eval "$(ssh-agent -t"600")"
fi
if [ "$SSH_AUTH_SOCK" != "$HOME/.ssh/agent" ]
then ln -fs "$SSH_AUTH_SOCK" "$HOME/.ssh/agent"
fi
export SSH_AUTH_SOCK="$HOME/.ssh/agent"

# After an ssh-agent is running, pull the latest home directory from GitHub.
# Don't bother doing this over and over on the Mac or once tmux is running.
if [ "$(uname)" != "Darwin" ] && [ -z "$TMUX" ] && [ "$HOME" = "$PWD" ] && ssh-add -l >"/dev/null" 2>"/dev/null"
then
    git remote update origin
    git pull origin master
fi
