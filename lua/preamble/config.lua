---@class PreambleFiletypeOptions
---@field allowlist? string[]
---@field denylist? string[]

---@class PreambleOptions
---@field templates_dir string
---@field author? string
---@field email? string
---@field enabled boolean
---@field filetypes PreambleFiletypeOptions
---@field header_scan_lines integer

local M = {}

---@type PreambleOptions
M.defaults = {
  templates_dir = vim.fn.stdpath("config") .. "/templates/",
  author = nil,
  email = nil,
  enabled = true,
  filetypes = {
    allowlist = nil,
    denylist = nil,
  },
  header_scan_lines = 20,
}

---@type PreambleOptions
M.opts = vim.deepcopy(M.defaults)

---@param value any
---@return boolean
local function is_empty(value)
  return value == nil or value == ""
end

---@param path string|nil
---@return string
local function normalize_templates_dir(path)
  if is_empty(path) then
    return M.defaults.templates_dir
  end

  if path:sub(-1) ~= "/" then
    return path .. "/"
  end

  return path
end

---@param opts PreambleOptions|nil
---@return PreambleOptions
function M.merge(opts)
  local merged = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
  merged.templates_dir = normalize_templates_dir(merged.templates_dir)
  return merged
end

---@param opts PreambleOptions|nil
function M.setup(opts)
  M.opts = M.merge(opts)
end

---@param ft string
---@return boolean
function M.allowed_filetype(ft)
  local allowlist = M.opts.filetypes.allowlist
  local denylist = M.opts.filetypes.denylist

  if type(allowlist) == "table" and #allowlist > 0 then
    local allowed = false
    for _, entry in ipairs(allowlist) do
      if entry == ft then
        allowed = true
        break
      end
    end

    if not allowed then
      return false
    end
  end

  if type(denylist) == "table" and #denylist > 0 then
    for _, entry in ipairs(denylist) do
      if entry == ft then
        return false
      end
    end
  end

  return true
end

return M
