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

# Tree-sitter
dev: $(TSDIR)
$(TSDIR):
	@git clone --depth=1 $(TS_REPO)
	@printf "\e[1m\e[31mNote\e[22m npm build can take a while\n" >&2
	cd $(TSDIR) &&                                         \
		npm --loglevel=info --progress=true install && \
		npm run generate

.PHONY: parse-%
parse-%:
	cd $(TSDIR) && npx tree-sitter parse $(TESTDIR)/$(subst parse-,,$@)

clean:
	$(RM) *~
