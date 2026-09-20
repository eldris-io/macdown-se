ALL: version.h

version.h: ../../MacDown/MacDown-Info.plist ../../Tools/utils.sh ../../Tools/generate_version_header.sh
	bash ../../Tools/generate_version_header.sh

.PHONY: install clean distclean

install: ALL

clean:
	-rm version.h 2>/dev/null

distclean: clean
