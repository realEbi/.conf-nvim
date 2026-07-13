# CodeSnap Issues on macOS 26+

## Problem 1: Neovim crashes on startup (SIGKILL - Code Signature Invalid)

After a Lazy update, nvim gets killed immediately with `Killed: 9`.

### Root Cause

The `generator.so` binary shipped with codesnap has a `com.apple.provenance` extended attribute (set by macOS when files are downloaded/cloned). On macOS 26, this triggers strict code signature validation. Since the `.so` is only ad-hoc signed, the OS kills the process when it tries to `dlopen` the library.

The crash report shows:
- Signal: `SIGKILL (Code Signature Invalid)`
- Termination namespace: `CODESIGNING`
- Indicator: `Invalid Page`
- Faulting library: `generator.so`

### Fix

Remove the plugin entirely and reinstall (fresh clone gets a valid signature):

```bash
rm -rf ~/.local/share/nvim/lazy/codesnap.nvim
nvim --headless -c 'lua require("lazy").install({wait=true})' -c 'qall'
```

Alternatively, re-sign the binary:

```bash
codesign --force --sign - ~/.local/share/nvim/lazy/codesnap.nvim/lua/libs/mac-aarch64_generator.so
```

Note: `xattr -d com.apple.provenance` does NOT work on macOS 26 — the attribute is kernel-level and irremovable.

---

## Problem 2: `parse_code_theme` nil error when running CodeSnap

Running `:CodeSnap` or `:CodeSnapSave` gives:

```
attempt to call field 'parse_code_theme' (a nil value)
```

### Root Cause

There are TWO `generator.so` files in the plugin:

1. `lua/generator.so` — old binary placed by `make` build step (copies bundled pre-built binaries from git). Only has: `copy_into_clipboard`, `save_snapshot`, `copy_ascii`.
2. `lua/libs/mac-aarch64_generator.so` — correctly downloaded v2.0.5 release binary. Has: `copy`, `save`, `copy_ascii`, `parse_code_theme`.

The plugin's Lua code (v2.0.5) expects the newer API, but `require("generator")` finds the old `lua/generator.so` first on the cpath because it's in the same directory as the Lua files.

Additionally, `config.lua:32` calls `module.load_generator(true)` which forces debug/local-build mode instead of using the downloaded release library.

### Fix

Remove the old bundled binaries so the plugin uses the correct downloaded version:

```bash
rm -f ~/.local/share/nvim/lazy/codesnap.nvim/lua/generator.so
rm -f ~/.local/share/nvim/lazy/codesnap.nvim/lua/mac-aarch64generator.so
rm -f ~/.local/share/nvim/lazy/codesnap.nvim/lua/mac-x86_64generator.so
rm -f ~/.local/share/nvim/lazy/codesnap.nvim/lua/linux-x86_64generator.so
```

Then fix the debug mode bug in config.lua:

```bash
sed -i '' 's/module.load_generator(true)/module.load_generator()/' \
  ~/.local/share/nvim/lazy/codesnap.nvim/lua/codesnap/config.lua
```

Then sign the downloaded library:

```bash
codesign --force --sign - ~/.local/share/nvim/lazy/codesnap.nvim/lua/libs/mac-aarch64_generator.so
```

---

## Full Recovery (both problems)

Run all steps together:

```bash
# 1. Remove and reinstall plugin
rm -rf ~/.local/share/nvim/lazy/codesnap.nvim
nvim --headless -c 'lua require("lazy").install({wait=true})' -c 'qall'

# 2. Remove old bundled binaries
rm -f ~/.local/share/nvim/lazy/codesnap.nvim/lua/generator.so
rm -f ~/.local/share/nvim/lazy/codesnap.nvim/lua/mac-aarch64generator.so
rm -f ~/.local/share/nvim/lazy/codesnap.nvim/lua/mac-x86_64generator.so
rm -f ~/.local/share/nvim/lazy/codesnap.nvim/lua/linux-x86_64generator.so

# 3. Fix debug mode bug in config.lua
sed -i '' 's/module.load_generator(true)/module.load_generator()/' \
  ~/.local/share/nvim/lazy/codesnap.nvim/lua/codesnap/config.lua

# 4. Sign the correct library
codesign --force --sign - ~/.local/share/nvim/lazy/codesnap.nvim/lua/libs/mac-aarch64_generator.so
```

---

## Notes

- This will need to be re-applied after every `:Lazy update` that touches codesnap.
- The `config.lua` bug (`load_generator(true)`) is likely an upstream issue — consider filing a bug at https://github.com/mistricky/codesnap.nvim/issues.
- The `make` build target in the plugin's Makefile just copies old pre-built `.so` files from the git repo — it does NOT compile from source (that requires Rust/cargo).
