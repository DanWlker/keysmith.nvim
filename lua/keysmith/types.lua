---@class Keysmith.Config

---@class QuickfixEntryHelper
---Snacks
---@field buf number
---@field pos snacks.picker.Pos
---@field valid boolean
---@field text string
---
---Telescope
--- TODO: fill this
---
---Fzf lua
--- TODO: fill this

---@class Keysmith.NodeItem: QuickfixEntryHelper
---@field key string
---@field value string
---@field target_node TSNode -- To be used when jumping

---@class Keysmith.lang
---@field get_all_leaf_keysmith_nodes fun(root: TSNode, bufnr: number): Keysmith.NodeItem[] | nil
---@field get_keysmith_node fun(opts: vim.treesitter.get_node.Opts|nil): Keysmith.NodeItem[] | nil
