SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
SASS = node_modules/.bin/sass

target = ../../MacDown/Resources/Styles/GitHub-2020.css

all: $(target)

$(target): index.sass package-lock.json Makefile
	$(SASS) --no-source-map --load-path=node_modules $< | sed s/.markdown-body/body/ > $@.tmp
	test -s $@.tmp
	mv $@.tmp $@

clean:
	$(RM) $(target) $(target).tmp

.PHONY: all clean
