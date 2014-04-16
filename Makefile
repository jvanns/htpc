DESTDIR ?=

install:
	install -CD -o root -g root -m 0755 consolidate.py $(DESTDIR)/usr/local/bin/consolidate
	install -CD -o root -g root -m 0755 blutit.py $(DESTDIR)/usr/local/bin/blutit
	install -CD -o root -g root -m 0755 audio-prefs.py $(DESTDIR)/usr/local/bin/audio-prefs
	install -CD -o root -g root -m 0755 audio-info.sh $(DESTDIR)/usr/local/bin/audio-info
	install -CD -o root -g root -m 0755 backup.sh $(DESTDIR)/usr/local/sbin/backup
	install -C -o root -g root -m 0755 disc-trigger $(DESTDIR)/usr/local/sbin/
	install -C -o root -g root -m 0755 disc-trigger-prologue $(DESTDIR)/usr/local/sbin/
	install -C -o root -g root -m 0755 disc-trigger-epilogue $(DESTDIR)/usr/local/sbin/
	install -CD -o root -g root -m 0644 75-optical-drive.rules $(DESTDIR)/etc/udev/rules.d/75-optical-drive.rules
	install -C -o root -g root -m 0644 disc-trigger.conf $(DESTDIR)/etc
	install -C -o root -g root -m 0644 abcde.conf $(DESTDIR)/etc

release:
	git archive --format=tar --prefix=htpc/ HEAD | gzip 1> htpc.tar.gz

.PHONY: install .release
