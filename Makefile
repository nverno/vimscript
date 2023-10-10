SHELL =  /bin/bash
emacs ?= emacs
wget  ?= wget

TS_REPO ?= https://github.com/neovim/tree-sitter-vim
TSDIR   = $(notdir $(TS_REPO))


all:
	@echo $(TSDIR)

.PHONY: test
test:
	$(emacs) -Q -batch -L . -l ert -l test/vimscript-tests.el \
	-f ert-run-tests-batch-and-exit

README.md : el2markdown.el vimscript.el
	$(emacs) -batch -l $< vimscript.el -f el2markdown-write-readme

.INTERMEDIATE: el2markdown.el
el2markdown.el:
	$(wget) -q -O $@ "https://github.com/Lindydancer/el2markdown/raw/master/el2markdown.el"

# Tree-sitter
dev: $(TSDIR)
$(TSDIR):
	@git clone --depth=1 $(TS_REPO)
	@printf "\33[1m\33[31mNote\33[22m npm build can take a while" >&2
	cd $(TSDIR) &&                                         \
		npm --loglevel=info --progress=true install && \
		npm run generate

.PHONY: parse-%
parse-%:
	cd $(TSDIR) && npx tree-sitter parse $(TESTDIR)/$(subst parse-,,$@)

clean:
	$(RM) *~
