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
-- @file: lua/meow/yarn/hierarchy.lua
-- @brief: The main class for managing a hierarchy view, including the UI and state
-- @author: Andrew Vasilyev
-- @license: MIT

---@mod meow.yarn.hierarchy
---@brief The main class for managing a hierarchy view, including the UI and state.

local get_config = function() return require("meow.yarn.config.internal").get() end
local state = require("meow.yarn.state")
local util = require("meow.yarn.util")
local animation = require("meow.yarn.animation")

local Hierarchy = {}
Hierarchy.__index = Hierarchy

--- Creates a new Hierarchy instance.
---@param client table The LSP client.
---@param root_item table The root item of the hierarchy.
---@param strategy table The strategy to use for this hierarchy.
---@param direction_key string The initial direction (e.g., "supertypes", "callers").
---@return table The new Hierarchy instance.
function Hierarchy:new(client, root_item, strategy, direction_key)
    local cfg = get_config()
    local instance = setmetatable({}, Hierarchy)
    instance.client = client
    instance.strategy = strategy
    instance.direction_key = direction_key
    instance.active_requests = {}

    local help_text = instance.strategy.generate_help_text(cfg.mappings)

    instance.tree_popup = require("nui.popup")({
        enter = true,
        focusable = true,
        border = {
            style = cfg.window.border,
            text = {
                bottom = help_text,
                bottom_align = "center",
            },
        },
        win_options = {
            winhighlight = "Normal:Normal,FloatBorder:Normal",
            cursorline = true,
            signcolumn = "yes",
        },
    })
    instance.preview_popup = require("nui.popup")({
        focusable = false,
        border = { style = "rounded" },
        buf_options = { modifiable = false, readonly = true, buflisted = false },
        win_options = { number = true, relativenumber = true, cursorline = false },
    })
    instance.layout = instance:_create_layout()

    local Node = require("nui.tree").Node
    local get_item_key = instance.strategy.get_item_key or util.default_key_from_item
    local root_node_obj = Node({
        id = get_item_key(root_item),
        text = root_item.name,
        lsp_item = root_item,
        dir_key = direction_key,
        fetched = false,
        loading = root_item.is_placeholder or false,
        has_more = true,
    })

    instance.tree = require("nui.tree")({
        bufnr = instance.tree_popup.bufnr,
        winid = instance.tree_popup.winid,
        nodes = { root_node_obj },
        prepare_node = function(node)
            return instance.strategy.render_node_line(node, instance)
        end,
    })
    state.G.active_hierarchies[instance.tree.bufnr] = instance
    animation.manage_animation_timer()
    return instance
end

--- Checks if the hierarchy's window is still valid.
---@return boolean
function Hierarchy:is_valid()
    return self.tree_popup and self.tree_popup.winid and vim.api.nvim_win_is_valid(self.tree_popup.winid)
end

--- Mounts the hierarchy UI and sets up autocommands and keymaps.
function Hierarchy:mount()
    self.autocmd_group = vim.api.nvim_create_augroup("MeowYarn_" .. self.tree_popup.bufnr, {})
    self.layout:mount()
    self:_setup_keymaps()
    self:_setup_preview()
    self:_setup_cleanup()
    self.tree:render()
end

--- Unmounts the hierarchy UI and cleans up resources.
function Hierarchy:unmount()
    if not self:is_valid() then
        return
    end
    for _, request_id in pairs(self.active_requests) do
        self.client.cancel_request(request_id)
    end
    self.active_requests = {}
    if self.autocmd_group then
        pcall(vim.api.nvim_del_augroup_by_id, self.autocmd_group)
        self.autocmd_group = nil
    end
    if self.debounce_timer then
        vim.fn.timer_stop(self.debounce_timer)
    end
    pcall(self.layout.unmount, self.layout)
    state.G.active_hierarchies[self.tree.bufnr] = nil
    animation.manage_animation_timer()
end

--- Resets the hierarchy to a new root item and direction.
---@param root_item table The new root LSP item.
---@param direction_key string The new direction key.
function Hierarchy:reset(root_item, direction_key)
    for _, request_id in pairs(self.active_requests) do
        self.client.cancel_request(request_id)
    end
    self.active_requests = {}
    self.direction_key = direction_key

    local Node = require("nui.tree").Node
    local get_item_key = self.strategy.get_item_key or util.default_key_from_item
    local new_root_node = Node({
        id = get_item_key(root_item),
        text = root_item.name,
        lsp_item = root_item,
        dir_key = direction_key,
        fetched = false,
        loading = false,
        has_more = true,
    })
    self.tree:set_nodes({ new_root_node })

    if self:is_valid() then
        vim.api.nvim_win_set_cursor(self.tree_popup.winid, { 1, 0 })
    end
    vim.schedule(function()
        if self:is_valid() then
            local cfg = get_config()
            self:update_node(new_root_node, cfg.expand_depth)
        end
    end)
