# markdown-snip.nvim

Enhanced editing of markdown code & linking files.

Useful for writing AI specs and documentation.

## Code Snippet Editing

Position cursor in a markdown code block and press `gd` to edit it in a dedicated buffer with full LSP support, auto-completion, and your project's configuration.

Buffer contents will be automatically synced with your markdown file.

![Code snippets editing](./doc/gd.gif)

## File Auto-completion

Auto-complete works for following syntax:

 - `[[path]]`
 - `[text](path)`
 - `@path` 

One of following commands are used: `fd`, `rg`, or `find`

![File auto-completion](./doc/cmp.gif)

---

See `examples/lazy-config.lua` for sample Lazy configuration.

If you use `blink.cmp` add omni to your default sources as shown in `examples/lazy-blink.lua`

