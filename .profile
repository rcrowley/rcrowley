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

[[ -d ~/bin ]] && export PATH="~/bin:$PATH"

# Preferred versions
[[ -d /opt/Python-2.6.2/bin ]] && export PATH="/opt/Python-2.6.2/bin:$PATH"
[[ -d /opt/ruby-1.8.7-p174/bin ]] && export PATH="/opt/ruby-1.8.7-p174/bin:$PATH"

# MacPorts
[[ -d /opt/local/bin ]] && export PATH="/opt/local/bin:$PATH"
