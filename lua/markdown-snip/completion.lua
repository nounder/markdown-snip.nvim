local M = {}

local function get_files_in_directory(dir, target_dir)
  local files = {}
  local search_dir = target_dir and (dir .. "/" .. target_dir) or dir

  if not vim.fn.isdirectory(search_dir) then
    return files
  end

  local cmd
  if vim.fn.executable("fd") == 1 then
    cmd = { "fd", "--type", "f", "." }
  elseif vim.fn.executable("rg") == 1 then
    cmd = { "rg", "--files" }
  elseif vim.fn.executable("find") == 1 then
    cmd = { "find", ".", "-type", "f" }
  else
    return files
  end

  local result = vim.system(cmd, { cwd = search_dir }):wait()
  if result.code == 0 then
    local file_list = vim.split(result.stdout, "\n", { trimempty = true })
    for _, file in ipairs(file_list) do
      local relative_path = file:gsub("^%./", "")
      table.insert(files, relative_path)
    end
  end

  return files
end

local function extract_directory_from_prefix(prefix)
  if prefix == "" then
    return nil
  end
  
  local dir_part = prefix:match("^([^/]+)/")
  if dir_part then
    return dir_part
  end
  
  return nil
end

local function get_current_context()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1
  local before_cursor = line:sub(1, col)
  local after_cursor = line:sub(col + 1)

  -- Check for @path pattern
  local at_match = before_cursor:match("@([%w%.%/%-%_]*)$")
  if at_match then
    return { type = "at", prefix = at_match, start_col = col - #at_match, has_closing = false }
  end

  -- Check for @ at end of line
  if before_cursor:match("@$") then
    return { type = "at", prefix = "", start_col = col, has_closing = false }
  end

  -- Check for [[path pattern
  local wiki_match = before_cursor:match("%[%[([^%]]*)$")
  if wiki_match then
    return { type = "wiki", prefix = wiki_match, start_col = col - #wiki_match, has_closing = false }
  end

  -- Check for [[ at end of line or followed by auto-inserted ]]
  if before_cursor:match("%[%[$") then
    return { type = "wiki", prefix = "", start_col = col, has_closing = false }
  end

  -- Handle auto-bracket case: check if we're inside [[ ]]
  if before_cursor:match("%[%[") and after_cursor:match("^%]%]") then
    local wiki_content = before_cursor:match("%[%[([^%]]*)$")
    if wiki_content then
      return { type = "wiki", prefix = wiki_content, start_col = col - #wiki_content, has_closing = true }
    else
      return { type = "wiki", prefix = "", start_col = col, has_closing = true }
    end
  end

  -- Handle case where cursor is inside [[content]] - before_cursor ends with ']'
  if before_cursor:match("%[%[.*%]$") and after_cursor:match("^%]$") then
    local wiki_content = before_cursor:match("%[%[([^%]]*)%]$")
    if wiki_content then
      return { type = "wiki", prefix = wiki_content, start_col = col - #wiki_content, has_closing = true }
    end
  end

  -- Check for [text](path pattern - handle both [text](path) and [text](path
  local link_text, link_path = before_cursor:match("%[([^%]]*)%]%(([^%)]*)%)$")
  if link_path then
    return { type = "link", prefix = link_path, start_col = col - #link_path, has_closing = true }
  end

  -- Check for [text](path pattern without closing )
  local link_text2, link_path2 = before_cursor:match("%[([^%]]*)%]%(([^%)]*)$")
  if link_path2 then
    return { type = "link", prefix = link_path2, start_col = col - #link_path2, has_closing = false }
  end

  -- Check for [text]( at end of line or followed by auto-inserted )
  if before_cursor:match("%[[^%]]*%]%($") then
    return { type = "link", prefix = "", start_col = col, has_closing = false }
  end

  -- Handle auto-bracket case: check if we're inside [text]( )
  if before_cursor:match("%[[^%]]*%]%(") and after_cursor:match("^%)") then
    local link_content = before_cursor:match("%[[^%]]*%]%(([^%)]*)$")
    if link_content then
      return { type = "link", prefix = link_content, start_col = col - #link_content, has_closing = true }
    else
      return { type = "link", prefix = "", start_col = col, has_closing = true }
    end
  end

  -- Handle case where cursor is inside [text](content) - before_cursor ends with ')'
  if before_cursor:match("%[[^%]]*%]%(.*%)$") and after_cursor:match("^%)$") then
    local link_content = before_cursor:match("%[[^%]]*%]%(([^%)]*)%)$")
    if link_content then
      return { type = "link", prefix = link_content, start_col = col - #link_content, has_closing = true }
    end
  end

  return nil
end

-- Standard omnifunc for universal completion support
function M.omnifunc(findstart, base)
  if findstart == 1 then
    -- Find the start of the completion
    local context = get_current_context()
    if context then
      return context.start_col - 1 -- Convert to 0-based for vim
    end
    return -1                      -- No completion
  else
    -- Return completion items
    local context = get_current_context()
    if not context then
      return {}
    end

    local cwd = vim.fn.expand("%:p:h")
    local target_dir = extract_directory_from_prefix(context.prefix)
    local files = get_files_in_directory(cwd, target_dir)
    local items = {}

    local search_base = base
    if target_dir then
      search_base = base:gsub("^" .. vim.pesc(target_dir .. "/"), "")
    end

    for _, file in ipairs(files) do
      local display_path = file
      if target_dir then
        display_path = target_dir .. "/" .. file
      end
      
      if search_base == "" or file:lower():find(search_base:lower(), 1, true) then
        table.insert(items, {
          word = display_path,
          abbr = display_path,
          kind = "File",
          info = "File: " .. display_path,
        })
      end
    end

    return items
  end
end

function M.resolve(item, callback)
  local file_path = item.data and item.data.file_path
  if file_path then
    local full_path = vim.fn.resolve(vim.fn.expand("%:p:h") .. "/" .. file_path)
    if vim.fn.filereadable(full_path) == 1 then
      local content = vim.fn.readfile(full_path, "", 10)
      item.documentation = {
        kind = "markdown",
        value = "**" .. file_path .. "**\n\n```\n" .. table.concat(content, "\n") .. "\n```"
      }
    end
  end
  callback(item)
end

function M.get_trigger_characters()
  return { "@", "[" }
end

function M.should_show_completion(context)
  local current_context = get_current_context()
  return current_context ~= nil
end

return M
