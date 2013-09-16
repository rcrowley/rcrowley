LAYOUTS=content.html page.html title.html
EXCLUDE=$(LAYOUTS) \
	about.html \
	index.html \
	links.html \
	xul.html

all: feed pages slides

feed: var/www/index.xml

pages: $(shell find share/templates -name \*.html $(addprefix \! -name ,$(LAYOUTS)) -printf var/www/%P\\n)

var/www/%.html: share/templates/%.html
	mkdir -p $(shell dirname $@)
	build page <$< >$@

var/www/%.xml: var/www/%.html
	grep \<li\>\<time <$< | sort -r | head -n15 | cut -d\" -f4 | cut -c2- | python build.py feed >$@

var/www/talks/%.html: share/slides/%.slide
	presentme $< >$@

slides: $(shell find share/slides -name \*.slide -printf var/www/talks/%P\\n | sed s/.slide$$/.html/)

.PHONY: all deploy feed pages reload slides
