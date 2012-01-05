[ -f "/etc/bash_completion.d/git" ] && . "/etc/bash_completion.d/git"

PS1="\[\e[1;31m\]█\[\e[0m\] $(
	lsb_release -sc 2>"/dev/null"
)\[\e[1;31m\]-\[\e[0m\]$(
	dpkg --print-architecture 2>"/dev/null" || rpm --eval "%_arch" 2>"/dev/null"
) \h$(
	[ -f "/.lxcme" ] && {
		echo -n "\[\e[1;31m\]/\[\e[0m\]"
		cat "/.lxcme"
	}
)\[\e[1;31m\]:\[\e[0m\]\w$(
	[ "$(type -t __git_ps1)" ] &&
	echo -n "\$(__git_ps1 ' \[\e[1;31m\](\[\e[0m\]%s\[\e[1;31m\])\[\e[0m\]')" ||
	echo -n "\$(printf ' \[\e[1;31m\](\[\e[0m\]%s\[\e[1;31m\])\[\e[0m\]' \"\$(git branch | grep '^\*' | cut -c'3-')\")"
)\n\[\e[1;31m\]█\[\e[0m\] \[\e[1;31m\]$(
	[ "$(whoami)" = "root" ] && echo "#" || echo "\$"
)\[\e[0m\] "
