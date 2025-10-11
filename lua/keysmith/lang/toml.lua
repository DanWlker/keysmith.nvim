---@type Keysmith.lang
local M = {}

---@param key string
local function clean_key(key) return key:gsub('^["\']', ''):gsub('["\']$', '') end

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

-- TODO: check if want to support all possible combinations of keys and values, not just leaves
M.get_all_leaf_keysmith_nodes = function(root, bufnr)
  ---@type table<boolean, Keysmith.NodeItem>
  local paths = {}
  ---@type table<string, number>
  local arrayIndexCounter = {}

  ---@param node TSNode
  ---@param current_path string
  ---@param depth number
  local function traverse_node(node, current_path, depth)
    local type = node:type()
    -- local prefixPrint = function(text) print(string.rep(' ', depth) .. text) end

    --prefixPrint('type ' .. type)

    if type == 'comment' then
      return
    end

    -- Handle object properties
    if type == 'pair' then
      local key_node = extract_key_node(node)
      if key_node then
        local key = extract_key_text(key_node)
        --prefixPrint('k: ' .. key)

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
          --prefixPrint('traversing ' .. new_path)
          traverse_node(value_node, new_path, depth + 1)
          --prefixPrint('=======2 ' .. type)
          --prefixPrint('p: ' .. new_path)
          return
        end

        -- if the type of the value node is not a table, then it can only be the leaf
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
      if key_node then
        local key = extract_key_text(key_node)
        --prefixPrint('k: ' .. key)

        local new_path
        if current_path == '' then
          new_path = key
        else
          new_path = current_path .. '.' .. key
        end

        local index = arrayIndexCounter[new_path] or 0
        --prefixPrint('a: ' .. index)
        arrayIndexCounter[new_path] = index + 1

        for child in node:iter_children() do
          if child:equal(key_node) then
            goto continue
          end

          local array_path = new_path .. '[' .. index .. ']'
          --prefixPrint('traversing ' .. new_path)
          traverse_node(child, array_path, depth + 1)
          --prefixPrint('=======3 ' .. type)
          --prefixPrint('p: ' .. new_path)
          ::continue::
        end
      end
    -- Handle other stuff
    elseif type == 'table' then
      local key_node = extract_key_node(node)
      if key_node then
        local key = extract_key_text(key_node)
        --prefixPrint('k: ' .. key)

        local new_path
        if current_path == '' then
          new_path = key
        else
          new_path = current_path .. '.' .. key
        end

        for child in node:iter_children() do
          if child:equal(key_node) then
            goto continue
          end

          traverse_node(child, new_path, depth + 1)

          ::continue::
        end
      end
    else
      if node:child_count() ~= 0 then
        for child in node:iter_children() do
          --prefixPrint('traversing ' .. current_path)
          traverse_node(child, current_path, depth + 1)
          --prefixPrint('=======4 ' .. type)
          --prefixPrint('p: ' .. current_path)
        end
      end
    end
  end

  traverse_node(root, '', 0)

  ---@type Keysmith.NodeItem[]
  local res = {}
  for _, value in pairs(paths) do
    table.insert(res, value)
  end

  return res
end

M.get_keysmith_node = function(opts) end

return M
