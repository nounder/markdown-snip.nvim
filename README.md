# markdown-snip.nvim

Enhanced editing of markdown code & linking files.

Useful for writing AI specs and documentation.

## Code Snippet Editing

Position cursor in a markdown code block and press `gd` to edit it in a dedicated buffer with full LSP support, auto-completion, and your project's configuration.

## File Auto-completion

Type `[[path]]`, `[text](path)`, or `@path` to trigger file completion from your project directory using `fd`, `rg`, or `find` (respects `.gitignore`).

