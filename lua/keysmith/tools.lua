local M = {}

---@param using_parser string
---@return Keysmith.NodeItem[] | nil
M.get_all_leaf_keysmith_nodes = function(using_parser)
  ---@type string
  local use_lang = require('keysmith.lang.' .. using_parser).use_lang
  local ok_parser, parser = pcall(vim.treesitter.get_parser, 0, use_lang)
  if not ok_parser or not parser then
    return nil
  end

  local trees = parser:parse()
  if not trees or #trees == 0 then
    return nil
  end

  ---@type Keysmith.NodeItem[]
  local roots = {}
  for _, child in ipairs(trees) do
    local root = child:root()
    table.insert(roots, root)
  end

  return require('keysmith.lang.' .. using_parser).get_all_leaf_keysmith_nodes(roots, vim.api.nvim_get_current_buf())
end

---@param using_parser string
---@return Keysmith.NodeItem | nil
M.get_keysmith_node = function(using_parser) return require('keysmith.lang.' .. using_parser).get_keysmith_node() end

---@param key string
---@param value string
---@param target_node TSNode
---@param qf_params vim.quickfix.entry
---@return Keysmith.NodeItem
M.new_keysmith_node_item = function(key, value, target_node, qf_params)
  return {
    key = key,
    value = value,
    target_node = target_node,

    --Snacks
    buf = qf_params.bufnr,
    pos = { qf_params.lnum, qf_params.col },
    valid = qf_params.valid,
    text = qf_params.text,

    --Telescope
    bufnr = qf_params.bufnr,
    lnum = qf_params.lnum,
    col = qf_params.col,
    text = qf_params.text,

    --Fzf lua
    bufnr = qf_params.bufnr,
    line = qf_params.line,
    col = qf_params.col,
    text = qf_params.text,
  }
end

return M
