# Changelog

All notable changes to meow.yarn.nvim are documented here.

## [0.1.3] - 2026-04-12

### Fixed

- Breadcrumb trail not visible on initial open — `update_breadcrumb_display` is now deferred via `vim.schedule` so it runs after `layout:mount()` has assigned `tree_popup.winid`
- Breadcrumb display incorrectly updated during back navigation — moved `update_breadcrumb_display` inside the `skip_history` guard in `reset()`
- `breadcrumb_back()` double-remove bug — previous entry was being removed from history twice and then re-inserted; now only the current entry is popped and `reset(skip_history=true)` is called with the previous entry already in place

## [0.1.2] - 2025-12-01

### Added

- **Navigation breadcrumbs** — exploration path is displayed in the tree window title (e.g. `[Animal] > [Dog] > [Poodle]`); press `<BS>` to step back; set `mappings.breadcrumb_back = nil` to disable
- **Custom node renderer** — `render_node` config option accepts a function `(node, context) -> string|nil` to fully control how each tree node is displayed; return `nil` to fall back to the built-in renderer

### Fixed

- Replaced deprecated `nvim_buf_set_option` / `nvim_win_set_option` calls with `vim.bo` / `vim.wo`
- Duplicate LSP error notifications no longer appear when multiple hierarchy requests fail

### Changed

- `mappings.breadcrumb_back` type widened to `string|nil` (`nil` disables the keymap)

## [0.1.1] - 2025-10-15

### Changed

- Removed the custom invisible cursor implementation in the hierarchy window; relies on Neovim's default cursor behavior for a more robust and consistent experience

### Fixed

- README formatting improvements
- Vimdoc tags added for `:help` integration

## [0.1.0] - 2025-10-02

Initial release.

### Features

- Interactive tree view for LSP type hierarchies (supertypes / subtypes)
- Interactive tree view for LSP call hierarchies (callers / callees)
- Live code preview pane alongside the tree
- Jump to definition with `<CR>`
- Re-root exploration on any node with `K` / `J`
- Switch direction (e.g. callers ↔ callees) on the fly
- Fully asynchronous — all LSP requests are non-blocking
- Configurable keymaps, window layout, and expand depth
- Built on Neovim's native LSP and [nui.nvim](https://github.com/MunifTanjim/nui.nvim)
