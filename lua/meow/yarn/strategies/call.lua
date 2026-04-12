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
-- @file: lua/meow/yarn/strategies/call.lua
-- @brief: Strategy for handling LSP call hierarchies
-- @author: Andrew Vasilyev
-- @license: MIT

---@mod meow.yarn.strategies.call
---@brief Strategy for handling LSP call hierarchies.

local get_config = function() return require("meow.yarn.config.internal").get() end
local state = require("meow.yarn.state")
local util = require("meow.yarn.util")

local call_hierarchy_strategy = {
    name = "Call Hierarchy",
    lsp_capability = "callHierarchyProvider",
    lsp_methods = {
        prepare = "textDocument/prepareCallHierarchy",
        get_children = {
            callers = "callHierarchy/incomingCalls",
            callees = "callHierarchy/outgoingCalls",
        },
    },
    directions = {
        callers = { display_name = "Callers" },
        callees = { display_name = "Callees" },
    },
}

--- Prepares the root item for a call hierarchy request.
---@param client table The LSP client.
---@param winid number The window ID of the source buffer.
---@param callback function The function to call with the root item.
function call_hierarchy_strategy.prepare_root_item(client, winid, callback)
    winid = winid or 0
    local bufnr = vim.api.nvim_win_get_buf(winid)
    local encoding = util.lsp.get_encoding(client)
    local params = vim.lsp.util.make_position_params(winid, encoding)
    util.lsp.request_async(client, call_hierarchy_strategy.lsp_methods.prepare, params, bufnr, function(items)
        callback((items and items[1]) or nil)
    end)
end

--- Fetches the children of a call hierarchy item.
---@param client table The LSP client.
---@param item table The parent LSP item.
---@param direction_key string The direction to fetch ("callers" or "callees").
---@param callback function The function to call with the child items.
function call_hierarchy_strategy.fetch_children(client, item, direction_key, callback)
    local method = call_hierarchy_strategy.lsp_methods.get_children[direction_key]
    if not method then
        vim.notify("Invalid direction for call hierarchy: " .. direction_key, vim.log.levels.ERROR)
        return callback(nil)
    end
    local req_buf = (item.uri and vim.uri_to_bufnr(item.uri)) or 0
    if req_buf ~= 0 and not vim.api.nvim_buf_is_loaded(req_buf) then
        pcall(vim.fn.bufload, req_buf)
    end
    util.lsp.request_async(client, method, { item = item }, req_buf, function(results)
        if not results then return callback(nil) end
        local children_items = vim.tbl_map(function(result)
            return direction_key == "callers" and result.from or result.to
        end, results)
        callback(children_items)
    end)
end

--- Generates the help text for the call hierarchy view.
---@param mappings table The user's key mappings.
---@return string The formatted help text.
function call_hierarchy_strategy.generate_help_text(mappings)
    local dir_maps = {}
    -- Use display names from directions
    table.insert(dir_maps, string.format("[%s]%s", mappings.show_super_hierarchy, call_hierarchy_strategy.directions.callers.display_name))
    table.insert(dir_maps, string.format("[%s]%s", mappings.show_sub_hierarchy, call_hierarchy_strategy.directions.callees.display_name))
    return string.format("[%s]Jump | [%s]Toggle | %s | [%s]Quit", mappings.jump, mappings.toggle, table.concat(dir_maps, " | "), mappings.quit)
end

--- Renders a single line in the call hierarchy tree.
---@param node table The NuiTree node to render.
---@param hierarchy_instance table The Hierarchy instance.
---@return table The NuiLine object.
function call_hierarchy_strategy.render_node_line(node, hierarchy_instance)
    local cfg = get_config()
    local Line = require("nui.line")
    local Text = require("nui.text")
    local item = node.lsp_item
    local line = Line()

    line:append(string.rep("  ", math.max(0, node:get_depth() - 1)))

    if node.loading then
        local frame = cfg.icons.animation_frames[state.G.animation_frame_index] or cfg.icons.loading
        line:append(frame .. " ", "SpecialChar")
    elseif node:has_children() or node.has_more then
        line:append(node:is_expanded() and " " or " ", "SpecialChar")
    else
        line:append("  ")
    end

    local lsp_kind_to_name = {
        [6] = "method",
        [12] = "func",
        [13] = "variable",
    }
    local icons = cfg.hierarchies.call_hierarchy.icons
    local kind_name = lsp_kind_to_name[item.kind]
    local icon = item.is_placeholder and cfg.icons.placeholder or (kind_name and icons[kind_name] or icons.default)

    -- Try user-supplied custom renderer first
    local custom_line = util.try_custom_render(node, item, icon, hierarchy_instance)
    if custom_line then
        if node._filtered_out then
            local Line2 = require("nui.line")
            local Text2 = require("nui.text")
            local dimmed = Line2()
            dimmed:append(Text2(tostring(custom_line), "Comment"))
            return dimmed
        end
        return custom_line
    end

    if node._filtered_out then
        local dim_line = Line()
        dim_line:append(string.rep("  ", math.max(0, node:get_depth() - 1)) .. "  " .. icon .. " " .. item.name, "Comment")
        return dim_line
    end

    line:append(icon .. " ")
    line:append(item.name)

    if item.detail and item.detail ~= "" then
        line:append(" " .. item.detail, "Comment")
    end

    if node:get_depth() == 1 then
        local dir_info = call_hierarchy_strategy.directions[hierarchy_instance.direction_key]
        line:append(string.format(" [%s]", dir_info.display_name), "Comment")
    end

    if item.is_placeholder then return line end

    local file = item.uri and vim.uri_to_fname(item.uri)
    if file then
        local sel = (item.selectionRange and item.selectionRange.start) or (item.range and item.range.start)
        local rhs = ("  %s"):format(util.short_path(file))
        if sel then rhs = rhs .. (":" .. (sel.line + 1)) end
        line:append(" ")
        line:append(Text(rhs, "Comment"))
    end
    return line
end

return call_hierarchy_strategy
