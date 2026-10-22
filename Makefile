# Top-level Makefile for Redline Heights.
# The project path has a trailing space, so every path is quoted.
#   make run     play the game, Redline Island only (imports assets automatically the first time)
#   make full    play the whole map
#   make edit    open the Godot editor
#   make import  re-import assets
#   make test    headless driving test
#   make clean   remove the import cache

GAME := $(CURDIR)/Redline_Heights

.PHONY: run full edit import test animtest clean

run full edit import test animtest clean:
	$(MAKE) -C "$(GAME)" $@
