emacs ?= emacs
wget ?= wget

.PHONY: test
all: test
test:
	$(emacs) -Q -batch -L . -l ert -l test/vimscript-tests.el \
	-f ert-run-tests-batch-and-exit

README.md : el2markdown.el vimscript.el
	$(emacs) -batch -l $< vimscript.el -f el2markdown-write-readme

.INTERMEDIATE: el2markdown.el
el2markdown.el:
	$(wget) -q -O $@ "https://github.com/Lindydancer/el2markdown/raw/master/el2markdown.el"

clean:
	$(RM) *~
