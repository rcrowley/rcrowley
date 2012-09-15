# Extra search pathnames.
for BINDIR in "$HOME/bin" "/opt/local/bin" "/usr/go/bin" /var/lib/gems/*/bin
do
	[ -d "$BINDIR" ] || continue
	expr "$PATH" : ".*$BINDIR" >/dev/null && continue
	export PATH="$BINDIR:$PATH"
done
