# preamble.nvim

A small Neovim plugin that inserts file preambles (headers) from templates when new files are created.

## Features

- Inserts preambles on `BufNewFile`.
- Inserts only when the buffer is empty (`0` lines or a single empty line).
- Uses filetype-specific templates from:
  - `vim.fn.stdpath("config") .. "/templates/<filetype>.template"`
- Safely does nothing when no template exists.
- Replaces placeholders with file/date/author metadata.
- Supports `<CURSOR>` placement after insertion.
- Exposes:
  - `setup()`
  - `:PreambleInsert[!]`
  - `:PreamblePreview`
  - `require("preamble").insert({ force = false })`
  - `require("preamble").render()`

## Installation

### lazy.nvim

```lua
{
  "tkruer/preamble.nvim",
  config = function()
    require("preamble").setup()
  end,
}
```

### LazyVim (detailed)

Create a plugin spec file such as:

- `~/.config/nvim/lua/plugins/preamble.lua`

Then add:

```lua
return {
  "tkruer/preamble.nvim",
  event = "BufNewFile",
  config = function()
    require("preamble").setup({
      author = "Your Name",
      email = "you@example.com",
      enabled = true,
      templates_dir = vim.fn.stdpath("config") .. "/templates/",
      filetypes = {
        allowlist = nil, -- e.g. { "lua", "python", "c" }
        denylist = nil,  -- e.g. { "txt", "markdown" }
      },
    })
  end,
}
```

Optional globals you can set in your LazyVim config (for example in `lua/config/options.lua`):

```lua
vim.g.header_author = "Your Name"
vim.g.header_email = "you@example.com"
```

> `opts.author` / `opts.email` passed to `setup()` take precedence over globals.

## Configuration

```lua
require("preamble").setup({
  templates_dir = vim.fn.stdpath("config") .. "/templates/",
  author = nil,
  email = nil,
  enabled = true,
  filetypes = {
    allowlist = nil, -- e.g. { "lua", "python" }
    denylist = nil,  -- e.g. { "txt" }
  },
})
```

Author/email resolution order:

- `<AUTHOR>`
  1. `opts.author`
  2. `vim.g.header_author`
  3. `$GIT_AUTHOR_NAME`
  4. `$USER`
  5. `"Unknown"`
- `<EMAIL>`
  1. `opts.email`
  2. `vim.g.header_email`
  3. `$GIT_AUTHOR_EMAIL`
  4. `$EMAIL`
  5. empty string

## Templates

Place templates in your config templates directory:

- `~/.config/nvim/templates/lua.template`
- `~/.config/nvim/templates/c.template`
- `~/.config/nvim/templates/python.template`

Included example templates are in this repository under [`templates/`](./templates).

## Placeholders

- `<FILE>` => `expand("%:t")`
- `<PATH>` => `expand("%")`
- `<DATE>` => `YYYY-MM-DD`
- `<DATETIME>` => `YYYY-MM-DD HH:MM`
- `<YEAR>` => `YYYY`
- `<AUTHOR>` => resolved author value
- `<EMAIL>` => resolved email value
- `<CURSOR>` => removed from output and cursor placed at that position

If `<CURSOR>` is missing, cursor moves to the first non-comment line after insertion (or line 1 fallback).

## Commands

- `:PreambleInsert` — insert preamble when buffer is empty.
- `:PreambleInsert!` — force insert even when buffer is not empty.
- `:PreamblePreview` — open rendered template in a scratch buffer.

## Lua API

```lua
require("preamble").insert({ force = false })
require("preamble").render()
```


## Development

Recommended tooling:

- [StyLua](https://github.com/JohnnyMorganz/StyLua) for formatting
- [Luacheck](https://github.com/mpeterv/luacheck) for linting

Convenience targets are included in the `justfile`:

```bash
just format       # format lua/plugin/tests with stylua
just format-check # verify formatting
just lint         # run luacheck
just test         # run unit tests
```

CI (`.github/workflows/ci.yml`) runs format checks, linting, and tests on push and pull requests.

## Duplicate preamble guard

The plugin scans the first 20 lines and skips insertion if it detects common markers such as `File:`.
