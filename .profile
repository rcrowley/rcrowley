# ~/.profile: executed by Bourne-compatible login shells.

[ "$BASH" -a -f ~/.bashrc ] && . ~/.bashrc

mesg n

# Release and architecture prompt.
PS1="$(lsb_release -c 2>/dev/null | cut -f2)-$(dpkg --print-architecture 2>/dev/null) \h:\w \[\e[1m\]\$\[\e[0m\] "

# Git branch in prompt.
[ -f /etc/bash_completion.d/git ] && {
	. /etc/bash_completion.d/git
	[ "\$(type -t __git_ps1)" ] && PS1="\$(__git_ps1 '(%s) ')$PS1"
}

# My bin.
[ -d ~/bin ] && export PATH="$HOME/bin:$PATH"

# MacPorts.
[ -d /opt/local/bin ] && export PATH="/opt/local/bin:$PATH"

# QProf.
[ -f /usr/local/lib/qprof/alias.sh ] && . /usr/local/lib/qprof/alias.sh

DYNAMIC_MANPATH='$(
	echo -n $(manpath)
	for MAN in /{usr/lib/ruby,var/lib}/gems/1.8/gems/*/man /opt/local{/share,}/man; do
		echo -n :$MAN
	done
)'
alias mandb="mandb $DYNAMIC_MANPATH"
alias man="man -M$DYNAMIC_MANPATH"
alias whatis="whatis -M$DYNAMIC_MANPATH"
alias apropos="apropos -M$DYNAMIC_MANPATH"

alias gh-pages='git symbolic-ref HEAD refs/heads/gh-pages && rm .git/index && git clean -fdx'

[ -f /etc/profile.d/sandbox_prompt.sh ] && . /etc/profile.d/sandbox_prompt.sh

which ssh-agent >/dev/null && {
	: ${SSH_AUTH_SOCK:=$(echo /tmp/ssh-*/agent.* | cut -d" " -f1)}
	[ -S "$SSH_AUTH_SOCK" ] && {
		export SSH_AUTH_SOCK
	} || {
		eval $(ssh-agent)
		ssh-add
	}
}
