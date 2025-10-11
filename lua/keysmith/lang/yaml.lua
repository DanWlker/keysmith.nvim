---@type Keysmith.lang
local M = {}

---@param key string
local function clean_key(key) return key:gsub('^["\']', ''):gsub('["\']$', '') end

-- TODO: check if want to support all possible combinations of keys and values, not just leaves
-- TODO: change this to accept buf number or a root node to get all the child key value nodes
M.get_all_leaf_nodes = function()
  local ft = vim.bo.filetype
  local ok_parser, parser = pcall(vim.treesitter.get_parser, 0, ft)
  if not ok_parser or not parser then
    return nil
  end

  local trees = parser:parse()
  if not trees or not trees[1] then
    return nil
  end

  local tree = trees[1]
  local root = tree:root()
  if not root then
    return nil
  end

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

M.get_node = function()
  local ft = vim.bo.filetype
  local ok_parser, parser = pcall(vim.treesitter.get_parser, 0, ft)
  if not ok_parser or not parser then
    return nil
  end

  local trees = parser:parse()
  if not trees or not trees[1] then
    return nil
  end

  local node = vim.treesitter.get_node(nil)
  if not node then
    return nil
  end

  local key, value, target_node = nil, nil, nil
  local last_key_node = node
  while node do
    local type = node:type()

    if type == 'block_mapping_pair' or type == 'flow_pair' then
      local key_node = node:field('key')[1]
      if key_node then
        local node_text = clean_key(vim.treesitter.get_node_text(key_node, 0))
        if key == nil then
          key = node_text
        elseif string.sub(key, 1, 1) == '[' then
          key = node_text .. (key or '')
        else
          key = node_text .. '.' .. (key or '')
        end

        if not value then
          local value_node = node:field('value')[1]
          if value_node then
            value = clean_key(vim.treesitter.get_node_text(value_node, 0))
          end
        end

        if not target_node then
          target_node = node
        end

        last_key_node = node
      end
    elseif type == 'block_sequence' or type == 'flow_sequence' then
      local counter = 1
      for child in node:iter_children() do
        local desc = child:child_with_descendant(last_key_node)
        if desc then
          break
        end
        counter = counter + 1
      end

      local node_text = '[' .. counter .. ']'
      if key == nil then
        key = node_text
      else
        key = node_text .. '.' .. (key or '')
      end
    end

    node = node:parent()
  end

  if not target_node or not key or not value then
    return nil
  end

  ---@type Keysmith.NodeItem
  return {
    key = key,
    value = value,
    target_node = target_node,
  }
end

return M
