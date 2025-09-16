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
-- @file: lua/meow/yarn/strategies/type.lua
-- @brief: Strategy for handling LSP type hierarchies
-- @author: Andrew Vasilyev
-- @license: MIT

---@mod meow.yarn.strategies.type
---@brief Strategy for handling LSP type hierarchies.

local get_config = function() return require("meow.yarn.config.internal").get() end
local state = require("meow.yarn.state")
local util = require("meow.yarn.util")

local type_hierarchy_strategy = {
    name = "Type Hierarchy",
    lsp_capability = "typeHierarchyProvider",
    lsp_methods = {
        prepare = "textDocument/prepareTypeHierarchy",
        get_children = {
            supertypes = "typeHierarchy/supertypes",
            subtypes = "typeHierarchy/subtypes",
        },
    },
    directions = {
        supertypes = { display_name = "Super" },
        subtypes = { display_name = "Sub" },
    },
}

--- Prepares the root item for a type hierarchy request.
---@param client table The LSP client.
---@param winid number The window ID of the source buffer.
---@param callback function The function to call with the root item.
function type_hierarchy_strategy.prepare_root_item(client, winid, callback)
    winid = winid or 0
    local bufnr = vim.api.nvim_win_get_buf(winid)
    local encoding = util.lsp.get_encoding(client)
    local params = vim.lsp.util.make_position_params(winid, encoding)
    util.lsp.request_async(client, type_hierarchy_strategy.lsp_methods.prepare, params, bufnr, function(items)
        callback((items and items[1]) or nil)
    end)
end

--- Fetches the children of a type hierarchy item.
---@param client table The LSP client.
---@param item table The parent LSP item.
---@param direction_key string The direction to fetch ("supertypes" or "subtypes").
---@param callback function The function to call with the child items.
function type_hierarchy_strategy.fetch_children(client, item, direction_key, callback)
    local method = type_hierarchy_strategy.lsp_methods.get_children[direction_key]
    if not method then
        vim.notify("Invalid direction for type hierarchy: " .. direction_key, vim.log.levels.ERROR)
        return callback(nil)
    end
    local req_buf = (item.uri and vim.uri_to_bufnr(item.uri)) or 0
    if req_buf ~= 0 and not vim.api.nvim_buf_is_loaded(req_buf) then
        pcall(vim.fn.bufload, req_buf)
    end
    util.lsp.request_async(client, method, { item = item }, req_buf, callback)
end

--- Generates the help text for the type hierarchy view.
---@param mappings table The user's key mappings.
---@return string The formatted help text.
function type_hierarchy_strategy.generate_help_text(mappings)
    local dir_maps = {}
    -- Use display names from directions
    table.insert(dir_maps, string.format("[%s]%s", mappings.show_super_hierarchy, type_hierarchy_strategy.directions.supertypes.display_name))
    table.insert(dir_maps, string.format("[%s]%s", mappings.show_sub_hierarchy, type_hierarchy_strategy.directions.subtypes.display_name))
    return string.format("[%s]Jump | [%s]Toggle | %s | [%s]Quit", mappings.jump, mappings.toggle, table.concat(dir_maps, " | "), mappings.quit)
end

--- Renders a single line in the type hierarchy tree.
---@param node table The NuiTree node to render.
---@param hierarchy_instance table The Hierarchy instance.
---@return table The NuiLine object.
function type_hierarchy_strategy.render_node_line(node, hierarchy_instance)
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
        line:append(node:is_expanded() and " " or " ", "SpecialChar")
    else
        line:append("  ")
    end

    local SYMBOL_KIND = { Class = 5, Struct = 11, Interface = 23 }
    local icons = cfg.hierarchies.type_hierarchy.icons
    local icon_map = { [SYMBOL_KIND.Class] = icons.class, [SYMBOL_KIND.Struct] = icons.struct, [SYMBOL_KIND.Interface] = icons.interface }
    local icon = item.is_placeholder and cfg.icons.placeholder or (icon_map[item.kind] or icons.default)
    line:append(icon .. " ")
    line:append(item.name)

    if node:get_depth() == 1 then
        local dir_info = type_hierarchy_strategy.directions[hierarchy_instance.direction_key]
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

return type_hierarchy_strategy
