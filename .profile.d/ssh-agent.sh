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
