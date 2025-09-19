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

--- Sends an async request to an LSP client.
---@param client table The LSP client.
---@param method string The LSP method to call.
---@param params table|nil The parameters for the method.
---@param bufnr number|nil The buffer number for the request.
---@param callback function The callback to execute with the result.
function M.lsp.request_async(client, method, params, bufnr, callback)
    client.request(method, params or {}, function(err, res)
        if err and err.code ~= -32800 then -- -32800: "Request cancelled"
            vim.schedule(function()
                vim.notify(string.format("LSP %s: %s", method, err.message or "error"), vim.log.levels.ERROR)
            end)
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
    for _, client in ipairs(vim.lsp.get_active_clients({ bufnr = bufnr })) do
        if client.server_capabilities and client.server_capabilities[capability_key] then
            return client
        end
    end
    -- Fallback to checking all clients if no buffer-specific client is found
    for _, client in ipairs(vim.lsp.get_active_clients()) do
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

--- Jumps to the location specified by an LSP item.
---@param lsp_item table The LSP item with URI and range.
---@param client table The LSP client, used for offset encoding.
function M.jump_to_item(lsp_item, client)
    if not lsp_item or not lsp_item.uri then
        return
    end
    local range = lsp_item.selectionRange or lsp_item.range
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

--- Shortens a file path for display.
---@param p string The full file path.
---@return string The shortened path.
function M.short_path(p)
    return p and vim.fn.fnamemodify(p, ":~:.") or ""
end

return M
