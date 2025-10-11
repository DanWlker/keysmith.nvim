---@class Keysmith.Config

---@class Keysmith.NodeItem
---@field key string
---@field value string
---@field target_node TSNode -- To be used when jumping

---@class Keysmith.lang
---@field get_all_leaf_nodes fun(): Keysmith.NodeItem[] | nil
---@field get_node fun(): Keysmith.NodeItem[] | nil
