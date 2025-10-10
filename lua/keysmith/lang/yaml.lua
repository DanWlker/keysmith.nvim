---@type Keysmith.lang
local M = {}

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

  ---@type string[]
  local paths = {}

  ---@param node TSNode
  ---@param current_path string
  -- local function traverse_node(node, current_path)
  --   local type = node:type()
  --
  --   if type == 'stream' or type == 'document' or type == 'block_node' then
  --     for child in node:iter_children() do
  --       traverse_node(child, current_path)
  --     end
  --     return
  --   end
  --
  --   -- Handle object properties
  --   if type == 'pair' or type == 'block_mapping_pair' or type == 'flow_mapping_pair' then
  --     local key_node = node:field('key')[1]
  --     if key_node then
  --       local key = clean_key(vim.treesitter.get_node_text(key_node, 0))
  --       local new_path = current_path .. '.' .. key
  --       table.insert(paths, new_path)
  --
  --       -- Traverse value node
  --       local value_node = node:field('value')[1]
  --       if value_node then
  --         traverse_node(value_node, new_path)
  --       end
  --     end
  --     -- Handle array items
  --   elseif type == 'block_sequence_item' or type == 'flow_sequence_item' then
  --     local parent = node:parent()
  --     if parent then
  --       local index = 0
  --       for child in parent:iter_children() do
  --         if child == node then
  --           break
  --         end
  --         if child:type() == type then
  --           index = index + 1
  --         end
  --       end
  --       local new_path = current_path .. '[' .. index .. ']'
  --       table.insert(paths, new_path) -- TODO: this gets all intermediate keys, should get only leaf
  --
  --       -- Traverse array item content
  --       for child in node:iter_children() do
  --         traverse_node(child, new_path)
  --       end
  --     end
  --     -- Handle block mappings and sequences
  --   elseif type == 'block_mapping' or type == 'flow_mapping' or type == 'block_sequence' or type == 'flow_sequence' then
  --     for child in node:iter_children() do
  --       traverse_node(child, current_path)
  --     end
  --   end
  -- end

  ---@param node TSNode
  ---@param current_path string
  ---@return string
  local function traverse_node(node, current_path, depth)
    local type = node:type()
    local prefixPrint = function(text) print(string.rep(' ', depth) .. text) end

    prefixPrint('type ' .. type)

    -- Handle object properties
    if type == 'pair' or type == 'block_mapping_pair' or type == 'flow_mapping_pair' then
      local key_node = node:field('key')[1]
      if key_node then
        local key = clean_key(vim.treesitter.get_node_text(key_node, 0))
        local new_path = current_path .. '.' .. key

        -- Traverse value node
        local value_node = node:field('value')[1]
        if value_node then
          prefixPrint('traversing ' .. new_path)
          local leaf_key = traverse_node(value_node, new_path, depth + 1)
          prefixPrint('=======2 ' .. type)
          prefixPrint('p: ' .. new_path)
          prefixPrint(leaf_key)
          if leaf_key ~= '' then
            table.insert(paths, new_path .. '.' .. leaf_key)
            return ''
          end
          return key
        end
      end
    -- Handle array items
    elseif type == 'block_sequence' or type == 'flow_sequence' then
      local index = 0
      for child in node:iter_children() do
        local new_path = current_path .. '[' .. index .. ']'
        index = index + 1

        prefixPrint('traversing ' .. new_path)
        local leaf_key = traverse_node(child, new_path, depth + 1)
        prefixPrint('=======3 ' .. type)
        prefixPrint('p: ' .. new_path)
        prefixPrint(leaf_key)
        if leaf_key ~= '' then
          table.insert(paths, new_path .. '.' .. leaf_key)
        end
      end
    -- Handle other stuff
    else
      for child in node:iter_children() do
        prefixPrint('traversing ' .. current_path)
        local leaf_key = traverse_node(child, current_path, depth + 1)
        prefixPrint('=======4 ' .. type)
        prefixPrint('p: ' .. current_path)
        prefixPrint(leaf_key)
        if leaf_key ~= '' then
          table.insert(paths, current_path .. '.' .. leaf_key)
        end
      end
    end
    return ''
  end

  traverse_node(root, '', 0)
  print(vim.inspect(paths))
  return paths
end

M.get_node = function() end

return M
