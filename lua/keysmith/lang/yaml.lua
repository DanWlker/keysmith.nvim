---@type Keysmith.lang
local M = {}

-- TODO: check if want to support all possible combinations of keys and values
--
---@return Keysmith.NodeItem[]
M.get_all_leaf_nodes = function()
  local ft = vim.bo.filetype
  local ok_parser, parser = pcall(vim.treesitter.get_parser, 0, ft)
  if not ok_parser or not parser then
    return {}
  end

  local trees = parser:parse()
  if not trees or not trees[1] then
    return {}
  end

  local tree = trees[1]
  local root = tree:root()
  if not root then
    return {}
  end

  ---@return string
  local function clean_key(key) return key:gsub('^["\']', ''):gsub('["\']$', '') end

  ---@type table<boolean, Keysmith.NodeItem>
  local paths = {}

  ---@param node TSNode
  ---@param current_path string
  ---@param current_path_target_node TSNode
  ---@param depth number
  local function traverse_node(node, current_path, current_path_target_node, depth)
    local type = node:type()
    --local prefixPrint = function(text) print(string.rep(' ', depth) .. text) end

    --prefixPrint('type ' .. type)

    -- Handle object properties
    if type == 'block_mapping_pair' or type == 'flow_pair' then
      local key_node = node:field('key')[1]
      if key_node then
        local key = clean_key(vim.treesitter.get_node_text(key_node, 0))
        local new_path = current_path .. '.' .. key

        -- Traverse value node
        local value_node = node:field('value')[1]
        if value_node then
          --prefixPrint('traversing ' .. new_path)
          traverse_node(value_node, new_path, key_node, depth + 1)
          --prefixPrint('=======2 ' .. type)
          --prefixPrint('p: ' .. new_path)
          return
        end
      end
    -- Handle array items
    elseif type == 'block_sequence' or type == 'flow_sequence' then
      local index = 0
      for child in node:iter_children() do
        local new_path = current_path .. '[' .. index .. ']'
        index = index + 1

        --prefixPrint('traversing ' .. new_path)
        traverse_node(child, new_path, current_path_target_node, depth + 1)
        --prefixPrint('=======3 ' .. type)
        --prefixPrint('p: ' .. new_path)
      end
    -- Handle other stuff
    else
      -- leaf node
      if node:child_count() == 0 then
        paths[current_path] = {
          key = current_path,
          target_node = current_path_target_node,
        }
        return
      end

      for child in node:iter_children() do
        --prefixPrint('traversing ' .. current_path)
        traverse_node(child, current_path, current_path_target_node, depth + 1)
        --prefixPrint('=======4 ' .. type)
        --prefixPrint('p: ' .. current_path)
      end
    end
  end

  traverse_node(root, '', root, 0)

  ---@type Keysmith.NodeItem[]
  local res = {}
  for _, value in pairs(paths) do
    table.insert(res, value)
  end

  return res
end

M.get_node = function() end

return M
