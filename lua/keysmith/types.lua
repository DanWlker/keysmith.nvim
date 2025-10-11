---@class Keysmith.Config

---@class Keysmith.NodeItem
---@field key string
---@field value string
---@field target_node TSNode -- To be used when jumping

---@class Keysmith.lang
---@field get_all_leaf_keysmith_nodes fun(root: TSNode): Keysmith.NodeItem[] | nil
---@field get_leaf_keysmith_node fun(opts: vim.treesitter.get_node.Opts|nil): Keysmith.NodeItem[] | nil
