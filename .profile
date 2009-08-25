# ~/.profile: executed by Bourne-compatible login shells.

if [ "$BASH" ]; then
  if [ -f ~/.bashrc ]; then
    . ~/.bashrc
  fi
fi

mesg n

source /etc/bash_completion.d/git
if [[ "\$(type -t __git_ps1)" ]]; then
	PS1="\$(__git_ps1 '(%s) ')$PS1"
fi

set -o vi
