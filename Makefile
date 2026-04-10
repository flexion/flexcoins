GODOT := /Applications/Godot.app/Contents/MacOS/Godot

.PHONY: lint test test-json ci run clean

## Run headless lint on all scenes
lint:
	$(GODOT) --headless --script res://tools/lint_project.gd -- --all --fail-on-warn

## Run unit tests
test:
	$(GODOT) --headless --script res://tools/run_tests.gd

## Run unit tests with JSON output
test-json:
	$(GODOT) --headless --script res://tools/run_tests.gd -- --json

## Run full CI pipeline (lint + unit tests + E2E)
ci:
	bash scripts/ci_test.sh

## Launch the game
run:
	$(GODOT) --path .

## Remove Godot import cache
clean:
	rm -rf .godot/imported
