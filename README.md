# 🐱 meow.yarn.nvim

> A purr-fectly simple way to visualize LSP hierarchies in Neovim.

<div align="center">

![Neovim](https://img.shields.io/badge/neovim-%23019733.svg?style=for-the-badge&logo=neovim&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-blue.svg?style=for-the-badge)
![GitHub stars](https://img.shields.io/github/stars/retran/meow.yarn.nvim?style=for-the-badge)
![GitHub forks](https://img.shields.io/github/forks/retran/meow.yarn.nvim?style=for-the-badge)

</div>

<div align="center">

<img src="https://github.com/retran/meow/raw/dev/assets/icon_small.png" alt="Meow Logo" width="200" /><br />

<strong>meow.yarn.nvim - Untangle Your Code's Relationships</strong>

</div>

Ever feel like you're unraveling a tangled ball of yarn when navigating your codebase? `meow.yarn.nvim` is here to help. It provides a simple, beautiful, and interactive way to explore LSP hierarchies without the usual clutter. Forget getting lost in endless definitions and references; **`meow.yarn.nvim` visualizes type and call hierarchies in a clean, intuitive tree view**.

---

## Screenshots

<div align="center">

<img src="assets/screenshots/screenshot_types.png" alt="types" width="800">
<img src="assets/screenshots/screenshot_calls.png" alt="calls" width="800">

</div>

---

## Key Features

- **Clean, Interactive Tree**: Shows hierarchies in a straightforward, expandable list
- **Type & Call Hierarchies**: Explore both supertypes/subtypes and callers/callees of functions
- **Live Preview**: Instantly see the relevant code for any item you select in the tree
- **Jump to Definition**: Press Enter on any item to go directly to its location in the code
- **Explore Deeper**: Pick any symbol in the tree and make it the new starting point for exploration, or switch directions (e.g., from callers to callees) on the fly
- **Breadcrumbs & Sticky Cursor**: The exploration path is shown in the window title; `<BS>` steps back and puts the cursor exactly where you drilled in
- **Multi-Selection**: Mark several nodes with `<Space>` and send them all at once to the quickfix list — or to [trouble.nvim](https://github.com/folke/trouble.nvim) when it is installed
- **Jump to the Call Site**: For incoming calls the plugin jumps to the exact line where the call happens and shows how many calls a caller makes
- **Search, Sort & Expand All**: Filter nodes with `/`, cycle sort order with `s`, expand/collapse everything with `zO` / `zC`
- **Re-open Last Session**: `:MeowYarn last` brings back the previous hierarchy exactly as it was
- **Fast & Non-Blocking**: Fully asynchronous so it won't freeze your Neovim
- **Built on Solid Foundations**: Powered by Neovim's native LSP and [nui.nvim](https://github.com/MunifTanjim/nui.nvim)

---

## Prerequisites

### Required

| Requirement      | Details                                                                                |
| ---------------- | -------------------------------------------------------------------------------------- |
| **Neovim**       | ≥ 0.8.0                                                                                |
| **LSP Client**   | An active LSP server that supports `typeHierarchyProvider` or `callHierarchyProvider`. |
| **Dependencies** | [nui.nvim](https://github.com/MunifTanjim/nui.nvim)                                    |

### Optional

| Optional                                                    | Details                                                     |
| ----------------------------------------------------------- | ----------------------------------------------------------- |
| [trouble.nvim](https://github.com/folke/trouble.nvim)       | Used instead of the built-in quickfix window when installed. |

---

## Getting Started

### Installation

Install `meow.yarn.nvim` using your favorite plugin manager.

#### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    "retran/meow.yarn.nvim",
    dependencies = { "MunifTanjim/nui.nvim" },
    config = function()
        require("meow.yarn").setup({
            -- Your custom configuration goes here
        })
    end,
}
```

#### [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
    "retran/meow.yarn.nvim",
    requires = { "MunifTanjim/nui.nvim" },
    config = function()
        require("meow.yarn").setup({})
    end,
}
```

#### [rocks.nvim](https://github.com/lumen-oss/rocks.nvim)

```vim
:Rocks install meow.yarn.nvim
```

The dependency (nui.nvim) will be automatically installed and managed.
Then add to your Neovim configuration:

```lua
require("meow.yarn").setup({
    -- Your custom configuration goes here
})
```

### Quick Start

The plugin provides the `:MeowYarn` command to open hierarchy views.

- **View Type Hierarchy (Supertypes):** `:MeowYarn type super`
- **View Type Hierarchy (Subtypes):** `:MeowYarn type sub`
- **View Call Hierarchy (Callers):** `:MeowYarn call callers`
- **View Call Hierarchy (Callees):** `:MeowYarn call callees`
- **Re-open the Last Hierarchy:** `:MeowYarn last`

---

## Configuration and Mappings

### Default Configuration

You can customize the plugin by passing a configuration table to the `setup` function. Here are the defaults:

```lua
require("meow.yarn").setup({
    window = {
        width = 0.8,
        height = 0.85,
        border = "rounded",
        preview_height_ratio = 0.35,
        -- "vertical": tree above, preview below (default); "horizontal": tree left, preview right
        layout = "vertical",
    },
    icons = {
        loading = "",
        placeholder = "",
        selected = "●",
        animation_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
    },
    mappings = {
        jump = "<CR>",
        toggle = "<Tab>",
        expand = "l",
        expand_alt = "<Right>",
        collapse = "h",
        collapse_alt = "<Left>",
        show_super_hierarchy = "K",
        show_sub_hierarchy = "J",
        quit = "q",
        breadcrumb_back = "<BS>",
        yank_path = "y",
        expand_all = "zO",
        collapse_all = "zC",
        filter = "/",
        preview_scroll_down = "<C-d>",
        preview_scroll_up = "<C-u>",
        sort = "s",
        toggle_select = "<Space>",
        clear_selection = "<Esc>",
        send_to_quickfix = "<C-q>",
    },
    quickfix = {
        -- Open trouble.nvim (when installed) instead of the built-in quickfix window.
        use_trouble = true,
    },
    -- Stay in the hierarchy window after jumping to a symbol.
    keep_open_on_jump = false,
    expand_depth = 3,
    preview_context_lines = 10,
    animation_speed = 100,
    hierarchies = {
        type_hierarchy = {
            icons = {
                class = "󰌗",
                struct = "󰙅",
                interface = "󰌆",
                default = "",
            },
        },
        call_hierarchy = {
            icons = {
                method = "󰆧",
                func = "󰊕",
                variable = "",
                default = "",
            },
        },
    },
    -- Optional: fully control how each node is rendered, see `:help meow-yarn-render-node`.
    -- render_node = function(node_info)
    --     return string.format("%s %s", node_info.icon, node_info.name)
    -- end,
})
```

### Keymaps

You can map the commands for easier access.

#### Example Lua Keymaps

```lua
-- Using lua functions
vim.keymap.set("n", "<leader>yt", function() require("meow.yarn").open_tree("type_hierarchy", "supertypes") end, { desc = "Yarn: Type Hierarchy (Super)" })
vim.keymap.set("n", "<leader>yT", function() require("meow.yarn").open_tree("type_hierarchy", "subtypes") end, { desc = "Yarn: Type Hierarchy (Sub)" })
vim.keymap.set("n", "<leader>yc", function() require("meow.yarn").open_tree("call_hierarchy", "callers") end, { desc = "Yarn: Call Hierarchy (Callers)" })
vim.keymap.set("n", "<leader>yC", function() require("meow.yarn").open_tree("call_hierarchy", "callees") end, { desc = "Yarn: Call Hierarchy (Callees)" })
vim.keymap.set("n", "<leader>yl", "<Plug>(MeowYarnLast)", { desc = "Yarn: Re-open last hierarchy" })

-- Or using commands
vim.keymap.set("n", "<leader>yS", "<Cmd>MeowYarn type super<CR>", { desc = "Yarn: Super Types" })
vim.keymap.set("n", "<leader>ys", "<Cmd>MeowYarn type sub<CR>", { desc = "Yarn: Sub Types" })
vim.keymap.set("n", "<leader>yC", "<Cmd>MeowYarn call callers<CR>", { desc = "Yarn: Callers" })
vim.keymap.set("n", "<leader>yc", "<Cmd>MeowYarn call callees<CR>", { desc = "Yarn: Callees" })
```

### In-Window Mappings

Inside the hierarchy view, the following default keymappings are available:

| Key              | Action                                                                              |
| ---------------- | ----------------------------------------------------------------------------------- |
| `<CR>`           | Jump to the selected item, or open the whole selection (`mappings.jump`)            |
| `<Tab>`          | Toggle expand/collapse for the selected node (`mappings.toggle`)                    |
| `l` or `<Right>` | Expand the selected node (`mappings.expand`, `mappings.expand_alt`)                 |
| `h` or `<Left>`  | Collapse the selected node (`mappings.collapse`, `mappings.collapse_alt`)           |
| `zO` / `zC`      | Expand / collapse all nodes (`mappings.expand_all`, `mappings.collapse_all`)        |
| `<Space>`        | Toggle multi-selection for the node (`mappings.toggle_select`)                      |
| `<C-q>`          | Send the selection to quickfix / trouble.nvim (`mappings.send_to_quickfix`)         |
| `<Esc>`          | Clear the multi-selection (`mappings.clear_selection`)                              |
| `/`              | Filter nodes by name (`mappings.filter`)                                            |
| `s`              | Cycle sort order: lsp → alpha → file (`mappings.sort`)                              |
| `y`              | Yank `file:line` of the selected node to the clipboard (`mappings.yank_path`)       |
| `<C-d>` / `<C-u>`| Scroll the preview pane (`mappings.preview_scroll_down`, `..._up`)                  |
| `K` / `J`        | Open new hierarchy from selected item (K=super/callers, J=sub/callees)              |
| `<BS>`           | Step back in the breadcrumb history (`mappings.breadcrumb_back`)                    |
| `q`              | Quit the hierarchy view (`mappings.quit`)                                           |

### Multi-Selection and Quickfix

Press `<Space>` to mark nodes (the cursor moves down, so repeated presses select consecutive items), then `<C-q>` — or simply `<CR>` — to send them all to the quickfix list at once. With nothing selected, the node under the cursor is used. When [trouble.nvim](https://github.com/folke/trouble.nvim) is installed it is opened instead of the built-in quickfix window; set `quickfix.use_trouble = false` to always use `:copen`.

See `:help meow-yarn-selection` for details.

---

## Contributing

Contributions are welcome! Feel free to open an issue or submit a pull request.

- Report bugs and issues
- Suggest new features
- Improve documentation
- Submit pull requests

---

## License

Licensed under the MIT License. See [`LICENSE`](LICENSE) for details.

---

## Acknowledgments

`meow.yarn.nvim` would not be possible without these amazing projects:

- [Neovim](https://neovim.io/)
- [nui.nvim](https://github.com/MunifTanjim/nui.nvim) for the wonderful UI components.
- [trouble.nvim](https://github.com/folke/trouble.nvim) for the optional quickfix integration.

Special thanks to everyone who helped shape this plugin:

- [@Sword-Of-Code](https://github.com/Sword-Of-Code) — for suggesting multi-selection, the trouble.nvim integration and a shortcut for re-opening the last search ([#18](https://github.com/retran/meow.yarn.nvim/issues/18)).
- [@raphaelahrens](https://github.com/raphaelahrens) — for reporting the rendering crash caused by multi-line symbol names from rust-analyzer ([#17](https://github.com/retran/meow.yarn.nvim/issues/17)).
- [@qufeiyan](https://github.com/qufeiyan) — for the idea of jumping straight to the call site, matching VS Code's call hierarchy behaviour ([#9](https://github.com/retran/meow.yarn.nvim/pull/9)).
- [@Nichtigott](https://github.com/Nichtigott) — for reporting the Neovim 0.11+ deprecation warnings ([#8](https://github.com/retran/meow.yarn.nvim/issues/8)).
- [@zkamvar](https://github.com/zkamvar) — for suggesting that repeated LSP error notifications be suppressed ([#4](https://github.com/retran/meow.yarn.nvim/issues/4)).
- [@gi4c0](https://github.com/gi4c0) — for reporting the invalid highlight color error ([#3](https://github.com/retran/meow.yarn.nvim/issues/3)).

---

### Author

`meow.yarn.nvim` is developed by Andrew Vasilyev with help from GitHub Copilot and feline assistants Sonya Blade, Mila, and Marcus Fenix.

---

<div align="center">

**Happy coding with `project meow`! 🐱**

Made with ❤️ by Andrew Vasilyev and feline assistants Sonya Blade, Mila, and Marcus Fenix.

[Report Bug](https://github.com/retran/meow.yarn.nvim/issues) ·
[Request Feature](https://github.com/retran/meow.yarn.nvim/issues) ·
[Contribute](https://github.com/retran/meow.yarn.nvim/pulls)

</div>
