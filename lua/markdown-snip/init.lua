local M = {}

local sync_buffers = {}
local current_code_buffer = nil

local function get_fence_info(bufnr, lnum)
  local parser = vim.treesitter.get_parser(bufnr, "markdown")
  if not parser then
    return nil
  end

  local tree = parser:parse()[1]
  local root = tree:root()

  local row = lnum - 1
  local col = vim.api.nvim_win_get_cursor(0)[2]

  local query = vim.treesitter.query.parse(
    "markdown",
    [[
    (fenced_code_block
      (fenced_code_block_delimiter) @start
      (code_fence_content) @content
      (fenced_code_block_delimiter) @end) @block
  ]]
  )

  for id, node, metadata in query:iter_captures(root, bufnr, 0, -1) do
    local capture_name = query.captures[id]
    if capture_name == "block" then
      local start_row, start_col, end_row, end_col = node:range()

      if row >= start_row and row <= end_row then
        local fence_start_row = start_row + 1
        local fence_end_row = end_row + 1

        local fence_line = vim.api.nvim_buf_get_lines(bufnr, start_row, start_row + 1, false)[1]

        return {
          fence_line = fence_line,
          start_line = fence_start_row,
          end_line = fence_end_row,
          content_start = fence_start_row + 1,
          content_end = fence_end_row - 1,
        }
      end
    end
  end

  return nil
end

local function get_extension_from_lang(fence)
  local lang = fence:match("^```(%w+)")
  if lang == "js" or lang == "javascript" then
    return ".js"
  elseif lang == "ts" or lang == "typescript" then
    return ".ts"
  elseif lang == "py" or lang == "python" then
    return ".py"
  elseif lang == "lua" then
    return ".lua"
  elseif lang == "html" then
    return ".html"
  elseif lang == "css" then
    return ".css"
  elseif lang == "json" then
    return ".json"
  else
    return ".txt"
  end
end

local function get_code_block_content(md_bufnr, fence_info)
  local parser = vim.treesitter.get_parser(md_bufnr, "markdown")
  if not parser then
    return {}
  end

  local tree = parser:parse()[1]
  local root = tree:root()

  local query = vim.treesitter.query.parse(
    "markdown",
    [[
    (fenced_code_block
      (code_fence_content) @content) @block
  ]]
  )

  for id, node, metadata in query:iter_captures(root, md_bufnr, 0, -1) do
    local capture_name = query.captures[id]
    if capture_name == "content" then
      local start_row, start_col, end_row, end_col = node:range()
      local content_start_line = start_row + 1
      local content_end_line = end_row + 1

      if content_start_line == fence_info.content_start then
        return vim.api.nvim_buf_get_lines(md_bufnr, start_row, end_row, false)
      end
    end
  end

  if fence_info.content_start > fence_info.content_end then
    return {}
  end
  return vim.api.nvim_buf_get_lines(md_bufnr, fence_info.content_start - 1, fence_info.content_end, false)
end

local function sync_to_markdown(code_bufnr, md_bufnr, fence_info)
  local code_lines = vim.api.nvim_buf_get_lines(code_bufnr, 0, -1, false)

  local md_lines = vim.api.nvim_buf_get_lines(md_bufnr, 0, -1, false)
  local closing_fence_line = fence_info.start_line

  for i = fence_info.start_line + 1, #md_lines do
    if md_lines[i]:match("^```$") then
      closing_fence_line = i
      break
    end
  end

  vim.api.nvim_buf_set_lines(md_bufnr, fence_info.content_start - 1, closing_fence_line - 1, false, code_lines)
end

local function get_link_under_cursor()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1

  for text, path in line:gmatch("%[([^%]]+)%]%(([^%)]+)%)") do
    local start_pos = line:find("%[" .. vim.pesc(text) .. "%]%(", 1, false)
    local end_pos = start_pos + #text + #path + 3
    if col >= start_pos and col <= end_pos then
      return path
    end
  end

  for path in line:gmatch("%[%[([^%]]+)%]%]") do
    local start_pos = line:find("%[%[" .. vim.pesc(path) .. "%]%]", 1, false)
    local end_pos = start_pos + #path + 3
    if col >= start_pos and col <= end_pos then
      return path
    end
  end

  for path in line:gmatch("@([%w%.%/%-%_]+)") do
    local start_pos = line:find("@" .. vim.pesc(path), 1, false)
    local end_pos = start_pos + #path
    if col >= start_pos and col <= end_pos then
      return path
    end
  end

  return nil
