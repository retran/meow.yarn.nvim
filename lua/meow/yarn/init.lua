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
-- @file: lua/meow/yarn/init.lua
-- @brief: Main module for meow.yarn.nvim - LSP hierarchy visualization plugin
-- @author: Andrew Vasilyev
-- @license: MIT

---@mod meow.yarn
---@brief A Neovim plugin for visualizing LSP hierarchies (types and calls).
---@author Andrew Vasilyev
local M = {}

-- Lazy-loaded modules
local config_internal = nil
local util = nil
local Hierarchy = nil
local strategies = nil
local state = nil

-- Initialize modules lazily when first needed
local function ensure_loaded()
    if not config_internal then
        require("meow.yarn.config.meta")
        config_internal = require("meow.yarn.config.internal")
        util = require("meow.yarn.util")
        Hierarchy = require("meow.yarn.hierarchy")
        state = require("meow.yarn.state")

        strategies = {
            type_hierarchy = require("meow.yarn.strategies.type"),
            call_hierarchy = require("meow.yarn.strategies.call"),
        }
    end
end

local function get_config()
    ensure_loaded()
    return config_internal.get()
end

local _private = {}

--- Fetches the root item from the LSP and then builds the hierarchy tree.
--- This is called after a placeholder UI is shown.
---@param placeholder table The placeholder Hierarchy instance.
---@param client table The LSP client.
---@param source_win number The source window ID.
---@param strategy table The hierarchy strategy to use.
---@param strategy_name string The strategy name key.
---@param direction_key string The direction of the hierarchy.
function _private.fetch_root_and_build_tree(placeholder, client, source_win, strategy, strategy_name, direction_key)
    if not placeholder:is_valid() then return end
    strategy.prepare_root_item(client, source_win, function(root_item)
        if not placeholder:is_valid() then return end
        placeholder:unmount()
        if not root_item then
            return vim.notify(strategy.name .. ": No symbol found under cursor.", vim.log.levels.WARN)
        end
        M.open_from_item(root_item, strategy, direction_key, strategy_name)
    end)
end

--- Opens a new hierarchy view starting from a specific LSP item.
---@param item table The root LSP item.
---@param strategy table The hierarchy strategy.
---@param direction_key string The direction of the hierarchy.
---@param strategy_name? string The strategy name key, used to persist the session for re-opening.
function M.open_from_item(item, strategy, direction_key, strategy_name)
    ensure_loaded()
    local bufnr = item.uri and vim.uri_to_bufnr(item.uri) or vim.api.nvim_get_current_buf()
    if not util or not util.lsp then
        ensure_loaded()
    end
    local client = util.lsp.find_client(bufnr, strategy.lsp_capability)
    if not client then
        return vim.notify(strategy.name .. ": No active LSP client supports this feature.", vim.log.levels.WARN)
    end
    if not Hierarchy then
        ensure_loaded()
    end
    -- Persist last session for :MeowYarn last
    if strategy_name then
        state.G.last_session = { item = item, strategy_name = strategy_name, direction_key = direction_key }
    end
    local hierarchy = Hierarchy:new(client, item, strategy, direction_key)
    hierarchy:mount()
    local root_node = hierarchy.tree:get_node(1)
    if root_node then
        hierarchy:update_node(root_node, get_config().expand_depth)
    end
end

--- Re-opens the last opened hierarchy session (same item, strategy, and direction).
--- Does nothing if no session has been opened yet.
function M.reopen_last()
    ensure_loaded()
    local session = state.G.last_session
    if not session then
        return vim.notify("MeowYarn: No previous hierarchy session to re-open.", vim.log.levels.WARN)
    end
    local strategy = strategies[session.strategy_name]
    if not strategy then
        return vim.notify("MeowYarn: Unknown strategy '" .. session.strategy_name .. "'", vim.log.levels.ERROR)
    end
    M.open_from_item(session.item, strategy, session.direction_key, session.strategy_name)
end

--- Opens a hierarchy tree for the symbol under the cursor in the current window.
---@param strategy_name string The name of the strategy to use (e.g., "type_hierarchy").
---@param direction_key string The direction of the hierarchy.
function M.open_tree(strategy_name, direction_key)
    ensure_loaded()
    if not strategies then
        ensure_loaded()
    end
    local strategy = strategies[strategy_name]
    if not strategy then
        return vim.notify("MeowYarn: Unknown strategy '" .. strategy_name .. "'", vim.log.levels.ERROR)
    end

    local source_win = vim.api.nvim_get_current_win()
    local source_buf = vim.api.nvim_win_get_buf(source_win)
    if not util or not util.lsp then
        ensure_loaded()
    end
    local client = util.lsp.find_client(source_buf, strategy.lsp_capability)

    if not client then
        return vim.notify(strategy.name .. ": No active LSP client supports this feature.", vim.log.levels.WARN)
    end

    local placeholder_item = { name = "Loading...", is_placeholder = true, kind = 0 }
    if not Hierarchy then
        ensure_loaded()
    end
    local placeholder_hierarchy = Hierarchy:new(client, placeholder_item, strategy, direction_key)
    placeholder_hierarchy:mount()
    vim.schedule(function()
        _private.fetch_root_and_build_tree(placeholder_hierarchy, client, source_win, strategy, strategy_name, direction_key)
    end)
end

--- Configure the plugin (optional)
--- This function allows users to override default configuration
---@param opts table|nil User-provided configuration options.
function M.setup(opts)
    vim.g.meow_yarn = vim.tbl_deep_extend("force", vim.g.meow_yarn or {}, opts or {})
end

return M
