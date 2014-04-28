# Extra search pathnames.
for BINDIR in "$HOME/local/bin" "$HOME/bin" "$HOME/node_modules/.bin" "/opt/local/bin" "/usr/local/heroku/bin" /var/lib/gems/*/bin
do
	[ -d "$BINDIR" ] || continue
	expr "$PATH" : ".*$BINDIR" >"/dev/null" && continue
	export PATH="$BINDIR:$PATH"
done
