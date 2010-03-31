# ~/.profile: executed by Bourne-compatible login shells.

if [[ "$BASH" ]]; then
	if [[ -f ~/.bashrc ]]; then
		. ~/.bashrc
	fi
fi

mesg n

if [[ -f /etc/bash_completion.d/git ]]; then
	. /etc/bash_completion.d/git
	if [[ "\$(type -t __git_ps1)" ]]; then
		PS1="\$(__git_ps1 '(%s) ')$PS1"
	fi
fi

[[ -d ~/bin ]] && export PATH="$HOME/bin:$PATH"

# MacPorts.
[[ -d /opt/local/bin ]] && export PATH="/opt/local/bin:$PATH"

# QProf.
[[ -f /usr/local/lib/qprof/alias.sh ]] && . /usr/local/lib/qprof/alias.sh

DYNAMIC_MANPATH='$(
	echo -n $(manpath)
	for MAN in /var/lib/gems/1.8/gems/*/man; do
		echo -n :$MAN
	done
)'
alias mandb="mandb $DYNAMIC_MANPATH"
alias man="man -M$DYNAMIC_MANPATH"
alias whatis="whatis -M$DYNAMIC_MANPATH"
alias apropos="apropos -M$DYNAMIC_MANPATH"

alias gh-pages='git symbolic-ref HEAD refs/heads/gh-pages && rm .git/index && git clean -fdx'
