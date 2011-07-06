# Release and architecture prompt.
PS1="$(
	lsb_release -c 2>/dev/null | cut -f2
)\[\e[1m\]-\[\e[0m\]$(
	dpkg --print-architecture 2>/dev/null
) \h\[\e[1m\]:\[\e[0m\]\w\n\[\e[1m\]$(
	[ "$(whoami)" = "root" ] && echo "#" || echo "\$"
)\[\e[0m\] "

# Git branch in prompt.
[ -f /etc/bash_completion.d/git ] && {
	. /etc/bash_completion.d/git
	[ "\$(type -t __git_ps1)" ] && PS1="\$(__git_ps1 '\[\e[1m\](\[\e[0m\]%s\[\e[1m\])\[\e[0m\] ')$PS1"
}
