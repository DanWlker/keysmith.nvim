local tools = require 'keysmith.tools'
---@type Keysmith.lang
local M = {}

M.get_all_leaf_keysmith_nodes = function(roots, bufnr)
  if #roots == 1 then
    return M.get_all_leaf_nodes_single(roots[1], bufnr)
  end

  ---@type Keysmith.NodeItem[]
  local res = {}
  for i, root in ipairs(roots) do
    vim.tbl_extend('error', res, M.get_all_leaf_nodes_single(root, bufnr, '[' .. i .. '].'))
  end

  return res
end

---@param key string
local function clean_key(key) return key:gsub('^["\']', ''):gsub('["\']$', '') end

-- TODO: check if want to support all possible combinations of keys and values, not just leaves
M.get_all_leaf_nodes_single = function(root, bufnr, prefix)
  prefix = prefix or ''

  ---@type table<boolean, Keysmith.NodeItem>
  local paths = {}

  ---@param node TSNode
  ---@param current_path string
  ---@param current_path_key_node TSNode
  ---@param depth number
  local function traverse_node(node, current_path, current_path_key_node, current_path_value_node, depth)
    local type = node:type()
    local prefixPrint = function(text) print(string.rep(' ', depth) .. text) end

    prefixPrint('type ' .. type)

    -- Handle object properties
    if type == 'block_mapping_pair' or type == 'flow_pair' then
      local key_node = node:field('key')[1]
      if key_node then
        local key = clean_key(vim.treesitter.get_node_text(key_node, 0))
        local new_path = current_path .. '.' .. key

        -- Traverse value node
        local value_node = node:field('value')[1]
        if value_node then
          prefixPrint('traversing ' .. new_path)
          traverse_node(value_node, new_path, key_node, current_path_value_node, depth + 1)
          prefixPrint('=======2 ' .. type)
          prefixPrint('p: ' .. new_path)
          return
        end
      end
    -- Handle array items
    elseif type == 'block_sequence' or type == 'flow_sequence' or type == 'stream' then
      ---@type TSNode
      local valid_children = {}
      for child in node:iter_children() do
        if child:type() == 'comment' then
          goto continue
        end

        table.insert(valid_children, child)

        ::continue::
      end

      for index, child in ipairs(valid_children) do
        local new_path = current_path .. '[' .. index .. ']'

        if type == 'stream' and #valid_children == 1 then
          new_path = current_path
        end

        prefixPrint('traversing ' .. new_path)
        traverse_node(child, new_path, child, current_path_value_node, depth + 1)
        prefixPrint('=======3 ' .. type)
        prefixPrint('p: ' .. new_path)
      end
    -- Handle other stuff
    else
      -- leaf node
      if node:child_count() == 0 then
        local start_line, start_col = current_path_key_node:start()
        paths[current_path] =
          tools.new_keysmith_node_item(prefix .. current_path, vim.treesitter.get_node_text(current_path_value_node, 0), current_path_key_node, {
            buf = bufnr,
            lnum = start_line + 1,
            col = start_col,
            text = prefix .. current_path,
            valid = true,
          })
        return
      end

      for child in node:iter_children() do
        prefixPrint('traversing ' .. current_path)
        traverse_node(child, current_path, current_path_key_node, current_path_value_node, depth + 1)
        prefixPrint('=======4 ' .. type)
        prefixPrint('p: ' .. current_path)
      end
    end
  end

  traverse_node(root, '', root, root, 0)

  ---@type Keysmith.NodeItem[]
  local res = {}
  for _, value in pairs(paths) do
    table.insert(res, value)
  end

  return res
end

M.get_keysmith_node = function(opts)
  vim.treesitter.get_parser():parse()
  local node = vim.treesitter.get_node(opts)
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
        local key_node_text = clean_key(vim.treesitter.get_node_text(key_node, 0))
        if key == nil then
          key = key_node_text
        elseif string.sub(key, 1, 1) == '[' then
          key = key_node_text .. (key or '')
        else
          key = key_node_text .. '.' .. (key or '')
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
        if child:equal(last_key_node) then
          break
        end

        local desc = child:child_with_descendant(last_key_node)
        if desc then
          break
        end
        counter = counter + 1
      end

      local key_node_text = '[' .. counter .. ']'
      if key == nil then
        key = key_node_text
      else
        key = key_node_text .. '.' .. (key or '')
      end
    end

    node = node:parent()
  end

  if not target_node or not key or not value then
    return nil
  end

  local start_line, start_col = target_node:start()

  ---@type Keysmith.NodeItem
  return tools.new_keysmith_node_item(key, value, target_node, {
    bufnr = (opts or {}).bufnr or vim.api.nvim_get_current_buf(),
    lnum = start_line + 1,
    col = start_col,
    text = key,
    valid = true,
  })
end

return M
