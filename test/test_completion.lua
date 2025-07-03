-- Comprehensive test suite for markdown-snip.nvim
local function print_test_result(test_name, passed, message)
  local status = passed and "PASS" or "FAIL"
  print(string.format("[%s] %s: %s", status, test_name, message or ""))
end

local function setup_plugin()
  local plugin_path = vim.fn.getcwd()
  vim.opt.runtimepath:prepend(plugin_path)
  
  local ok, markdown_snip = pcall(require, "markdown-snip")
  if not ok then
    print_test_result("Plugin Loading", false, "Failed to load markdown-snip plugin")
    return nil, nil
  end
  
  local completion_ok, completion = pcall(require, "markdown-snip.completion")
  if not completion_ok then
    print_test_result("Completion Loading", false, "Failed to load completion module")
    return nil, nil
  end
  
  print_test_result("Plugin Loading", true, "Successfully loaded plugin")
  return markdown_snip, completion
end

local function create_test_files()
  local plugin_path = vim.fn.getcwd()
  local test_files = { "test1.md", "test2.js", "README.md", "docs.txt" }
  
  for _, filename in ipairs(test_files) do
    local filepath = plugin_path .. "/" .. filename
    vim.fn.writefile({ "# Test file: " .. filename }, filepath)
  end
  
  return test_files
end

local function cleanup_test_files(test_files)
  local plugin_path = vim.fn.getcwd()
  for _, filename in ipairs(test_files) do
    local filepath = plugin_path .. "/" .. filename
    if vim.fn.filereadable(filepath) == 1 then
      vim.fn.delete(filepath)
    end
  end
end

local function test_completion_patterns(completion)
  print("\n=== Testing Completion Patterns ===")
  
  -- Create test markdown buffer
  vim.cmd("new test_completion.md")
  vim.bo.filetype = "markdown"
  vim.bo.omnifunc = "v:lua.require'markdown-snip.completion'.omnifunc"
  
  local test_cases = {
    -- @ pattern tests
    { content = "Link to @test", cursor_pos = 11, pattern = "@", desc = "@ pattern completion" },
    { content = "Link to @", cursor_pos = 9, pattern = "@", desc = "@ pattern at end" },
    
    -- [[ pattern tests  
    { content = "Wiki link [[README", cursor_pos = 18, pattern = "[[", desc = "[[ pattern completion" },
    { content = "Wiki link [[README]]", cursor_pos = 18, pattern = "[[", desc = "[[ pattern with closing brackets" },
    { content = "Wiki link [[", cursor_pos = 12, pattern = "[[", desc = "[[ pattern at end" },
    
    -- [text]( pattern tests
    { content = "[text](test", cursor_pos = 11, pattern = "[text](", desc = "[text]( pattern completion" },
    { content = "[text](test)", cursor_pos = 11, pattern = "[text](", desc = "[text]( pattern with closing parenthesis" },
    { content = "[text](", cursor_pos = 7, pattern = "[text](", desc = "[text]( pattern at end" },
    
    -- Negative test
    { content = "Normal text", cursor_pos = 6, pattern = "none", desc = "No pattern in normal text" },
  }
  
  for i, case in ipairs(test_cases) do
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { case.content })
    vim.api.nvim_win_set_cursor(0, { 1, case.cursor_pos })
    
    local findstart_result = completion.omnifunc(1, "")
    local should_find = case.pattern ~= "none"
    local found_pattern = findstart_result >= 0
    
    print_test_result(case.desc, found_pattern == should_find, 
      string.format("Expected %s, got findstart=%d", should_find and "pattern" or "no pattern", findstart_result))
    
    if found_pattern and should_find then
      local completions = completion.omnifunc(0, "")
      print_test_result(case.desc .. " - completions", #completions > 0, 
        string.format("Found %d completions", #completions))
      
      -- Verify no closing brackets are added
      if #completions > 0 then
        local has_closing_brackets = false
        for _, comp in ipairs(completions) do
          if comp.word and (comp.word:find("]]") or comp.word:find("%)")) then
            has_closing_brackets = true
            break
          end
        end
        print_test_result(case.desc .. " - no closing brackets", not has_closing_brackets,
          "Completions should not include closing brackets")
      end
    end
  end
  
  vim.cmd("bd!")
end

local function test_cursor_positioning(markdown_snip)
  print("\n=== Testing Cursor Positioning ===")
  
  -- Check if test file exists
  local plugin_path = vim.fn.getcwd()
  local test_file = plugin_path .. "/test/fixture_test_cursor_positioning.md"
  
  if vim.fn.filereadable(test_file) == 0 then
    print_test_result("Cursor Positioning", false, "Test fixture not found: " .. test_file)
    return
  end
  
  vim.cmd("edit " .. vim.fn.fnameescape(test_file))
  local md_bufnr = vim.api.nvim_get_current_buf()
  
  -- Test positioning in first code block (line 9)
  vim.api.nvim_win_set_cursor(0, { 9, 10 })
  markdown_snip.goto_file()
  
  local code_bufnr = vim.api.nvim_get_current_buf()
  local switched_buffer = code_bufnr ~= md_bufnr
  print_test_result("Cursor Positioning - Buffer Switch", switched_buffer, "Switched to code buffer")
  
  if switched_buffer then
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    local expected_line = 4 -- Should be line 4 in the code block
    local line_correct = cursor_pos[1] == expected_line
    print_test_result("Cursor Positioning - Line Position", line_correct, 
      string.format("Expected line %d, got %d", expected_line, cursor_pos[1]))
    
    vim.cmd("bd!")
  end
end

local function test_file_navigation(markdown_snip)
  print("\n=== Testing File Navigation ===")
  
  -- Create test markdown with file references
  vim.cmd("new test_navigation.md")
  local test_content = {
    "# Test Navigation",
    "",
    "Link to [README](README.md)",
    "Wiki link [[test1.md]]",
    "At reference @test2.js",
  }
  vim.api.nvim_buf_set_lines(0, 0, -1, false, test_content)
  vim.bo.filetype = "markdown"
  
  -- Test navigation to existing file
  vim.api.nvim_win_set_cursor(0, { 3, 20 }) -- Position on "README.md"
  local initial_buffer = vim.api.nvim_get_current_buf()
  
  markdown_snip.goto_file()
  
  local current_buffer = vim.api.nvim_get_current_buf()
  local navigated = current_buffer ~= initial_buffer
  print_test_result("File Navigation", navigated, "Successfully navigated to file")
  
  if navigated then
    local current_file = vim.api.nvim_buf_get_name(current_buffer)
    local is_readme = current_file:match("README%.md$") ~= nil
    print_test_result("File Navigation - Correct File", is_readme, "Opened README.md")
  end
  
  vim.cmd("bd!")
  vim.cmd("bd!")
end

-- Main test runner
local function run_comprehensive_tests()
  print("=== Markdown-Snip Comprehensive Test Suite ===")
  
  local markdown_snip, completion = setup_plugin()
  if not markdown_snip or not completion then
    return false
  end
  
  local test_files = create_test_files()
  
  test_completion_patterns(completion)
  test_cursor_positioning(markdown_snip)
  test_file_navigation(markdown_snip)
  
  cleanup_test_files(test_files)
  
  print("\n=== Test Suite Complete ===")
  return true
end

-- Run the tests
run_comprehensive_tests()