all:

clean:
	rm -f doc/kernel-debmaker.1.{gz,html}

install:
	install -m 544 -g root -o root src/kernel-debmaker.pl $(DESTDIR)/usr/bin/kernel-debmaker
	install -m 644 -g root -o root doc/kernel-debmaker.1.gz $(DESTDIR)/usr/share/man/man1
	mkdir $(DESTDIR)/usr/share/doc/kernel-debmaker
	install -m 644 -g root -o root doc/kernel-debmaker.1.html $(DESTDIR)/usr/share/doc/kernel-debmaker

uninstall:
	rm -f $(DESTDIR)/usr/bin/kernel-debmaker

# builds the debian package
package:
	dpkg-buildpackage -rfakeroot

check:
	./test/test.pl

doc:
	# convert SGML to man
	/usr/bin/docbook-to-man doc/kernel-debmaker.1.sgml > doc/kernel-debmaker.1
	# convert SGML to HTML
	cp doc/kernel-debmaker.1.sgml /tmp
	( cd /tmp && /usr/bin/docbook2html kernel-debmaker.1.sgml )
	mv /tmp/index.html doc/kernel-debmaker.1.html
	rm -f /tmp/kernel-debmaker.1.sgml
	# compress man
	rm -f doc/kernel-debmaker.1.gz
	( cd doc/ && gzip kernel-debmaker.1 )

# convert man to html
# TODO

.PHONY: doc
