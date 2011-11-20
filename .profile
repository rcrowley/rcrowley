# ~/.profile: executed by Bourne-compatible login shells.

[ "$BASH" -a -f ~/.bashrc ] && . ~/.bashrc

mesg n

# Find or create an ssh-agent.
if which ssh-agent >/dev/null
then
	: ${SSH_AUTH_SOCK:=$(echo /tmp/ssh-*/agent.* | cut -d" " -f1)}
	if [ -S "$SSH_AUTH_SOCK" ]
	then
		export SSH_AUTH_SOCK
	else
		eval $(ssh-agent)
		ssh-add
	fi
fi

# After an ssh-agent is running, pull the latest home directory from GitHub.
# Don't bother doing this over and over once tmux is running.
[ -z "$TMUX" ] && git remote update origin && git pull origin master

for PATHNAME in ~/.profile.d/*.sh
do
	. "$PATHNAME"
done
