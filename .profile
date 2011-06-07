# ~/.profile: executed by Bourne-compatible login shells.

[ "$BASH" -a -f ~/.bashrc ] && . ~/.bashrc

mesg n

# Find or create an ssh-agent.
which ssh-agent >/dev/null && {
	: ${SSH_AUTH_SOCK:=$(echo /tmp/ssh-*/agent.* | cut -d" " -f1)}
	[ -S "$SSH_AUTH_SOCK" ] && {
		export SSH_AUTH_SOCK
	} || {
		eval $(ssh-agent)
		ssh-add
	}
}

# After an ssh-agent is running, pull the latest home directory from GitHub.
git remote update origin && git pull origin master

for PATHNAME in ~/.profile.d/*.sh
do
	. "$PATHNAME"
done
