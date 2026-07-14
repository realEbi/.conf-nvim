local save_dir = vim.fn.expand '~/Pictures/Codesnap'

vim.keymap.set('v', '<leader>zsc', vim.cmd.CodeSnap, { desc = 'Code snapshot to clipboard' })
vim.keymap.set('v', '<leader>zss', function()
  vim.fn.mkdir(save_dir, 'p')
  vim.cmd.CodeSnapSave(save_dir .. '/' .. os.date '%Y%m%d-%H%M%S' .. '.png')
end, { desc = 'Code snapshot save' })

return {
  'mistricky/codesnap.nvim',
  config = function()
    require('codesnap').setup {
      border = 'rounded',
      has_breadcrumbs = true,
      bg_theme = 'grape',
      watermark = '',
    }
  end,
}
