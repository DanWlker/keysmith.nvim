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
---@return Keysmith.NodeItem[] | nil
M.get_all_leaf_keysmith_nodes = function(using_parser) return require('keysmith.lang.' .. using_parser).get_all_leaf_keysmith_nodes() end

---@param using_parser string
---@return Keysmith.NodeItem | nil
M.get_keysmith_node = function(using_parser) return require('keysmith.lang.' .. using_parser).get_keysmith_node() end

return M
