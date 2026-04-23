# Migrating nvim-treesitter to Neovim 0.12

This document records two related breakages that appeared after upgrading to
Neovim 0.12.1, and the steps taken to fix them. Both have the same root
cause: the `master` branch of `nvim-treesitter` was frozen and a complete
rewrite landed on the `main` branch with a different API and different
runtime requirements.

## The problems

### 1. Markdown file open crashes the treesitter highlighter

Whenever a markdown file was opened, the following error appeared:

```
Decoration provider "start" (ns=nvim.treesitter.highlighter):
Lua: .../neovim/0.12.1/share/nvim/runtime/lua/vim/treesitter/languagetree.lua:215:
.../neovim/0.12.1/share/nvim/runtime/lua/vim/treesitter.lua:196:
attempt to call method 'range' (a nil value)
```

### 2. Telescope preview crashes on any file

After migrating to the new branch (see fix below), opening any Telescope
picker with a preview produced:

```
vim.schedule callback: ...telescope/previewers/utils.lua:135:
attempt to call field 'ft_to_lang' (a nil value)
stack traceback:
  ...telescope/previewers/utils.lua:135: in function 'ts_highlighter'
  ...telescope/previewers/utils.lua:119: in function 'highlighter'
  ...telescope/previewers/buffer_previewer.lua:247: in function ''
```

### Shared root cause

- Neovim version installed: **0.12.1**.
- `nvim-treesitter` was pinned to its **`master`** branch (commit `cf12346a`).
- The `master` branch is **frozen** and explicitly supports only Neovim 0.10
  / 0.11 — its README states:
  > Neovim 0.10 or 0.11 (Neovim 0.12 is **not supported**).
- The `markdown` / `markdown_inline` queries shipped on that frozen branch
  use patterns that are incompatible with Neovim 0.12's treesitter API,
  which is why `node:range` ends up being called on a `nil` value.
- Fixing the markdown crash required migrating to the **`main`** branch —
  a complete rewrite with a different configuration API.
- That rewrite also removed several legacy helper functions (`parsers.ft_to_lang`,
  `parsers.get_parser`, `configs.is_enabled`, …) that third-party plugins
  such as `telescope.nvim` still call. Those plugins have not yet been
  updated, so we need a small compatibility shim on our side.

## The fix

### 1. Rewrite `lua/plugins/treesitter.lua` for the `main` branch

The old `main = 'nvim-treesitter.configs'` + `opts = { ensure_installed, highlight, indent }`
shape no longer exists. On the `main` branch:

- Pin `branch = 'main'`.
- Disable lazy-loading (`lazy = false`) — the new plugin does not support it.
- Install parsers with `require('nvim-treesitter').install(...)`.
- Enable highlighting, folding, and indentation per filetype via a
  `FileType` autocmd using the built-in `vim.treesitter.*` API.

The new file:

```lua
-- Highlight, edit, and navigate code
-- Uses the `main` branch of nvim-treesitter, required for Neovim 0.12+.
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
        'bash', 'c', 'diff', 'html', 'lua', 'luadoc',
        'markdown', 'markdown_inline', 'query', 'vim', 'vimdoc',
        'python', 'json', 'yaml', 'toml', 'go', 'sql',
      }

      require('nvim-treesitter').install(parsers)

      local filetypes = {
        'bash', 'sh', 'zsh', 'c', 'diff', 'html', 'lua', 'luadoc',
        'markdown', 'query', 'vim', 'help',
        'python', 'json', 'yaml', 'toml', 'go', 'sql',
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
```

### 2. Fix `lua/core/options.lua`

The legacy function `nvim_treesitter#foldexpr()` was removed in the `main`
branch rewrite. Replace it with Neovim's built-in `vim.treesitter.foldexpr()`:

```lua
-- before
opt.foldexpr = 'nvim_treesitter#foldexpr()'

-- after
opt.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
```

### 3. Install the `tree-sitter` CLI

After the first restart with the new config, Neovim showed:

```
[nvim-treesitter/install/<lang>] error: Error during "tree-sitter build":
ENOENT: no such file or directory (cmd): 'tree-sitter'
```

