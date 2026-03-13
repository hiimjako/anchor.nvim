PLENARY_DIR ?= ../plenary.nvim

.PHONY: test lint

test:
	nvim --headless -u tests/minimal_init.lua \
		-c "PlenaryBustedDirectory tests/anchor_nvim/ {minimal_init = 'tests/minimal_init.lua', sequential = true}"

test-file:
	nvim --headless -u tests/minimal_init.lua \
		-c "PlenaryBustedFile $(FILE)"

lint:
	stylua --check lua/ tests/

format:
	stylua lua/ tests/
