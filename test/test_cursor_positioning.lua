-- Test script to verify cursor positioning functionality in markdown-snip.nvim
-- This script should be run in a clean Neovim instance

local function print_test_result(test_name, passed, message)
  local status = passed and "PASS" or "FAIL"
  print(string.format("[%s] %s: %s", status, test_name, message or ""))
end

local function run_cursor_positioning_test()
  -- Add the plugin to runtimepath (assuming we're in the plugin directory)
  local plugin_path = vim.fn.getcwd()
  vim.opt.runtimepath:prepend(plugin_path)
  
  -- Load the plugin
  local ok, markdown_snip = pcall(require, "markdown-snip")
  if not ok then
    print_test_result("TEST Plugin Loading", false, "Failed to load markdown-snip plugin: " .. tostring(markdown_snip))
    return false
  end
  print_test_result("TEST Plugin Loading", true, "Successfully loaded markdown-snip")
  
  -- Open the test markdown file
  local test_file = plugin_path .. "/test/fixture_test_cursor_positioning.md"
  if vim.fn.filereadable(test_file) == 0 then
    print_test_result("TEST File", false, "Test file not found: " .. test_file)
    return false
  end
  
  vim.cmd("edit " .. vim.fn.fnameescape(test_file))
  local md_bufnr = vim.api.nvim_get_current_buf()
  print_test_result("TEST File", true, "Opened test markdown file")
  print("")
  
  -- Test 1: Position cursor on line 9 (middle of first code block)
  -- This should be "  local x = 42" which is line 4 within the lua code block
  vim.api.nvim_win_set_cursor(0, {9, 10}) -- Line 9, column 10
  local cursor_before = vim.api.nvim_win_get_cursor(0)
  print(string.format("Test 1 - Cursor position before goto_file: line %d, col %d", cursor_before[1], cursor_before[2]))
  
  -- Call goto_file
  markdown_snip.goto_file()
  
  -- Verify we're in a new buffer (code buffer)
  local code_bufnr = vim.api.nvim_get_current_buf()
  local is_different_buffer = code_bufnr ~= md_bufnr
  print_test_result("TEST Buffer Switch", is_different_buffer, "Switched to code buffer: " .. tostring(code_bufnr))
  
  if is_different_buffer then
    -- Check cursor position in code buffer
    local cursor_after = vim.api.nvim_win_get_cursor(0)
    local expected_line = 4 -- "local x = 42" is line 4 in the code block
    local expected_col = 10 -- Same column position
    
    print(string.format("Test 1 - Cursor position after goto_file: line %d, col %d", cursor_after[1], cursor_after[2]))
    print(string.format("Test 1 - Expected position: line %d, col %d", expected_line, expected_col))
    
    local line_correct = cursor_after[1] == expected_line
    local col_correct = cursor_after[2] == expected_col
    
    print_test_result("TEST Line Position", line_correct, string.format("Expected %d, got %d", expected_line, cursor_after[1]))
    print_test_result("TEST Column Position", col_correct, string.format("Expected %d, got %d", expected_col, cursor_after[2]))
    
    -- Get the current line content to verify we're at the right place
    local current_line = vim.api.nvim_get_current_line()
    local expected_content = "  local x = 42"
    local content_correct = current_line == expected_content
    print_test_result("TEST Line Content", content_correct, string.format("Expected '%s', got '%s'", expected_content, current_line))
    
    -- Close the code buffer
    vim.cmd("bd!")
  end
  print("")
  
  -- Test 2: Position cursor on line 21 (middle of second code block)  
  -- This should be "  console.log("This is line 3 of JS block");" which is line 3 within the JS code block
  vim.api.nvim_win_set_cursor(0, {21, 5}) -- Line 21, column 5
  local cursor_before_2 = vim.api.nvim_win_get_cursor(0)
  print(string.format("Test 2 - Cursor position before goto_file: line %d, col %d", cursor_before_2[1], cursor_before_2[2]))
  
  -- Call goto_file again
  markdown_snip.goto_file()
  
  -- Verify we're in a new buffer again
  local code_bufnr_2 = vim.api.nvim_get_current_buf()
  local is_different_buffer_2 = code_bufnr_2 ~= md_bufnr
  print_test_result("TEST Buffer Switch 2", is_different_buffer_2, "Switched to JS code buffer: " .. tostring(code_bufnr_2))
  
  if is_different_buffer_2 then
    -- Check cursor position in JS code buffer
    local cursor_after_2 = vim.api.nvim_win_get_cursor(0)
    local expected_line_2 = 3 -- "console.log..." is line 3 in the JS code block
    local expected_col_2 = 5 -- Same column position
    
    print(string.format("Test 2 - Cursor position after goto_file: line %d, col %d", cursor_after_2[1], cursor_after_2[2]))
    print(string.format("Test 2 - Expected position: line %d, col %d", expected_line_2, expected_col_2))
    
    local line_correct_2 = cursor_after_2[1] == expected_line_2
    local col_correct_2 = cursor_after_2[2] == expected_col_2
    
    print_test_result("TEST Line Position 2", line_correct_2, string.format("Expected %d, got %d", expected_line_2, cursor_after_2[1]))
    print_test_result("TEST Column Position 2", col_correct_2, string.format("Expected %d, got %d", expected_col_2, cursor_after_2[2]))
    
    -- Get the current line content to verify we're at the right place
    local current_line_2 = vim.api.nvim_get_current_line()
    local expected_content_2 = '  console.log("This is line 3 of JS block");'
    local content_correct_2 = current_line_2 == expected_content_2
    print_test_result("TEST Line Content 2", content_correct_2, string.format("Expected '%s', got '%s'", expected_content_2, current_line_2))
    
    -- Close the code buffer
    vim.cmd("bd!")
  end
  
  return true
end

-- Run the test
run_cursor_positioning_test()