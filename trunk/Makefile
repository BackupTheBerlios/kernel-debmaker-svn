all:

clean:

install:
	install -m 544 -g root -o root src/kernel-debmaker.pl $(DESTDIR)/usr/bin/kernel-debmaker
	install -m 644 -g root -o root doc/kernel-debmaker.1.gz $(DESTDIR)/usr/share/man/man1

uninstall:
	rm -f $(DESTDIR)/usr/bin/kernel-debmaker

# builds the debian package
package:
	dpkg-buildpackage -rfakeroot

doc:
# convert SGML to man.
	/usr/bin/docbook-to-man doc/kernel-debmaker.1.sgml > doc/kernel-debmaker.1
# compress man
	rm -f doc/kernel-debmaker.1.gz
	( cd doc/ && gzip kernel-debmaker.1 )
	echo "done\n"

# convert man to html
# TODO

.PHONY: doc
