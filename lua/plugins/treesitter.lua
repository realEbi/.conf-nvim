-- Highlight, edit, and navigate code
-- Uses the `main` branch of nvim-treesitter, which is required for Neovim 0.12+.
-- The old `master` branch is frozen and does not support Neovim 0.12.
return {
  {
    'nvim-treesitter/nvim-treesitter',
    branch = 'main',
    lazy = false,
    build = ':TSUpdate',
    config = function()
      require('nvim-treesitter').setup {
        install_dir = vim.fn.stdpath 'data' .. '/site',
      }

      local parsers = {
        'bash',
        'c',
        'diff',
        'html',
        'lua',
        'luadoc',
        'markdown',
        'markdown_inline',
        'query',
        'vim',
        'vimdoc',
        'python',
        'json',
        'yaml',
        'toml',
        'go',
        'sql',
      }

      require('nvim-treesitter').install(parsers)

      -- Filetypes for which treesitter highlighting/folding/indent should be enabled.
      -- Note: these are Neovim filetype names (not parser names).
      local filetypes = {
        'bash',
        'sh',
        'zsh',
        'c',
        'diff',
        'html',
        'lua',
        'luadoc',
        'markdown',
        'query',
        'vim',
        'help',
        'python',
        'json',
        'yaml',
        'toml',
        'go',
        'sql',
      }

      vim.api.nvim_create_autocmd('FileType', {
        pattern = filetypes,
        callback = function(args)
          pcall(vim.treesitter.start, args.buf)
          vim.wo[0][0].foldexpr = 'v:lua.vim.treesitter.foldexpr()'
          vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end,
      })
    end,
  },
}