end

--- Creates the Nui layout for the hierarchy and preview windows.
---@return table The NuiLayout instance.
function Hierarchy:_create_layout()
    local cfg = get_config()
    local w, h = cfg.window.width, cfg.window.height
    if w <= 1 then
        w = math.floor(vim.o.columns * w)
    end
    if h <= 1 then
        h = math.floor(vim.o.lines * h)
    end
    local Layout = require("nui.layout")
    local preview_height = string.format("%d%%", cfg.window.preview_height_ratio * 100)
    local tree_height = string.format("%d%%", (1 - cfg.window.preview_height_ratio) * 100)
    return Layout({ position = "50%", size = { width = w, height = h }, relative = "editor" },
        Layout.Box({ Layout.Box(self.tree_popup, { size = tree_height }), Layout.Box(self.preview_popup, { size = preview_height }) }, { dir = "col" }))
end

--- Sets up the keymaps for the hierarchy window.
function Hierarchy:_setup_keymaps()
    local cfg = get_config()
    local bufnr = self.tree.bufnr
    local map = function(lhs, rhs, desc)
        vim.keymap.set("n", lhs, rhs, { buffer = bufnr, nowait = true, silent = true, desc = "MeowYarn: " .. desc })
    end

    map(cfg.mappings.quit, function() self:unmount() end, "Quit")
    map(cfg.mappings.jump, function()
        local node = self.tree:get_node()
        if node and node.lsp_item and not node.lsp_item.is_placeholder then
            local item_to_jump = node.lsp_item
            self:unmount()
            util.jump_to_item(item_to_jump, self.client)
        end
    end, "Jump to definition")

    local expand_action = function(expand_only)
        return function()
            local node = self.tree:get_node()
            if not node or (node.lsp_item and node.lsp_item.is_placeholder) then return end
            if expand_only and node:is_expanded() then return end
            self:update_node(node, 1)
        end
    end
    map(cfg.mappings.toggle, expand_action(false), "Toggle expand/collapse")
    map(cfg.mappings.expand, expand_action(true), "Expand")
    map(cfg.mappings.expand_alt, expand_action(true), "Expand (alt)")
    map(cfg.mappings.collapse, function() local n = self.tree:get_node() if n then n:collapse() self.tree:render() end end, "Collapse")
    map(cfg.mappings.collapse_alt, function() local n = self.tree:get_node() if n then n:collapse() self.tree:render() end end, "Collapse (alt)")

    local function switch_direction(new_direction_key)
        local node = self.tree:get_node()
        if node and node.lsp_item and not node.lsp_item.is_placeholder then
            self:reset(node.lsp_item, new_direction_key)
        end
    end

    map(cfg.mappings.show_sub_hierarchy, function()
        local current_dir = self.direction_key
        if current_dir == "supertypes" then
            switch_direction("subtypes")
        elseif current_dir == "callers" then
            switch_direction("callees")
        end
    end, "Show Sub-Hierarchy")

    map(cfg.mappings.show_super_hierarchy, function()
        local current_dir = self.direction_key
        if current_dir == "subtypes" then
            switch_direction("supertypes")
        elseif current_dir == "callees" then
            switch_direction("callers")
        end
    end, "Show Super-Hierarchy")
end


