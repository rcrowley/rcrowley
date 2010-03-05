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

# Preferred versions.
[[ -n "$(which pick-php)" ]] && . pick-php 5.3
[[ -n "$(which pick-python)" ]] && . pick-python 2.6
[[ -n "$(which pick-ruby)" && root != "$(whoami)" ]] && . pick-ruby 1.8

# System RubyGems executables.
export PATH="/var/lib/gems/1.8/bin:$PATH"

# MacPorts.
[[ -d /opt/local/bin ]] && export PATH="/opt/local/bin:$PATH"

# QProf.
[[ -f /usr/local/lib/qprof/alias.sh ]] && . /usr/local/lib/qprof/alias.sh
