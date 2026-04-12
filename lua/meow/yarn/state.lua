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
-- @file: lua/meow/yarn/state.lua
-- @brief: Global state management for meow.yarn.nvim plugin
-- @author: Andrew Vasilyev
-- @license: MIT

---@mod meow.yarn.state
---@brief This module manages the global state of the plugin.
local M = {}

---@class MeowYarnState
---@field active_hierarchies table<number, any> A map of buffer numbers to active hierarchy instances.
---@field animation_timer any|nil The timer for the loading animation.
---@field animation_frame_index number The current frame index for the loading animation.
---@field last_session { item: table, strategy_name: string, direction_key: string }|nil The last opened hierarchy session, for re-opening.
M.G = {
    active_hierarchies = {},
    animation_timer = nil,
    animation_frame_index = 1,
    last_session = nil,
}

return M
