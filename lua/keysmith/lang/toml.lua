---@type Keysmith.lang
local M = {}

---@param key string
local function clean_key(key) return key:gsub('^["\']', ''):gsub('["\']$', '') end

-- TODO: check if want to support all possible combinations of keys and values, not just leaves
M.get_all_leaf_keysmith_nodes = function(root, bufnr)
  ---@type table<boolean, Keysmith.NodeItem>
  local paths = {}
  local arrayIndexCounter = {}

  ---@param node TSNode
  ---@param current_path string
  ---@param current_path_target_node TSNode
  ---@param depth number
  local function traverse_node(node, current_path, current_path_target_node, depth)
    local type = node:type()
    local prefixPrint = function(text) print(string.rep(' ', depth) .. text) end

    prefixPrint('type ' .. type)

    ---@param curr_node TSNode
    local function extract_key_node(curr_node)
      local fields = { bare_key = true, quoted_key = true, dotted_key = true }
      for child in curr_node:iter_children() do
        if fields[child:type()] then
          return child
        end
      end
      return nil
    end

    ---@param key_node TSNode
    local function extract_key_text(key_node)
      if key_node:type() ~= 'dotted_key' then
        return clean_key(vim.treesitter.get_node_text(key_node, 0))
      end

      local full_key = ''
      for sub_key in key_node:iter_children() do
        local extracted_sub_key = extract_key_text(sub_key)
        if extracted_sub_key == '.' then
          goto continue
        end

        if full_key == '' then
          full_key = extract_key_text(sub_key)
        else
          full_key = full_key .. '.' .. extract_key_text(sub_key)
        end
        ::continue::
      end

      return full_key
    end

    -- Handle object properties
    if type == 'pair' then
      local key_node = extract_key_node(node)
      print(key_node)
      if key_node then
        local key = extract_key_text(key_node)
        prefixPrint('k: ' .. key)

        local new_path
        if current_path == '' then
          new_path = key
        else
          new_path = current_path .. '.' .. key
        end

        local value_node = key_node:next_sibling()
        if not value_node then
          return
        end

        -- Traverse value node
        if value_node:type() == 'inline_table' then
          prefixPrint('traversing ' .. new_path)
          traverse_node(value_node, new_path, key_node, depth + 1)
          prefixPrint('=======2 ' .. type)
          prefixPrint('p: ' .. new_path)
          return
        end

        local start_line, start_col = key_node:start()
        paths[new_path] = {
          key = new_path,
          target_node = key_node,

          buf = bufnr,
          pos = { start_line + 1, start_col },
          text = new_path,
          valid = true,
        }
        return
      end

    -- Handle array items
    elseif type == 'table_array_element' then
      local key_node = extract_key_node(node)
      print(key_node)
      if key_node then
        local key = extract_key_text(key_node)
        prefixPrint('k: ' .. key)

        local new_path
        if current_path == '' then
          new_path = key
        else
          new_path = current_path .. '.' .. key
        end

        local index = arrayIndexCounter[new_path] or 0
        arrayIndexCounter[new_path] = index + 1

        for child in node:iter_children() do
          if child:equal(key_node) or child:type() == 'comment' then
            goto continue
          end

          local array_path = current_path .. '[' .. index .. ']'
          prefixPrint('traversing ' .. new_path)
          traverse_node(child, array_path, child, depth + 1)
          prefixPrint('=======3 ' .. type)
          prefixPrint('p: ' .. new_path)
          ::continue::
        end
      end
    -- Handle other stuff
    elseif type == 'table' then
      local key_node = extract_key_node(node)
      print(key_node)
      if key_node then
        local key = extract_key_text(key_node)
        prefixPrint('k: ' .. key)

        local new_path
        if current_path == '' then
          new_path = key
        else
          new_path = current_path .. '.' .. key
        end

        for child in node:iter_children() do
          if child:equal(key_node) or child:type() == 'comment' then
            goto continue
          end

          traverse_node(child, new_path, child, depth + 1)

          ::continue::
        end
      end
    else
      if node:child_count() ~= 0 then
        for child in node:iter_children() do
          --prefixPrint('traversing ' .. current_path)
          traverse_node(child, current_path, current_path_target_node, depth + 1)
          --prefixPrint('=======4 ' .. type)
          --prefixPrint('p: ' .. current_path)
        end
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
        if child:equal(last_key_node) then
          break
        end

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

  local start_line, start_col = target_node:start()

  ---@type Keysmith.NodeItem
  return {
    key = key,
    value = value,
    target_node = target_node,

    buf = (opts or {}).bufnr or vim.api.nvim_get_current_buf(),
    pos = { start_line + 1, start_col },
    text = key,
    valid = true,
  }
end

return M
