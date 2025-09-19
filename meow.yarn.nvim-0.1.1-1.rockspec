package = "meow.yarn.nvim"
rockspec_format = "3.0"
version = "0.1.1-1"
source = {
   url = "git+https://github.com/retran/meow.yarn.nvim.git",
   tag = "v0.1.1"
}
description = {
   summary = "A purr-fectly simple way to visualize LSP hierarchies in Neovim",
   detailed = [[
      meow.yarn.nvim provides a simple, beautiful, and interactive way to explore LSP hierarchies
      without the usual clutter. It visualizes type and call hierarchies in a clean, intuitive tree view.

      Features:
      - Interactive Tree View: Displays hierarchies in a clear, expandable tree
      - Type Hierarchy: Explore supertypes and subtypes of a class or type
      - Call Hierarchy: Navigate callers (incoming calls) and callees (outgoing calls) of a function
      - Live Preview: See the source code of the selected item in a live preview window
      - Built on Solid Foundations: Powered by Neovim's native LSP and nui.nvim
      - Configurable: Customize keymaps, window appearance, and more
      - Fast & Asynchronous: All LSP requests are handled asynchronously without blocking the UI
   ]],
   homepage = "https://github.com/retran/meow.yarn.nvim",
   license = "MIT",
   labels = { "neovim", "lsp", "hierarchy", "tree-view", "plugin" }
}
dependencies = {
   "lua >= 5.1",
   "nui.nvim"
}
build = {
   type = "builtin"
}
