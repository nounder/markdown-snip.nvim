-- Lazy plugin configuration for markdown-snip.nvim
-- Place this ~/.config/nvim/lua/plugins/markdown-snip.lua

return {
	"nounder/markdown-snip.nvim",
	ft = "markdown",
	init = function()
		require("markdown-snip").setup_completion()
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
				require("markdown-snip").insert_file_reference()
			end,
			ft = "markdown",
			desc = "Insert file reference using picker",
		},
	},
}
