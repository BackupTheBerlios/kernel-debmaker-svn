all:

clean:

install:
	install -m 544 -g root -o root src/kernel-debmaker.pl $(DESTDIR)/usr/bin/kernel-debmaker

uninstall:
	rm -f $(DESTDIR)/usr/bin/kernel-debmaker

# builds the debian package
package:
	dpkg-buildpackage -rfakeroot
