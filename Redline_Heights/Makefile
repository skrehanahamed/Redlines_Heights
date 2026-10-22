# Redline Heights - build/run helper (macOS, Godot 4.7)
#   make run      play the game - Redline Island only (fast start, the default while we build the island)
#   make full     play the whole map (mainland town, airport, railway, hills and the island)
#   make edit     open the project in the Godot editor
#   make import   (re)import assets - run once after adding new files
#   make test     numeric driving test (headless)
#   make clean    delete Godot's import cache (.godot) - next run re-imports everything

GODOT ?= /Applications/Godot.app/Contents/MacOS/Godot

.PHONY: run full edit import test animtest clean

run:
	@test -d .godot || $(MAKE) import
	"$(GODOT)" --path .

full:
	@test -d .godot || $(MAKE) import
	"$(GODOT)" --path . -- --full

edit:
	"$(GODOT)" --editor --path .

import:
	"$(GODOT)" --headless --path . --import

test:
	"$(GODOT)" --headless --path . res://scenes/game.tscn -- --drivetest

animtest:
	"$(GODOT)" --headless --path . res://scenes/game.tscn -- --animtest

clean:
	rm -rf .godot
