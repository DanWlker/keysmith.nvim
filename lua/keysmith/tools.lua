local M = {}

-- Credit to mini.nvim
---@param msg string
M.error = function(msg) error('(keysmith) ' .. msg, 0) end

-- Credit to mini.nvim
---@param msg string
M.error_treesitter = function(msg)
  local buf_id, ft = vim.api.nvim_get_current_buf(), vim.bo.filetype
  local has_lang, lang = pcall(vim.treesitter.language.get_lang, ft)
  lang = has_lang and lang or ft
  msg = string.format('Can not get %s for buffer %d and language "%s".', msg, buf_id, lang)
  M.error(msg)
end

---@param using_parser string
---@return Keysmith.NodeItem[]
M.get_all_leaf_nodes = function(using_parser) return require('keysmith.lang.' .. using_parser).get_all_leaf_nodes() end

---@param using_parser string
---@return Keysmith.NodeItem[]
M.get_node = function(using_parser) return require('keysmith.lang.' .. using_parser).get_node() end

---@return table<string, boolean>
M.get_files_without_extension = function(dir)
  local names = {}

  local fs = vim.uv.fs_scandir(dir)
  if not fs then
    return names
  end

  while true do
    local name, type = vim.uv.fs_scandir_next(fs)
    if not name then
      break
    end
    if type == 'file' then
      local base = name:match '(.+)%..+$' or name -- strip extension
      -- table.insert(names, base)
      names[base] = true
    end
  end

  return names
end

return M
