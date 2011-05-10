# All so manual pages in gems and other non-standard paths are available.
DYNAMIC_MANPATH='$(
	echo -n $(manpath)
	for MAN in /{usr/lib/ruby,var/lib}/gems/1.8/gems/*/man /opt/local{/share,}/man; do
		echo -n :$MAN
	done
)'
alias mandb="mandb $DYNAMIC_MANPATH"
alias man="man -M$DYNAMIC_MANPATH"
alias whatis="whatis -M$DYNAMIC_MANPATH"
alias apropos="apropos -M$DYNAMIC_MANPATH"
