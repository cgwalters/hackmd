# https://github.com/jgm/pandoc/wiki/Using-pandoc-to-produce-reveal.js-slides
getreveal:
	test -d reveal.js || (curl -L https://github.com/hakimel/reveal.js/archive/master.tar.gz | tar -xzf - && mv reveal.js-master reveal.js)

%.html: %.md Makefile
	pandoc -Vtheme=simple -t revealjs -s -o $@ $<