end

local function navigate_to_file(file_path)
  local current_dir = vim.fn.expand("%:p:h")
  local full_path

  if file_path:match("^%.") then
    full_path = vim.fn.resolve(current_dir .. "/" .. file_path)
  elseif file_path:match("^/") then
    full_path = file_path
  else
    full_path = vim.fn.resolve(current_dir .. "/" .. file_path)
  end

  if vim.fn.filereadable(full_path) == 1 then
    vim.cmd("edit " .. vim.fn.fnameescape(full_path))
  else
    vim.notify("File not found: " .. file_path, vim.log.levels.WARN)
  end
end

function M.goto_file()
  local md_bufnr = vim.api.nvim_get_current_buf()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]

  local link_path = get_link_under_cursor()
  if link_path then
    navigate_to_file(link_path)
    return
  end

  local fence_info = get_fence_info(md_bufnr, lnum)
  if not fence_info then
    return
  end
  local extension = get_extension_from_lang(fence_info.fence_line)

  if current_code_buffer and vim.api.nvim_buf_is_valid(current_code_buffer) then
    sync_buffers[current_code_buffer] = nil
    vim.api.nvim_buf_delete(current_code_buffer, { force = true })
  end

  local md_bufname = vim.api.nvim_buf_get_name(md_bufnr)
  local temp_file = md_bufname .. "~snippet" .. extension

  local code_content = get_code_block_content(md_bufnr, fence_info)

  vim.fn.writefile(code_content, temp_file)

  vim.cmd("edit " .. vim.fn.fnameescape(temp_file))
  local code_bufnr = vim.api.nvim_get_current_buf()

  vim.api.nvim_buf_set_option(code_bufnr, "bufhidden", "wipe")

  vim.api.nvim_create_autocmd("BufWritePost", {
    buffer = code_bufnr,
    callback = function(args)
      local sync_info = sync_buffers[args.buf]
      if sync_info and vim.api.nvim_buf_is_valid(sync_info.md_bufnr) then
        sync_to_markdown(args.buf, sync_info.md_bufnr, sync_info.fence_info)
        vim.api.nvim_buf_call(sync_info.md_bufnr, function()
          vim.cmd("write")
        end)
      end
    end,
  })

  vim.api.nvim_buf_set_keymap(code_bufnr, "n", "q", "<cmd>bd!<cr>", { noremap = true, silent = true })

  current_code_buffer = code_bufnr

  sync_buffers[code_bufnr] = {
    md_bufnr = md_bufnr,
    fence_info = fence_info,
  }

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    buffer = code_bufnr,
    callback = function()
      local sync_info = sync_buffers[code_bufnr]
      if sync_info and vim.api.nvim_buf_is_valid(sync_info.md_bufnr) then
        sync_to_markdown(code_bufnr, sync_info.md_bufnr, sync_info.fence_info)
      end
    end,
  })

  vim.api.nvim_create_autocmd("BufUnload", {
    buffer = code_bufnr,
    callback = function()
      sync_buffers[code_bufnr] = nil
      if current_code_buffer == code_bufnr then
        current_code_buffer = nil
      end
      if vim.fn.filereadable(temp_file) == 1 then
        vim.fn.delete(temp_file)
      end
    end,
  })
end

function M.insert_file_reference_snacks()
  require("snacks").picker.files({
    cwd = vim.fn.expand("%:p:h"),
    confirm = function(picker, item)
      picker:close()
      if item then
        local relative_path = vim.fn.fnamemodify(item.file, ":.")
        local filename = vim.fn.fnamemodify(item.file, ":t")
        local link_text = string.format("[%s](%s)", filename, relative_path)
        vim.api.nvim_put({ link_text }, "c", true, true)
      end
    end,
  })
end

return M