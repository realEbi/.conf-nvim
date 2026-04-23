-- See `:help vim.opt`
-- NOTE: For more options, you can see `:help option-list`
local opt = vim.opt
-- Make line numbers default
opt.number = true
opt.relativenumber = true
-- You can also add relative line numbers, to help with jumping.
--  Experiment for yourself to see if you like it!
-- opt.relativenumber = true

-- Enable mouse mode, can be useful for resizing splits for example!
opt.mouse = 'a'

-- Don't show the mode, since it's already in the status line
opt.showmode = false

-- Sync clipboard between OS and Neovim.
--  Schedule the setting after `UiEnter` because it can increase startup-time.
--  Remove this option if you want your OS clipboard to remain independent.
--  See `:help 'clipboard'`
vim.schedule(function()
  vim.opt.clipboard = 'unnamedplus'
end)

-- Enable break indent
opt.breakindent = true
-- Autoindent same level
opt.autoindent = true
-- convert tabs to space
opt.expandtab = true
-- Use 4 spaces per indentation level
opt.shiftwidth = 4
-- Display tabs as 4 spaces
opt.tabstop = 4

opt.spelllang = { 'en' }
-- Enable 24-bit RGB colors in the terminal
opt.termguicolors = true

-- code folding using treesitter
-- Use expression-based folding
opt.foldmethod = 'expr'
-- Use Neovim's built-in Treesitter folding (the old nvim-treesitter
-- `nvim_treesitter#foldexpr()` was removed in the `main` branch rewrite).
opt.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
-- disable autofold
opt.foldenable = false

-- Save undo history
opt.undofile = true

-- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
opt.ignorecase = true
opt.smartcase = true

-- Keep signcolumn on by default
opt.signcolumn = 'yes'

-- Decrease update time
opt.updatetime = 250

-- Decrease mapped sequence wait time
-- Displays which-key popup sooner
opt.timeoutlen = 300

-- Configure how new splits should be opened
opt.splitright = true
opt.splitbelow = true

-- Sets how neovim will display certain whitespace characters in the editor.
--  See `:help 'list'`
--  and `:help 'listchars'`
opt.list = true
opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

-- Preview substitutions live, as you type!
opt.inccommand = 'split'

-- Show which line your cursor is on
opt.cursorline = true

-- Minimal number of screen lines to keep above and below the cursor.
opt.scrolloff = 10
