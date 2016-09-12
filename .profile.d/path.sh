# Extra search pathnames.
for BINDIR in "$HOME/local/bin" "$HOME/bin" "$HOME/src/"*"/"*"/"*"/.virtualenv/bin" "$HOME/node_modules/.bin"
do
	[ -d "$BINDIR" ] || continue
	expr "$PATH" : ".*$BINDIR" >"/dev/null" && continue
	export PATH="$BINDIR:$PATH"
done
