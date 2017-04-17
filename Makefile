PUB=/usr/lib/dart/bin/pub
DART=dart


.PHONY = release debug clean

release:
	${PUB} build --mode release

debug:
	${PUB} build --mode debug

get:
	${PUB} get

web/pixelcity.html: web/debug.html
	-tidy -errors debug.html
	./htmlpp.py <web/debug.html  >$@

clean:
	rm -r build/
