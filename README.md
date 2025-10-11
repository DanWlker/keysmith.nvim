# keysmith.nvim

A neovim helper for data/config languages like Json, Yaml, Toml etc.

![demo](https://github.com/DanWlker/keysmith.nvim/blob/main/demo.gif)

## Installation

### Lazy.nvim

```lua
return {
  'DanWlker/keysmith.nvim',
  config = true,
}
```

## Usage

1. Search all keys in the current file. Note: select_all_keys accept the same params as `vim.ui.select`, so you can override the `on_choice` or `opts` passed

```lua
vim.api.nvim_create_autocmd('BufWinEnter', {
  pattern = { '*.yaml', '*.yml', '*.json' },
  group = vim.api.nvim_create_augroup('danwlker/keysmith', { clear = true }),
  callback = function() vim.keymap.set('n', '<leader>f/', require('keysmith').select_all_keys) end,
})
```

1. Copy / Get the key under your cursor

```lua
keys = {
    {
        'yk',
        function() vim.fn.setreg('+', require('keysmith').get_key()) end,
        desc = 'Copy key under cursor',
    },
    {
        'yv',
        function() vim.fn.setreg('+', require('keysmith').get_value()) end,
        desc = 'Copy key under cursor',
    },
},
```
