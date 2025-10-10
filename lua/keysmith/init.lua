local tools = require 'keysmith.tools'

local M = {}

---@type Keysmith.Config
M.opts = {
  -- ft_parser = {
  -- 	yaml = "yaml",
  -- 	["yaml.helm-chartfile"] = "yaml",
  -- 	json = "json",
  -- 	kitty = "kitty",
  -- 	toml = "toml",
  -- },
}

---@param opts Keysmith.Config
M.setup = function(opts)
  ---@type Keysmith.Config
  M.opts = vim.tbl_extend('force', M.opts, opts or {})
end

M.select_all_keys = function()
  local parser_name, ok = M.can_parse()
  if not ok then
    tools.error_treesitter 'parser'
    return
  end

  vim.ui.select(
    tools.get_all_leaf_nodes(parser_name),
    {
      prompt = 'Keysmith',
      ---@param item Keysmith.NodeItem
      format_item = function(item) return item.key end,
    },
    ---@param item Keysmith.NodeItem
    function(item)
      local start_row, start_col = item.target_node:start()
      vim.api.nvim_win_set_cursor(0, { start_row, start_col })
    end
  )
end

---@return string[]
M.get_all_leaf_keys = function()
  local parser_name, ok = M.can_parse()
  if not ok then
    tools.error_treesitter 'parser'
    return {}
  end

  return vim.tbl_map(
    ---@param item Keysmith.NodeItem
    function(item) return item.key end,
    tools.get_all_leaf_nodes(parser_name)
  )
end

---@return string
M.get_key = function()
  local parser_name, ok = M.can_parse()
  if not ok then
    tools.error_treesitter 'parser'
    return ''
  end

  return tools.get_node(parser_name).key
end

---@return string
M.get_value = function()
  local parser_name, ok = M.can_parse()
  if not ok then
    tools.error_treesitter 'parser'
    return ''
  end

  return tools.get_node(parser_name).value
end

---@return string, boolean
M.can_parse = function()
  local buf_id = vim.api.nvim_get_current_buf()
  local has_ts_parser, ts_parser = pcall(vim.treesitter.get_parser, buf_id, nil, { error = false })
  if not has_ts_parser or ts_parser == nil then
    return '', false
  end

  local has_parser = pcall(require, 'keysmith.lang.' .. ts_parser:lang())
  if not has_parser then
    return '', false
  end

  return ts_parser:lang(), true
end

return M
