[ -f "/etc/bash_completion.d/git" ] && . "/etc/bash_completion.d/git"

PS1="\[\e[1;31m\]█\[\e[0m\] $(
	lsb_release -c 2>/dev/null | cut -f2
)\[\e[1;31m\]-\[\e[0m\]$(
	dpkg --print-architecture 2>/dev/null
) \h$(
	[ -f "/.lxcme" ] && {
		echo -n "\[\e[1;31m\]/\[\e[0m\]"
		cat "/.lxcme"
	}
)\[\e[1;31m\]:\[\e[0m\]\w$(
	[ "\$(type -t __git_ps1)" ] && echo -n "\$(__git_ps1 ' \[\e[1;31m\](\[\e[0m\]%s\[\e[1;31m\])\[\e[0m\]')"
)\n\[\e[1;31m\]█\[\e[0m\] \[\e[1;31m\]$(
	[ "$(whoami)" = "root" ] && echo "#" || echo "\$"
)\[\e[0m\] "
