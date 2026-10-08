P = function(v)
  print(vim.inspect(v))
  return v
end

RELOAD = function(...)
  return require('plenary.reload').reload_module(...)
end

R = function(name)
  RELOAD(name)
  return require(name)
end
-- copy current file path to clipboard
vim.api.nvim_create_user_command('Cppath', function()
  local path = vim.fn.expand '%:p'
  vim.fn.setreg('+', path)
  vim.notify('Copied "' .. path .. '" to the clipboard!')
end, { desc = 'copy current file path to clipboard' })
-- copy current file path relative to the working directory
vim.api.nvim_create_user_command('Cprelpath', function()
  local path = vim.fn.expand '%:p:.'
  vim.fn.setreg('+', path)
  vim.notify('Copied "' .. path .. '" to the clipboard!')
end, { desc = 'copy relative file path to clipboard' })
-- copy current name  to clipboard
vim.api.nvim_create_user_command('Cpfile', function()
  local path = vim.fn.expand '%:t'
  vim.fn.setreg('+', path)
  vim.notify('Copied "' .. path .. '" to the clipboard!')
end, { desc = 'copy current file name to clipboard' })
