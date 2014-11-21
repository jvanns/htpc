DESTDIR ?=

install:
	install -CD -o root -g root -m 0755 consolidate.py $(DESTDIR)/usr/local/bin/consolidate
	install -CD -o root -g root -m 0755 blutit.py $(DESTDIR)/usr/local/bin/blutit
	install -CD -o root -g root -m 0755 audio-prefs.py $(DESTDIR)/usr/local/bin/audio-prefs
	install -CD -o root -g root -m 0755 audio-info.sh $(DESTDIR)/usr/local/bin/audio-info
	install -CD -o root -g root -m 0755 embed-album-art.sh $(DESTDIR)/usr/local/bin/embed-album-art
	install -CD -o root -g root -m 0755 rename-album.sh $(DESTDIR)/usr/local/bin/rename-album
	install -CD -o root -g root -m 0755 id3map.sh $(DESTDIR)/usr/local/bin/id3map
	install -CD -o root -g root -m 0755 itunes-migrator.sh $(DESTDIR)/usr/local/bin/itunes-migrator
	install -CD -o root -g root -m 0755 backup.sh $(DESTDIR)/usr/local/sbin/backup
	install -C -o root -g root -m 0755 dsc-trg-q $(DESTDIR)/usr/local/sbin/
	install -C -o root -g root -m 0755 dsc-trg-q-prologue $(DESTDIR)/usr/local/sbin/
	install -C -o root -g root -m 0755 dsc-trg-q-epilogue $(DESTDIR)/usr/local/sbin/
	install -C -o root -g root -m 0755 dsc-trg-dq $(DESTDIR)/usr/local/sbin/
	install -C -o root -g root -m 0755 dsc-trg-dq-prologue $(DESTDIR)/usr/local/sbin/
	install -C -o root -g root -m 0755 dsc-trg-dq-epilogue $(DESTDIR)/usr/local/sbin/
	install -CD -o root -g root -m 0644 host_root/etc/udev/rules.d/75-optical-drive.rules $(DESTDIR)/etc/udev/rules.d/75-optical-drive.rules
	install -C -o root -g root -m 0644 host_root/etc/dsc-trg.conf $(DESTDIR)/etc
	install -C -o root -g root -m 0644 host_root/etc/abcde.conf $(DESTDIR)/etc
	install -CD -o root -g root -m 0644 host_root/etc/id3map/genre.db $(DESTDIR)/etc/id3map/genre.db

release:
	git archive --format=tar --prefix=htpc/ HEAD | gzip 1> htpc.tar.gz

.PHONY: install .release
