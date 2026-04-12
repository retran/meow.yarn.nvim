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
-- @file: lua/meow/yarn/health.lua
-- @brief: Health checks for the meow.yarn plugin
-- @author: Andrew Vasilyev
-- @license: MIT

---@mod meow.yarn.health
---@brief Health checks for the meow.yarn plugin
local M = {}

---@private
local function check_neovim_version()
    vim.health.start("Neovim version")

    -- vim.version() and vim.version.cmp() were added in Neovim 0.9.
    -- On 0.8 we must use vim.fn.has() exclusively to avoid a crash.
    local has_090 = vim.fn.has("nvim-0.9.0") == 1
    local has_0100 = vim.fn.has("nvim-0.10.0") == 1
    local has_080 = vim.fn.has("nvim-0.8.0") == 1

    if not has_080 then
        vim.health.error("Neovim >= 0.8.0 is required")
        return false
    end

    local version_str = has_090 and tostring(vim.version()) or "0.8.x"

    if has_0100 then
        vim.health.ok("Neovim " .. version_str .. " (>= 0.10.0, full feature support)")
    elseif has_090 then
        vim.health.ok("Neovim " .. version_str .. " (>= 0.9.0)")
        vim.health.warn("Neovim 0.10+ is recommended for the best experience")
    else
        -- 0.8.x: supported but with caveats
        vim.health.warn(
            "Neovim " .. version_str .. " (0.8.x detected)"
            .. " - plugin is functional, but 0.9.0+ is recommended"
        )
    end
    return true
end

---@private
local function check_dependencies()
    vim.health.start("Dependencies")
    local all_ok = true

    -- Check for nui.nvim
    local has_nui, nui = pcall(require, "nui.popup")
    if has_nui and nui then
        vim.health.ok("nui.nvim is installed")
    else
        vim.health.error("nui.nvim is not installed or not accessible. Please install folke/nui.nvim")
        all_ok = false
    end

    -- Check for nui.tree
    local has_tree, tree = pcall(require, "nui.tree")
    if has_tree and tree then
        vim.health.ok("nui.tree is available")
    else
        vim.health.error("nui.tree is not available. Please ensure nui.nvim is properly installed")
        all_ok = false
    end

    -- Check for nui.layout
    local has_layout, layout = pcall(require, "nui.layout")
    if has_layout and layout then
        vim.health.ok("nui.layout is available")
    else
        vim.health.error("nui.layout is not available. Please ensure nui.nvim is properly installed")
        all_ok = false
    end

    return all_ok
end

---@private
local function check_configuration()
    vim.health.start("Configuration")

    local config_ok, config_internal = pcall(require, "meow.yarn.config.internal")
    if not config_ok then
        vim.health.error("Could not load configuration module: " .. tostring(config_internal))
        return false
    end

    local config = config_internal.get()
    local is_valid, error_message = config_internal.validate(config)

    if is_valid then
        vim.health.ok("Configuration is valid")

        -- Show some key configuration values for debugging
        vim.health.info("Window size: " .. config.window.width .. "x" .. config.window.height)
        vim.health.info("Border style: " .. config.window.border)
        vim.health.info("Expand depth: " .. config.expand_depth)
        vim.health.info("Animation speed: " .. config.animation_speed .. "ms")
    else
        vim.health.error("Configuration validation failed: " .. (error_message or "Unknown error"))
        return false
    end

    -- Check if user has customized configuration
    if vim.g.meow_yarn then
        vim.health.info("User configuration detected in vim.g.meow_yarn")
    else
        vim.health.info("Using default configuration (vim.g.meow_yarn not set)")
    end

    return true
end

---@private
local function check_lsp_clients()
    vim.health.start("LSP Clients")

    local get_clients = vim.lsp.get_clients or vim.lsp.get_active_clients
    local active_clients = get_clients()
    if #active_clients == 0 then
        vim.health.warn("No active LSP clients found. Type and call hierarchies require LSP servers.")
        return false
    end

    vim.health.ok("Found " .. #active_clients .. " active LSP client(s)")

    -- Check for type hierarchy capability
    local type_hierarchy_clients = {}
    local call_hierarchy_clients = {}

    for _, client in ipairs(active_clients) do
        if client.server_capabilities then
            if client.server_capabilities.typeHierarchyProvider then
                table.insert(type_hierarchy_clients, client.name)
            end
            if client.server_capabilities.callHierarchyProvider then
                table.insert(call_hierarchy_clients, client.name)
            end
        end
    end

    if #type_hierarchy_clients > 0 then
        vim.health.ok("Type hierarchy support found in: " .. table.concat(type_hierarchy_clients, ", "))
    else
        vim.health.warn("No LSP clients with type hierarchy support found")
    end

    if #call_hierarchy_clients > 0 then
        vim.health.ok("Call hierarchy support found in: " .. table.concat(call_hierarchy_clients, ", "))
    else
        vim.health.warn("No LSP clients with call hierarchy support found")
    end

    return #type_hierarchy_clients > 0 or #call_hierarchy_clients > 0
end

---@private
local function provide_troubleshooting_info()
    vim.health.start("Troubleshooting Information")

    vim.health.info("Plugin directory: lua/meow/yarn/")
    vim.health.info("Configuration location: vim.g.meow_yarn")
    vim.health.info("Health check: :checkhealth meow.yarn")

    -- Minimal configuration example
    vim.health.info([[
Minimal configuration example:
vim.g.meow_yarn = {
    window = { width = 0.8, height = 0.8 },
    expand_depth = 2
}]])

    -- Common issues and solutions
    vim.health.info([[
Common issues:
1. "No symbol found under cursor" - Ensure LSP is running and cursor is on a symbol
2. "No active LSP client supports this feature" - Install LSP server with hierarchy support
3. UI not appearing - Check if nui.nvim is installed: require('nui.popup')
4. Configuration errors - Run :checkhealth meow.yarn to validate config
]])
end

--- Main health check function called by :checkhealth
function M.check()
    local nvim_ok = check_neovim_version()
    if not nvim_ok then
        return -- Don't continue if Neovim version is too old
    end

    local deps_ok = check_dependencies()

    -- Feature availability — only meaningful once nui.nvim is confirmed present.
    vim.health.start("Feature availability")
    vim.health.ok("Breadcrumb titles in tree window (supported on all versions via nui.nvim border)")

    local config_ok = check_configuration()
    local lsp_ok = check_lsp_clients()

    provide_troubleshooting_info()

    -- Summary
    vim.health.start("Summary")
    if deps_ok and config_ok then
        if lsp_ok then
            vim.health.ok("Plugin is ready to use!")
        else
            vim.health.warn("Plugin is configured but no LSP clients with hierarchy support found")
        end
    else
        vim.health.error("Plugin has configuration or dependency issues - see above for details")
    end
end

return M
