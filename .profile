# ~/.profile: executed by Bourne-compatible login shells.

[ "$BASH" -a -f ~/.bashrc ] && . ~/.bashrc

mesg n

for PATHNAME in .profile.d/*.sh
do
	. "$PATHNAME"
done
