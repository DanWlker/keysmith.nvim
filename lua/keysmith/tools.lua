local M = {}

-- Credit to Mini.nvim
---@param msg string
M.error = function(msg) error('(keysmith) ' .. msg, 0) end

-- Credit to Mini.nvim
---@param msg string
M.error_treesitter = function(msg)
  local buf_id, ft = vim.api.nvim_get_current_buf(), vim.bo.filetype
  local has_lang, lang = pcall(vim.treesitter.language.get_lang, ft)
  lang = has_lang and lang or ft
  local msg = string.format('Can not get %s for buffer %d and language "%s".', msg, buf_id, lang)
  M.error(msg)
end

---@return Keysmith.NodeItem
M.get_all_nodes = function()
  -- TODO: Implement
end

return M
