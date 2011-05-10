# Extra search pathnames.
for BINDIR in "$HOME/bin" "$HOME/go/bin" "/opt/local/bin" /var/lib/gems/*/bin
do
	[ -d "$BINDIR" ] || continue
	expr "$PATH" : ".*$BINDIR" >/dev/null && continue
	export PATH="$BINDIR:$PATH"
done
