export GPG_TTY="$(tty)"

if [ -f "$HOME/.gpg-agent-info" ]
then
    . "$HOME/.gpg-agent-info"
    export GPG_AGENT_INFO
fi
if ! gpg-connect-agent "/bye"
then eval "$(gpg-agent --daemon --disable-scdaemon --write-env-file "$HOME/.gpg-agent-info")"
fi