--- Fetches children for a node and updates the tree.
---@param node table The NuiTree node to update.
---@param depth number The depth to recursively expand.
function Hierarchy:update_node(node, depth)
    depth = depth or 1
    if not node or node.loading or (node.lsp_item and node.lsp_item.is_placeholder) then
        return
    end

    if node.fetched then
        if node:is_expanded() then
            node:collapse()
        else
            node:expand()
        end
        self.tree:render()
        return
    end

    node.loading = true
    self.tree:render()

    local node_id = node:get_id()
    self.active_requests[node_id] = self.strategy.fetch_children(self.client, node.lsp_item, self.direction_key, function(children)
        self.active_requests[node_id] = nil
        if not self:is_valid() then return end
        local parent = self.tree:get_node(node_id)
        if not parent then return end

        parent.loading = false
        parent.fetched = true
        parent.has_more = (type(children) == "table") and (#children > 0)

        local Node = require("nui.tree").Node
        local get_item_key = self.strategy.get_item_key or util.default_key_from_item
        local child_nodes = {}
        if parent.has_more then
            for _, child_item in ipairs(children) do
                local base_id = get_item_key(child_item)
                local path_dependent_id = node_id .. "->" .. base_id
                table.insert(child_nodes, Node({
                    id = util.unique_id_for(self.tree, path_dependent_id),
                    text = child_item.name,
                    lsp_item = child_item,
                    dir_key = parent.dir_key,
                    fetched = false,
                    loading = false,
                    has_more = true,
                }))
            end
        end
        self.tree:set_nodes(child_nodes, node_id)
        if not parent:is_expanded() then parent:expand() end
        self.tree:render()

        if depth > 1 and parent.has_more then
            for _, child_node in ipairs(self.tree:get_nodes(parent:get_id())) do
                vim.schedule(function()
                    if self:is_valid() then
                        self:update_node(child_node, depth - 1)
                    end
                end)
            end
        end
    end)
end

--- Sets up autocommands for cleaning up the hierarchy window.
function Hierarchy:_setup_cleanup()
    vim.api.nvim_create_autocmd({ "BufWipeout" }, {
        group = self.autocmd_group,
        buffer = self.tree.bufnr,
        once = true,
        callback = function() self:unmount() end,
    })
end

--- Sets up the preview window and its autocommands.
function Hierarchy:_setup_preview()
    local K = require("meow.yarn.util").K
    local preview_ns = vim.api.nvim_create_namespace(K.PREVIEW_NAMESPACE)
    local update_preview = function()
        local node = self.tree:get_node()
        if not (self:is_valid() and node and node.lsp_item and node.lsp_item.uri and not node.lsp_item.is_placeholder) then
            return
        end
        local pbuf = self.preview_popup.bufnr
        if not (pbuf and vim.api.nvim_buf_is_valid(pbuf)) then
            return
        end
        pcall(function()
            local lsp_item = node.lsp_item
            local source_bufnr = vim.uri_to_bufnr(lsp_item.uri)
            if not vim.api.nvim_buf_is_loaded(source_bufnr) then
                vim.fn.bufload(source_bufnr)
            end
            vim.bo[pbuf].filetype = vim.bo[source_bufnr].filetype
            local start_line_0 = (lsp_item.selectionRange or lsp_item.range).start.line
            local cfg = get_config()
            local ctx = cfg.preview_context_lines
            local first_line = math.max(0, start_line_0 - ctx)
            local last_line = math.min(vim.api.nvim_buf_line_count(source_bufnr), start_line_0 + ctx + 1)
            local lines = vim.api.nvim_buf_get_lines(source_bufnr, first_line, last_line, false)

            vim.api.nvim_buf_set_option(pbuf, "readonly", false)
            vim.api.nvim_buf_set_option(pbuf, "modifiable", true)
            vim.api.nvim_buf_clear_namespace(pbuf, preview_ns, 0, -1)
            vim.api.nvim_buf_set_lines(pbuf, 0, -1, false, lines)
            local highlight_line = start_line_0 - first_line
            vim.api.nvim_buf_add_highlight(pbuf, preview_ns, K.HIGHLIGHT_GROUP, highlight_line, 0, -1)
            vim.api.nvim_buf_set_option(pbuf, "modifiable", false)
            vim.api.nvim_buf_set_option(pbuf, "readonly", true)
            vim.api.nvim_win_set_cursor(self.preview_popup.winid, { highlight_line + 1, 0 })
            vim.api.nvim_win_call(self.preview_popup.winid, function() vim.cmd("normal! zt") end)
        end)
    end
    local update_cursor_sign = function()
        if not self:is_valid() then return end
        local bufnr = self.tree.bufnr
        local linenr = vim.api.nvim_win_get_cursor(self.tree_popup.winid)[1]
        vim.fn.sign_unplace(K.SIGN_GROUP, { buffer = bufnr })
        vim.fn.sign_place(0, K.SIGN_GROUP, K.SIGN_CURSOR_NAME, bufnr, { lnum = linenr })
    end
    local on_cursor_moved = function()
        update_cursor_sign()
        if self.debounce_timer then vim.fn.timer_stop(self.debounce_timer) end
        self.debounce_timer = vim.fn.timer_start(100, function() vim.schedule(update_preview) end)
    end
    vim.api.nvim_create_autocmd("CursorMoved",
        { group = self.autocmd_group, buffer = self.tree.bufnr, callback = on_cursor_moved })
    vim.schedule(function()
        if self:is_valid() then
            update_cursor_sign()
            update_preview()
        end
    end)
end

return Hierarchy
