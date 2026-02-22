set shell := ["bash", "-cu"]

# Run plugin unit tests
test:
  lua tests/test_preamble.lua

# Lint Lua sources
lint:
  luacheck lua plugin tests

# Format Lua sources
format:
  stylua lua plugin tests

# Verify Lua formatting
format-check:
  stylua --check lua plugin tests
