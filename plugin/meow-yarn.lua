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
-- @file: plugin/meow-yarn.lua
-- @brief: Entry point for meow.yarn.nvim plugin - automatically loaded by Neovim
-- @author: Andrew Vasilyev
-- @license: MIT

-- Prevent loading the plugin multiple times
if vim.g.loaded_meow_yarn then
    return
end
vim.g.loaded_meow_yarn = 1

-- Check Neovim version compatibility
if vim.fn.has('nvim-0.8.0') == 0 then
    vim.api.nvim_err_writeln('meow.yarn.nvim requires Neovim >= 0.8.0')
    return
end

-- Defer dependency check until the plugin is actually used
local function check_dependencies()
    local has_nui, _ = pcall(require, 'nui.popup')
    if not has_nui then
        vim.api.nvim_err_writeln('meow.yarn.nvim requires nui.nvim (https://github.com/MunifTanjim/nui.nvim)')
        return false
    end
    return true
end

---@class MeowYarnSubcommand
---@field impl fun(args:string[], opts: table) The command implementation
---@field complete? fun(subcmd_arg_lead: string): string[] (optional) Command completions callback

---@type table<string, MeowYarnSubcommand>
local subcommand_tbl = {
    type = {
        impl = function(args, opts)
            if not check_dependencies() then return end
            local direction = args[1] or "super"
            local meow_yarn = require("meow.yarn")
            if direction == "super" then
                meow_yarn.open_tree("type_hierarchy", "supertypes")
            elseif direction == "sub" then
                meow_yarn.open_tree("type_hierarchy", "subtypes")
            else
                vim.notify("Invalid direction for type hierarchy. Use 'super' or 'sub'", vim.log.levels.ERROR)
            end
        end,
        complete = function(subcmd_arg_lead)
            local directions = { "super", "sub" }
            return vim.iter(directions)
                :filter(function(dir)
                    return dir:find(subcmd_arg_lead) ~= nil
                end)
                :totable()
        end,
    },
    call = {
        impl = function(args, opts)
            if not check_dependencies() then return end
            local direction = args[1] or "callers"
            local meow_yarn = require("meow.yarn")
            if direction == "callers" then
                meow_yarn.open_tree("call_hierarchy", "callers")
            elseif direction == "callees" then
                meow_yarn.open_tree("call_hierarchy", "callees")
            else
                vim.notify("Invalid direction for call hierarchy. Use 'callers' or 'callees'", vim.log.levels.ERROR)
            end
        end,
        complete = function(subcmd_arg_lead)
            local directions = { "callers", "callees" }
            return vim.iter(directions)
                :filter(function(dir)
                    return dir:find(subcmd_arg_lead) ~= nil
                end)
                :totable()
        end,
    },
}

---@param opts table :h lua-guide-commands-create
local function meow_yarn_cmd(opts)
    local fargs = opts.fargs
    local subcommand_key = fargs[1]

    if not subcommand_key then
        vim.notify("Usage: :MeowYarn <type|call> [super|sub|callers|callees]", vim.log.levels.ERROR)
        return
    end

    -- Get the subcommand's arguments, if any
    local args = #fargs > 1 and vim.list_slice(fargs, 2, #fargs) or {}
    local subcommand = subcommand_tbl[subcommand_key]

    if not subcommand then
        vim.notify("MeowYarn: Unknown command: " .. subcommand_key, vim.log.levels.ERROR)
        return
    end

    -- Invoke the subcommand
    subcommand.impl(args, opts)
end

-- Create the main command with proper completions
vim.api.nvim_create_user_command("MeowYarn", meow_yarn_cmd, {
    nargs = "+",
    desc = "Open hierarchy view (Usage: MeowYarn <type|call> [super|sub|callers|callees])",
    complete = function(arg_lead, cmdline, _)
        -- Get the subcommand
        local subcmd_key, subcmd_arg_lead = cmdline:match("^['<,'>]*MeowYarn[!]*%s(%S+)%s(.*)$")
        if subcmd_key
            and subcmd_arg_lead
            and subcommand_tbl[subcmd_key]
            and subcommand_tbl[subcmd_key].complete
        then
            -- The subcommand has completions. Return them.
            return subcommand_tbl[subcmd_key].complete(subcmd_arg_lead)
        end

        -- Check if cmdline is a subcommand
        if cmdline:match("^['<,'>]*MeowYarn[!]*%s+%w*$") then
            -- Filter subcommands that match
            local subcommand_keys = vim.tbl_keys(subcommand_tbl)
            return vim.iter(subcommand_keys)
                :filter(function(key)
                    return key:find(arg_lead) ~= nil
                end)
                :totable()
        end
    end,
})

-- Provide <Plug> mappings for common actions
vim.keymap.set("n", "<Plug>(MeowYarnTypeSuper)", function()
    if not check_dependencies() then return end
    require("meow.yarn").open_tree("type_hierarchy", "supertypes")
end, { desc = "Show type supertypes hierarchy" })

vim.keymap.set("n", "<Plug>(MeowYarnTypeSub)", function()
    if not check_dependencies() then return end
    require("meow.yarn").open_tree("type_hierarchy", "subtypes")
end, { desc = "Show type subtypes hierarchy" })

vim.keymap.set("n", "<Plug>(MeowYarnCallCallers)", function()
    if not check_dependencies() then return end
    require("meow.yarn").open_tree("call_hierarchy", "callers")
end, { desc = "Show call hierarchy callers" })

vim.keymap.set("n", "<Plug>(MeowYarnCallCallees)", function()
    if not check_dependencies() then return end
    require("meow.yarn").open_tree("call_hierarchy", "callees")
end, { desc = "Show call hierarchy callees" })

-- Initialize highlights and signs (this is minimal overhead)
vim.api.nvim_set_hl(0, "MeowYarnPreview", { link = "Visual", default = true })
vim.fn.sign_define("MeowYarnCursor", { text = "➜", texthl = "Question" })
