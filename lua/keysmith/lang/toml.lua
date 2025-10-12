local tools = require "keysmith.tools"
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
M.get_all_leaf_nodes_single = function(root, bufnr, prefix)
  prefix = prefix or ''

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

        for child in node:iter_children() do
          if child == key_node then
            goto continue
          end

          -- Traverse value node
          if child:type() == 'inline_table' then
            --prefixPrint('traversing ' .. new_path)
            traverse_node(child, new_path, depth + 1)
            --prefixPrint('=======2 ' .. type)
            --prefixPrint('p: ' .. new_path)
            goto continue
          end

          if vim.treesitter.get_node_text(child, 0) == '=' then
            goto continue
          end

          -- if the type of the value node is not a table, then it can only be the leaf
          local start_line, start_col = key_node:start()
          paths[new_path] = tools.new_keysmith_node_item(
            prefix .. new_path,
            vim.treesitter.get_node_text(child, 0),
            key_node,
            {
              bufnr = bufnr,
              lnum = start_line+1,
              col = start_col,
              valid = true,
              text = prefix .. new_path,
            }
          )

          ::continue::
        end

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

-- TODO: Figure out how to get the index of arrays
M.get_keysmith_node = function(opts)
  vim.treesitter.get_parser():parse()
  local node = vim.treesitter.get_node(opts)
  if not node then
    return nil
  end

  local key, value, target_node = nil, nil, nil
  while node do
    local type = node:type()

    if type == 'pair' then
      local key_node = extract_key_node(node)
      if key_node then
        local key_node_text = extract_key_text(key_node)

        if key == nil then
          key = key_node_text
        else
          key = key_node_text .. '.' .. key
        end

        if not target_node then
          target_node = node
        end

        if value then
          goto continue
        end

        for child in node:iter_children() do
          if child == key_node then
            goto continue
          end

          if vim.treesitter.get_node_text(child, 0) == '=' then
            goto continue
          end

          value = clean_key(vim.treesitter.get_node_text(child, 0))

          ::continue::
        end
      end

    elseif type == 'table_array_element'  then
      local key_node = extract_key_node(node)
      if key_node then
        local key_node_text = extract_key_text(key_node)

        if key == nil then
          key = key_node_text .. '[?]'
        else
          key = key_node_text .. '[?].' .. key
        end

        if not target_node then
          target_node = node
        end

        if value then
          goto continue
        end

        value = clean_key(vim.treesitter.get_node_text(node, 0))
      end

    elseif type == 'table' then
      local key_node = extract_key_node(node)
      if key_node then
        local key_node_text = extract_key_text(key_node)

        if key == nil then
          key = key_node_text
        else
          key = key_node_text .. '.' .. key
        end

        if not target_node then
          target_node = node
        end

        if value then
          goto continue
        end

        value = clean_key(vim.treesitter.get_node_text(node, 0))
      end
    end

    ::continue::
    node = node:parent()
  end

  if not target_node or not key or not value then
    return nil
  end

  local start_line, start_col = target_node:start()

  return tools.new_keysmith_node_item(
    key,
    value,
    target_node,
    {
    bufnr = (opts or {}).bufnr or vim.api.nvim_get_current_buf(),
    lnum = start_line+1,
    col = start_col,
    text = key,
    valid = true,
    }
  )

end

return M
