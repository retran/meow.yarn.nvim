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
-- @file: lua/meow/yarn/util.lua
-- @brief: Utility functions for LSP and general tasks
-- @author: Andrew Vasilyev
-- @license: MIT

---@mod meow.yarn.util
---@brief Utility functions for LSP and general tasks.
local M = {}

M.K = {
    HIGHLIGHT_GROUP = "MeowYarnPreview",
    PREVIEW_NAMESPACE = "meow_yarn_preview",
    SIGN_CURSOR_NAME = "MeowYarnCursor",
    SIGN_GROUP = "MeowYarnGroup",
}

---@class meow.yarn.LspUtils
M.lsp = {}

-- Tracks recently shown LSP error messages to avoid spamming the user.
-- Maps "method:message" -> timestamp of last notification.
local _lsp_error_cache = {}
local _LSP_ERROR_DEBOUNCE_MS = 3000

--- Sends an async request to an LSP client.
---@param client table The LSP client.
---@param method string The LSP method to call.
---@param params table|nil The parameters for the method.
---@param bufnr number|nil The buffer number for the request.
---@param callback function The callback to execute with the result.
function M.lsp.request_async(client, method, params, bufnr, callback)
    client.request(method, params or {}, function(err, res)
        if err then
            if err.code == -32800 then -- Request cancelled — silent
                return callback(nil)
            end
            -- Deduplicate noisy LSP error notifications (e.g. server-side
            -- "key not found" errors from servers that don't track all documents).
            local key = method .. ":" .. (err.message or "")
            local now = vim.uv and vim.uv.now() or vim.loop.now()
            if not _lsp_error_cache[key] or (now - _lsp_error_cache[key]) >= _LSP_ERROR_DEBOUNCE_MS then
                _lsp_error_cache[key] = now
                vim.schedule(function()
                    vim.notify(
                        string.format("LSP %s: %s", method, err.message or "error"),
                        vim.log.levels.WARN
                    )
                end)
            end
            return callback(nil)
        end
        callback(res or {})
    end, bufnr or 0)
end

--- Finds an active LSP client for a buffer that supports a given capability.
---@param bufnr number The buffer number.
---@param capability_key string The server capability to check for (e.g., "typeHierarchyProvider").
---@return table|nil The found LSP client, or nil.
function M.lsp.find_client(bufnr, capability_key)
    local get_clients = vim.lsp.get_clients or vim.lsp.get_active_clients
    for _, client in ipairs(get_clients({ bufnr = bufnr })) do
        if client.server_capabilities and client.server_capabilities[capability_key] then
            return client
        end
    end
    -- Fallback to checking all clients if no buffer-specific client is found
    for _, client in ipairs(get_clients()) do
        if client.server_capabilities and client.server_capabilities[capability_key] then
            return client
        end
    end
    return nil
end

--- Gets the offset encoding from an LSP client.
---@param client table|nil The LSP client.
---@return string The offset encoding (e.g., "utf-8").
function M.lsp.get_encoding(client)
    if not client or not client.offset_encoding then
        return "utf-8"
    end
    local encoding = client.offset_encoding
    while type(encoding) == "table" and encoding[1] do
        encoding = encoding[1]
    end
    return type(encoding) == "string" and encoding or "utf-8"
end

--- Resolves the range to use when jumping to / previewing an LSP item.
--- Incoming-call items carry `call_site_ranges` (the LSP `fromRanges`), i.e. the
--- exact positions where the call happens inside the caller; preferring them
--- matches the behaviour of VS Code's "show call hierarchy".
---@param item table|nil The LSP item.
---@return table|nil The range to use, or nil when the item has none.
function M.item_range(item)
    if not item then return nil end
    local ranges = item.call_site_ranges
    if type(ranges) == "table" and ranges[1] then
        return ranges[1]
    end
    return item.selectionRange or item.range
end

--- Jumps to the location specified by an LSP item.
---@param lsp_item table The LSP item with URI and range.
---@param client table The LSP client, used for offset encoding.
function M.jump_to_item(lsp_item, client)
    if not lsp_item or not lsp_item.uri then
        return
    end
    local range = M.item_range(lsp_item)
    if not range then
        return
    end
    local encoding = M.lsp.get_encoding(client)
    vim.lsp.util.show_document({ uri = lsp_item.uri, range = range }, encoding, { focus = true })
end

--- Creates a default key for an LSP item to be used as a node ID.
---@param item table The LSP item.
---@return string A unique key for the item.
function M.default_key_from_item(item)
    if item.is_placeholder then
        return "placeholder"
    end
    local sr = item.selectionRange or item.range or {}
    local s = sr.start or { line = -1, character = -1 }
    local e = sr["end"] or { line = -1, character = -1 }
    local uri, name, detail = item.uri or "?", item.name or "?", item.detail or ""
    return string.format("%s|%s|%d:%d|%d:%d|%s", uri, name, s.line, s.character, e.line, e.character, detail)
end

--- Generates a unique ID for a node in a tree to prevent duplicates.
---@param tree table The NuiTree instance.
---@param base_id string The base ID for the node.
---@return string A unique ID.
function M.unique_id_for(tree, base_id)
    local id, n = base_id, 1
    while tree and tree:get_node(id) do
        n = n + 1
        id = base_id .. "#" .. n
    end
    return id
end

--- Flattens a string into a single display line.
--- LSP servers (notably rust-analyzer) may return item names or details that
--- contain newlines; passing those to nui/`nvim_buf_set_lines` raises
--- "'replacement string' item contains newlines", so every string that ends up
--- in a tree line must go through this first.
---@param s string|nil The raw string.
---@return string A single-line string with control characters collapsed into spaces.
function M.sanitize_text(s)
    if type(s) ~= "string" then return "" end
    -- Replace any newline / carriage return / tab / other control char with a space.
    local flat = s:gsub("%c", " ")
    -- Collapse runs of whitespace and trim.
    flat = flat:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    return flat
end

--- Shortens a file path for display.
---@param p string The full file path.
---@return string The shortened path.
function M.short_path(p)
    return p and vim.fn.fnamemodify(p, ":~:.") or ""
end

--- Builds the selection marker prefix for a node.
--- Returns the configured marker icon when the node is part of the multi-selection,
--- an equally wide blank otherwise, so lines stay aligned.
---@param node table The NuiTree node.
---@param hierarchy_instance table|nil The Hierarchy instance holding the selection.
---@return string The marker prefix.
function M.selection_marker(node, hierarchy_instance)
    if not (hierarchy_instance and hierarchy_instance.selection) then return "" end
    if vim.tbl_isempty(hierarchy_instance.selection) then return "" end
    local cfg = require("meow.yarn.config.internal").get()
    local icon = cfg.icons.selected or "*"
    local marker = hierarchy_instance.selection[node:get_id()] and icon or " "
    return marker .. " "
end

--- Converts LSP items into quickfix entries.
---@param items table[] List of LSP hierarchy items.
---@return table[] Quickfix entries.
function M.items_to_qf(items)
    local entries = {}
    for _, item in ipairs(items) do
        if item and item.uri and not item.is_placeholder then
            local range = M.item_range(item)
            local start = range and range.start or { line = 0, character = 0 }
            table.insert(entries, {
                filename = vim.uri_to_fname(item.uri),
                lnum = start.line + 1,
                col = start.character + 1,
                text = M.sanitize_text(item.name) ..
                    ((item.detail and item.detail ~= "") and (" " .. M.sanitize_text(item.detail)) or ""),
            })
        end
    end
    return entries
end

--- Sends LSP items to the quickfix list and opens it.
--- Uses trouble.nvim when it is installed and not disabled via `quickfix.use_trouble`.
---@param items table[] List of LSP hierarchy items.
---@param title string The quickfix list title.
---@return number The number of entries added.
function M.send_to_quickfix(items, title)
    local entries = M.items_to_qf(items)
    if #entries == 0 then
        vim.notify("MeowYarn: nothing to send to the quickfix list.", vim.log.levels.WARN)
        return 0
    end
    vim.fn.setqflist({}, " ", { title = title or "MeowYarn", items = entries })

    local cfg = require("meow.yarn.config.internal").get()
    if cfg.quickfix and cfg.quickfix.use_trouble then
        local has_trouble, trouble = pcall(require, "trouble")
        if has_trouble then
            -- trouble.nvim v3 takes an opts table; v2 takes a mode string.
            local ok = pcall(trouble.open, { mode = "quickfix", focus = true })
            if not ok then ok = pcall(trouble.open, "quickfix") end
            if ok then return #entries end
        end
    end
    vim.cmd("copen")
    return #entries
end

--- LSP kind number to human-readable name mapping.
M.LSP_KIND_NAMES = {
    [1] = "File", [2] = "Module", [3] = "Namespace", [4] = "Package",
    [5] = "Class", [6] = "Method", [7] = "Property", [8] = "Field",
    [9] = "Constructor", [10] = "Enum", [11] = "Interface", [12] = "Function",
    [13] = "Variable", [14] = "Constant", [15] = "String", [16] = "Number",
    [17] = "Boolean", [18] = "Array", [19] = "Object", [20] = "Key",
    [21] = "Null", [22] = "EnumMember", [23] = "Struct", [24] = "Event",
    [25] = "Operator", [26] = "TypeParameter",
}

--- Tries to invoke a user-supplied render_node function for a node.
--- If the function returns a non-nil string, wraps it in a NuiLine and returns it.
--- Returns nil if no custom renderer is configured or if it returns nil.
---@param node table The NuiTree node.
---@param item table The resolved LSP item for this node.
---@param icon string The resolved icon string.
---@param hierarchy_instance table The Hierarchy instance.
---@return table|nil A NuiLine if the custom renderer produced output, else nil.
function M.try_custom_render(node, item, icon, hierarchy_instance)
    local cfg = require("meow.yarn.config.internal").get()
    if type(cfg.render_node) ~= "function" then return nil end

    local file = item.uri and vim.uri_to_fname(item.uri) or nil
    local item_range = M.item_range(item)
    local sel = item_range and item_range.start

    ---@type meow.yarn.NodeInfo
    local node_info = {
        name = M.sanitize_text(item.name),
        kind = M.LSP_KIND_NAMES[item.kind] or "Unknown",
        icon = icon,
        file = file and M.short_path(file) or nil,
        line = sel and (sel.line + 1) or nil,
        detail = (item.detail and item.detail ~= "") and M.sanitize_text(item.detail) or nil,
        depth = node:get_depth(),
        is_loading = node.loading or false,
        is_placeholder = item.is_placeholder or false,
        direction = node.dir_key,
    }

    local ok, result = pcall(cfg.render_node, node_info)
    if not ok then
        vim.schedule(function()
            vim.notify("MeowYarn render_node error: " .. tostring(result), vim.log.levels.ERROR)
        end)
        return nil
    end
    if type(result) ~= "string" then return nil end

    local Line = require("nui.line")
    local line = Line()
    line:append(M.sanitize_text(result))
    return line
end

return M
