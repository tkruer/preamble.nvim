package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local function assert_eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or "assert_eq failed") .. "\nexpected: " .. tostring(expected) .. "\nactual: " .. tostring(actual), 2)
  end
end

local function assert_true(value, msg)
  if not value then
    error(msg or "expected true", 2)
  end
end

local function assert_false(value, msg)
  if value then
    error(msg or "expected false", 2)
  end
end

local function reset_vim(state)
  local cwd = state.cwd or "/repo"
  local current_file = state.current_file or "src/main.lua"
  local current_filename = state.current_filename or "main.lua"
  local buffer_lines = state.buffer_lines or { "" }
  local filetype = state.filetype or "lua"
  local commentstring = state.commentstring or "-- %s"
  local files = state.files or {}

  _G.vim = {
    g = {},
    env = state.env or {},
    bo = setmetatable({ filetype = filetype }, {
      __index = function()
        return {
          buftype = "",
          bufhidden = "",
          swapfile = false,
          modifiable = true,
          filetype = "",
        }
      end,
      __newindex = function(t, k, v)
        rawset(t, k, v)
      end,
    }),
    log = { levels = { INFO = 1, DEBUG = 2, WARN = 3 } },
    notify = function() end,
    trim = function(s)
      return (s:gsub("^%s+", ""):gsub("%s+$", ""))
    end,
    startswith = function(s, prefix)
      return s:sub(1, #prefix) == prefix
    end,
    deepcopy = function(tbl)
      if type(tbl) ~= "table" then
        return tbl
      end
      local out = {}
      for k, v in pairs(tbl) do
        out[k] = _G.vim.deepcopy(v)
      end
      return out
    end,
    tbl_deep_extend = function(_, a, b)
      local out = _G.vim.deepcopy(a)
      local function merge(dst, src)
        for k, v in pairs(src or {}) do
          if type(v) == "table" and type(dst[k]) == "table" then
            merge(dst[k], v)
          else
            dst[k] = v
          end
        end
      end
      merge(out, b)
      return out
    end,
    uv = {
      fs_stat = function(path)
        if files[path] ~= nil then
          return { type = "file" }
        end
        return nil
      end,
    },
    fn = {
      stdpath = function()
        return "/config"
      end,
      readfile = function(path)
        local content = files[path]
        if not content then
          error("missing file")
        end
        return content
      end,
      expand = function(expr)
        if expr == "%:t" then
          return current_filename
        end
        if expr == "%" then
          return current_file
        end
        return ""
      end,
    },
    cmd = function() end,
    api = {
      nvim_get_current_buf = function()
        return 1
      end,
      nvim_buf_line_count = function()
        return #buffer_lines
      end,
      nvim_buf_get_lines = function(_, start_i, end_i)
        local out = {}
        local last = math.min(end_i, #buffer_lines)
        for i = start_i + 1, last do
          out[#out + 1] = buffer_lines[i]
        end
        return out
      end,
      nvim_buf_set_lines = function(_, start_i, end_i, _, lines)
        if start_i == 0 and end_i == -1 then
          buffer_lines = {}
          for i, line in ipairs(lines) do
            buffer_lines[i] = line
          end
        end
      end,
      nvim_win_set_cursor = function(_, pos)
        state.cursor = pos
      end,
      nvim_buf_get_option = function(_, opt)
        if opt == "commentstring" then
          return commentstring
        end
        return ""
      end,
      nvim_create_user_command = function() end,
      nvim_del_user_command = function() end,
      nvim_create_augroup = function()
        return 1
      end,
      nvim_create_autocmd = function(_, spec)
        state.autocmd_callback = spec.callback
      end,
    },
  }

  return function()
    return buffer_lines
  end
end

local function run_tests()
  local state = {}
  local template_path = "/config/templates/lua.template"
  local get_lines = reset_vim({
    filetype = "lua",
    files = {
      [template_path] = {
        "-- File: <FILE>",
        "-- Path: <PATH>",
        "-- Date: <DATE>",
        "<CURSOR>",
      },
    },
    buffer_lines = { "" },
    current_file = "src/main.lua",
    current_filename = "main.lua",
    env = { USER = "dev" },
  })

  package.loaded["preamble"] = nil
  local preamble = require("preamble")

  preamble.setup({ enabled = true })
  local rendered = preamble.render()
  assert_true(rendered ~= nil, "render should return content for known template")
  assert_eq(rendered.lines[1], "-- File: main.lua")
  assert_eq(rendered.lines[2], "-- Path: src/main.lua")

  local inserted = preamble.insert()
  assert_true(inserted, "insert should work for empty buffer")
  local lines = get_lines()
  assert_eq(lines[1], "-- File: main.lua")
  assert_eq(lines[4], "")
  assert_eq(state.cursor[1], 4)
  assert_eq(state.cursor[2], 0)

  local second_insert = preamble.insert()
  assert_false(second_insert, "second insert should not run on non-empty buffer")

  local state2 = {}
  local get_lines2 = reset_vim({
    filetype = "lua",
    files = { [template_path] = { "-- Hello", "body" } },
    buffer_lines = { "-- File: existing.lua" },
    env = { USER = "dev" },
  })
  package.loaded["preamble"] = nil
  preamble = require("preamble")
  preamble.setup({ enabled = true })
  assert_false(preamble.insert({ force = true }), "force insert still blocked when marker exists")
  assert_eq(get_lines2()[1], "-- File: existing.lua")

  local state3 = {}
  reset_vim({
    filetype = "python",
    files = {},
    buffer_lines = { "" },
    env = { USER = "dev" },
  })
  package.loaded["preamble"] = nil
  preamble = require("preamble")
  preamble.setup({ enabled = true })
  assert_eq(preamble.render(), nil, "render should return nil without template")

  local state4 = {}
  local get_lines4 = reset_vim({
    filetype = "lua",
    files = {
      [template_path] = {
        "-- Author: <AUTHOR>",
        "-- Email: <EMAIL>",
      },
    },
    buffer_lines = { "" },
    env = { USER = "fallback-user" },
  })
  _G.vim.g.header_author = "Global Author"
  _G.vim.g.header_email = "global@example.com"
  package.loaded["preamble"] = nil
  preamble = require("preamble")
  preamble.setup({ author = "Opt Author", email = "opt@example.com" })
  assert_true(preamble.insert())
  local lines4 = get_lines4()
  assert_eq(lines4[1], "-- Author: Opt Author")
  assert_eq(lines4[2], "-- Email: opt@example.com")

  print("All tests passed")
end

run_tests()
