local config = require("preamble.config")
local preamble = require("preamble.preamble")

local M = {}

M._opts = config.opts

---@param msg string
---@param level integer|nil
local function notify(msg, level)
  pcall(vim.notify, msg, level or vim.log.levels.INFO, { title = "preamble" })
end

local function setup_commands()
  pcall(vim.api.nvim_del_user_command, "PreambleInsert")
  pcall(vim.api.nvim_del_user_command, "PreamblePreview")

  vim.api.nvim_create_user_command("PreambleInsert", function(command_opts)
    local inserted = preamble.insert({ force = command_opts.bang })
    if not inserted then
      notify("Preamble not inserted", vim.log.levels.DEBUG)
    end
  end, { bang = true, desc = "Insert file preamble" })

  vim.api.nvim_create_user_command("PreamblePreview", function()
    local rendered = preamble.render()
    if not rendered then
      notify("No preamble template available for this filetype", vim.log.levels.WARN)
      return
    end

    vim.cmd("new")
    local preview_buf = vim.api.nvim_get_current_buf()
    vim.bo[preview_buf].buftype = "nofile"
    vim.bo[preview_buf].bufhidden = "wipe"
    vim.bo[preview_buf].swapfile = false
    vim.bo[preview_buf].modifiable = true
    vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, rendered.lines)
    vim.bo[preview_buf].modifiable = false
    vim.bo[preview_buf].filetype = "headerpreview"
  end, { desc = "Preview rendered file preamble" })
end

local function setup_autocmd()
  local group = vim.api.nvim_create_augroup("Preamble", { clear = true })

  vim.api.nvim_create_autocmd("BufNewFile", {
    group = group,
    callback = function()
      preamble.insert({ force = false })
    end,
  })
end

M.render = preamble.render
M.insert = preamble.insert

---@param opts? PreambleOptions
function M.setup(opts)
  config.setup(opts)
  M._opts = config.opts
  setup_autocmd()
  setup_commands()
end

return M
