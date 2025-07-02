-- LazyVim plugin configuration for markdown-snip.nvim
-- Place this in your ~/.config/nvim/lua/plugins/markdown-snip.lua

return {
  "your-username/markdown-snip.nvim",
  ft = "markdown",
  config = function()
    -- Plugin is automatically loaded, no setup required
  end,
  keys = {
    {
      "gd",
      function()
        require("markdown-snip").goto_file()
      end,
      ft = "markdown",
      desc = "Go to file/code block under cursor",
    },
    {
      "<leader>mf",
      function()
        require("markdown-snip").insert_file_reference_snacks()
      end,
      ft = "markdown",
      desc = "Insert file reference using picker",
    },
  },
}