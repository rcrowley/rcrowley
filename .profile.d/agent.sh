for PATHNAME in $(find "/tmp" -name "agent.*" -user "$USER" 2>"/dev/null")
do
    if SSH_AUTH_SOCK="$PATHNAME" ssh-add -l >"/dev/null"
    then export SSH_AUTH_SOCK="$PATHNAME"
    else rm -f "$PATHNAME" && rmdir "$(dirname "$PATHNAME")" || :
    fi
done
if [ -z "$SSH_AUTH_SOCK" ]
then eval "$(ssh-agent)"
fi

# After an ssh-agent is running, pull the latest home directory from GitHub.
# Don't bother doing this over and over once tmux is running.
if [ -z "$TMUX" -a "$HOME" = "$PWD" ]
then
    git remote update origin
    git pull origin master
fi
