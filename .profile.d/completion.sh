if [ -d "/usr/local/Cellar/git" ]
then . "/usr/local/Cellar/git/$(ls -1 "/usr/local/Cellar/git" | sort -k1nr -k2nr -k3nr -t"." | head -n"1")/etc/bash_completion.d/git-completion.bash"
fi
