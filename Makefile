TESTS_INIT=tests/minimal_init.lua
TESTS_DIR=tests/coderadio/

.PHONY: test lint

test:
	@nvim \
		--headless \
		--noplugin \
		-u ${TESTS_INIT} \
		-c "PlenaryBustedDirectory ${TESTS_DIR} { minimal_init = '${TESTS_INIT}' }"

lint:
	@stylua --check lua/ tests/

format:
	@stylua lua/ tests/
