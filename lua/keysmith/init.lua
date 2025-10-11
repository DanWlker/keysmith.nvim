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

-- TODO: support custom actions for function(item) so that users can maybe copy the value to their clipboard
M.select_all_keys = function()
  local parser_name, ok = M.can_parse()
  if not ok then
    tools.error_treesitter 'parser'
    return
  end

  -- TODO: Support quickfix list
  vim.ui.select(
    tools.get_all_leaf_keysmith_nodes(parser_name) or {},
    {
      prompt = 'Keysmith',
      ---@param item Keysmith.NodeItem
      format_item = function(item) return item.key end,
    },
    ---@param item Keysmith.NodeItem
    function(item)
      if item then
        local start_row, start_col = item.target_node:start()
        vim.api.nvim_win_set_cursor(0, { start_row + 1, start_col })
      end
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
    tools.get_all_leaf_keysmith_nodes(parser_name) or {}
  )
end

---@return string
M.get_key = function()
  local parser_name, ok = M.can_parse()
  if not ok then
    tools.error_treesitter 'parser'
    return ''
  end

  local node = tools.get_leaf_keysmith_node(parser_name)
  if not node then
    return ''
  end

  return node.key
end

---@return string
M.get_value = function()
  local parser_name, ok = M.can_parse()
  if not ok then
    tools.error_treesitter 'parser'
    return ''
  end

  local node = tools.get_leaf_keysmith_node(parser_name)
  if not node then
    return ''
  end

  return node.value
end

---@return string, boolean
M.can_parse = function()
  local buf_id = vim.api.nvim_get_current_buf()
  local has_ts_parser, ts_parser = pcall(vim.treesitter.get_parser, buf_id, nil, { error = false })
  if not has_ts_parser or ts_parser == nil then
    return '', false
  end

  if not ts_parser:parse() then
    return '', false
  end

  local lang = ts_parser:lang()
  local has_parser = pcall(require, 'keysmith.lang.' .. lang)
  if not has_parser then
    return '', false
  end

  return lang, true
end

return M
