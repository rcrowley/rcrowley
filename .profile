[ "$BASH" -a -f ~/.bashrc ] && . ~/.bashrc

mesg n

for PATHNAME in ~/.profile.d/*.sh
do . "$PATHNAME"
done