The `main` branch delegates parser compilation to the official `tree-sitter`
CLI (the old `master` branch didn't). Per the plugin's README, it must be
installed via a system package manager (not npm):

```sh
brew install tree-sitter-cli
```

Verified with:

```sh
$ tree-sitter --version
tree-sitter 0.26.8
```

(`main` requires 0.26.1 or later.)

### 4. Patch Telescope's previewer for the new API

#### Why the error happens

Telescope's buffer previewer tries to attach a treesitter highlighter to the
preview buffer in
[`telescope/previewers/utils.lua`](https://github.com/nvim-telescope/telescope.nvim/blob/0.1.x/lua/telescope/previewers/utils.lua).
The relevant code on the `0.1.x` branch (paraphrased) is:

```lua
local _, ts_configs = pcall(require, 'nvim-treesitter.configs')
local _, ts_parsers = pcall(require, 'nvim-treesitter.parsers')

local treesitter_attach = function(bufnr, ft)
  local lang = ts_parsers.ft_to_lang(ft)            -- (a)
  if not ts_configs.is_enabled('highlight', lang, bufnr) then  -- (b)
    return false
  end
  vim.treesitter.highlighter.new(ts_parsers.get_parser(bufnr, lang)) -- (c)
  ...
end
```

All three calls, `(a)` `ft_to_lang`, `(b)` `is_enabled`, and `(c)`
`get_parser`, are helpers that only existed on the frozen `master` branch.
On the `main` branch, `nvim-treesitter.parsers` is now a plain table of
parser metadata (no helper functions), and `nvim-treesitter.configs` was
removed entirely. `pcall(require, 'nvim-treesitter.parsers')` still
succeeds, but the returned module no longer has an `ft_to_lang` field, so
`ts_parsers.ft_to_lang(ft)` throws
`attempt to call field 'ft_to_lang' (a nil value)`.

Telescope has not yet been updated for the new API, so we need a local
shim. Neovim 0.12 already ships equivalent functionality as part of its
built-in treesitter module:

| Telescope call                               | Built-in replacement                     |
| -------------------------------------------- | ---------------------------------------- |
| `ts_parsers.ft_to_lang(ft)`                  | `vim.treesitter.language.get_lang(ft)`   |
| `ts_parsers.get_parser(bufnr, lang)`         | handled internally by `vim.treesitter.start` |
| `ts_configs.is_enabled('highlight', ...)`    | not needed — we decide via our own opts  |
| `vim.treesitter.highlighter.new(parser)`     | `vim.treesitter.start(bufnr, lang)`      |

#### How the fix works

Rather than patching telescope's source, we override its public
`ts_highlighter` entry point with a version that uses the built-in API.
`utils.ts_highlighter` is called from `utils.highlighter`, which falls back
to the regex highlighter whenever `ts_highlighter` returns `false`, so if
the parser is not available we automatically get a sensible fallback
instead of a crash.

Add this inside `config = function()` of `lua/plugins/telescope.lua`, after
`require('telescope').setup { ... }`:

```lua
do
  local ok, previewer_utils = pcall(require, 'telescope.previewers.utils')
  if ok then
    previewer_utils.ts_highlighter = function(bufnr, ft)
      local lang = vim.treesitter.language.get_lang(ft) or ft
      local started = pcall(vim.treesitter.start, bufnr, lang)
      return started
    end
  end
end
```

What it does, line by line:

1. `pcall(require, 'telescope.previewers.utils')` — safely load the module;
   if Telescope is not installed this is a no-op.
2. `vim.treesitter.language.get_lang(ft)` — map a Neovim filetype (e.g.
   `help`) to a parser language (e.g. `vimdoc`). Falls back to `ft` when
   no explicit mapping is registered.
3. `pcall(vim.treesitter.start, bufnr, lang)` — attach the built-in
   treesitter highlighter to the preview buffer. `start` locates the
   parser, creates the language tree, and registers the highlighter; no
   manual plumbing through `parsers.get_parser` is needed.
4. Return `true` on success so `utils.highlighter` keeps the treesitter
   result; return `false` when no parser is installed so Telescope falls
   back to regex-based syntax highlighting.

This shim is small, isolated, and can be removed once Telescope upstream
adopts the `main` branch API.

### 5. Sync and update parsers

Inside Neovim:

```vim
:Lazy sync
:TSUpdate
```

Then restart Neovim. Opening a markdown file no longer triggers the
`range` crash, and Telescope previews render without the `ft_to_lang`
error.

## Summary of changes

| File                              | Change                                                                 |
| --------------------------------- | ---------------------------------------------------------------------- |
| `lua/plugins/treesitter.lua`      | Rewrote for the `main` branch API (install + FileType autocmd)         |
| `lua/core/options.lua`            | Switched `foldexpr` from `nvim_treesitter#foldexpr()` to `v:lua.vim.treesitter.foldexpr()` |
| `lua/plugins/telescope.lua`       | Overrode `previewers.utils.ts_highlighter` to use `vim.treesitter.start()` |
| System (Homebrew)                 | Installed `tree-sitter-cli` (required by the new `main` branch)         |

## Notes for the future

- `auto_install` no longer exists on the `main` branch — add any new
  language to both the `parsers` list (for installation) and the
  `filetypes` list (for the autocmd) in `lua/plugins/treesitter.lua`.
- `additional_vim_regex_highlighting` is gone; to keep vim regex
  highlighting for a filetype, just leave it out of the `filetypes` list.
- The new plugin does not support lazy-loading; keep `lazy = false`.
- Neovim's support policy on the `main` branch is the latest stable and
  the latest nightly, so staying reasonably up-to-date with Neovim is
  expected.
- The Telescope shim in section 4 is temporary. Once
  `telescope.nvim` ships support for the `main` branch API, the `do ...
  end` block can be deleted. Track this by checking whether
  `telescope/previewers/utils.lua` still references `ts_parsers.ft_to_lang`
  after future plugin updates.
