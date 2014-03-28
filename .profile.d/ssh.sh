for PATHNAME in "/tmp/ssh-"*"/agent."*
do
    if [ ! -w "$PATHNAME" ]
    then continue
    fi
    if SSH_AUTH_SOCK="$PATHNAME" ssh-add -l >"/dev/null"
    then export SSH_AUTH_SOCK="$PATHNAME"
    else
        rm -f "$PATHNAME"
        rmdir --ignore-fail-on-non-empty "$(dirname "$PATHNAME")"
    fi
done
if [ -z "$SSH_AUTH_SOCK" ]
then eval "$(ssh-agent -t"600")"
fi

# After an ssh-agent is running, pull the latest home directory from GitHub.
# Don't bother doing this over and over once tmux is running.
if [ -z "$TMUX" -a "$HOME" = "$PWD" ]
then
    git remote update origin
    git pull origin master
fi
