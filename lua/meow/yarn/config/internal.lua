-- MIT License
--
-- Copyright (c) 2025 Andrew Vasilyev <me@retran.me>
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.
--
-- @file: lua/meow/yarn/config/internal.lua
-- @brief: Internal configuration management for meow.yarn.nvim
-- @author: Andrew Vasilyev
-- @license: MIT

---@mod meow.yarn.config.internal
local M = {}

---@class meow.yarn.InternalConfig
local default_config = {
    ---@type { width: number, height: number, border: string, preview_height_ratio: number, layout: string }
    window = {
        width = 0.8,
        height = 0.85,
        border = "rounded",
        preview_height_ratio = 0.35,
        layout = "vertical",
    },
    ---@type { loading: string, placeholder: string, animation_frames: string[] }
    icons = {
        loading = "",
        placeholder = "",
        animation_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
    },
    ---@type { jump: string, toggle: string, expand: string, expand_alt: string, collapse: string, collapse_alt: string, show_super_hierarchy: string, show_sub_hierarchy: string, quit: string, breadcrumb_back: string|nil, yank_path: string|nil, expand_all: string|nil, collapse_all: string|nil, filter: string|nil }
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
    },
    ---@type boolean
    keep_open_on_jump = false,
    ---@type number
    expand_depth = 3,
    ---@type number
    preview_context_lines = 10,
    ---@type number
    animation_speed = 100,
    ---@type { type_hierarchy: { icons: { class: string, struct: string, interface: string, default: string } }, call_hierarchy: { icons: { method: string, func: string, variable: string, default: string } } }
    hierarchies = {
        type_hierarchy = {
            icons = {
                class = "󰌗",
                struct = "󰙅",
                interface = "󰌆",
                default = "",
            },
        },
        call_hierarchy = {
            icons = {
                method = "󰆧",
                func = "󰊕",
                variable = "",
                default = "",
            },
        },
    },
}

---@param cfg meow.yarn.InternalConfig
---@return boolean is_valid
---@return string|nil error_message
function M.validate(cfg)
    local fields = {
        { "vim.g.meow_yarn.window",                cfg.window,                "table" },
        { "vim.g.meow_yarn.icons",                 cfg.icons,                 "table" },
        { "vim.g.meow_yarn.mappings",              cfg.mappings,              "table" },
        { "vim.g.meow_yarn.expand_depth",          cfg.expand_depth,          "number" },
        { "vim.g.meow_yarn.preview_context_lines", cfg.preview_context_lines, "number" },
        { "vim.g.meow_yarn.animation_speed",       cfg.animation_speed,       "number" },
        { "vim.g.meow_yarn.hierarchies",           cfg.hierarchies,           "table" },
    }
    for _, spec in ipairs(fields) do
        local ok, err = pcall(vim.validate, spec[1], spec[2], spec[3])
        if not ok then
            return false, err
        end
    end
    if cfg.render_node ~= nil then
        local ok, err = pcall(vim.validate, "vim.g.meow_yarn.render_node", cfg.render_node, "function")
        if not ok then
            return false, err
        end
    end
    return true, nil
end

function M.get()
    local user_config = type(vim.g.meow_yarn) == "function" and vim.g.meow_yarn() or vim.g.meow_yarn or {}
    ---@type meow.yarn.InternalConfig
    local config = vim.tbl_deep_extend("force", default_config, user_config)

    -- Validate the merged configuration
    local is_valid, error_message = M.validate(config)
    if not is_valid then
        vim.notify("MeowYarn configuration error: " .. (error_message or "Unknown error"), vim.log.levels.ERROR)
        -- Return default config on validation failure
        return default_config
    end

    return config
end

return M
