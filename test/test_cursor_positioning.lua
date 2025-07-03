-- Focused test for cursor positioning functionality in code blocks
local function print_test_result(test_name, passed, message)
  local status = passed and "PASS" or "FAIL"
  print(string.format("[%s] %s: %s", status, test_name, message or ""))
end

local function run_cursor_positioning_test()
  local plugin_path = vim.fn.getcwd()
  vim.opt.runtimepath:prepend(plugin_path)
  
  local ok, markdown_snip = pcall(require, "markdown-snip")
  if not ok then
    print_test_result("Plugin Loading", false, "Failed to load markdown-snip plugin")
    return false
  end
  print_test_result("Plugin Loading", true, "Successfully loaded markdown-snip")
  
  local test_file = plugin_path .. "/test/fixture_test_cursor_positioning.md"
  if vim.fn.filereadable(test_file) == 0 then
    print_test_result("Test File", false, "Test file not found: " .. test_file)
    return false
  end
  
  vim.cmd("edit " .. vim.fn.fnameescape(test_file))
  local md_bufnr = vim.api.nvim_get_current_buf()
  print_test_result("Test File", true, "Opened test markdown file")
  
  -- Test: Position cursor on line 9 (middle of first code block)
  vim.api.nvim_win_set_cursor(0, {9, 10})
  markdown_snip.goto_file()
  
  local code_bufnr = vim.api.nvim_get_current_buf()
  local switched_buffer = code_bufnr ~= md_bufnr
  print_test_result("Buffer Switch", switched_buffer, "Switched to code buffer")
  
  if switched_buffer then
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    local expected_line = 4 -- Line 4 in the code block
    local line_correct = cursor_pos[1] == expected_line
    
    print_test_result("Line Position", line_correct, 
      string.format("Expected line %d, got %d", expected_line, cursor_pos[1]))
    
    local current_line = vim.api.nvim_get_current_line()
    local expected_content = "  local x = 42"
    local content_correct = current_line == expected_content
    print_test_result("Line Content", content_correct, 
      string.format("Expected '%s', got '%s'", expected_content, current_line))
    
    vim.cmd("bd!")
  end
  
  -- Test: Position cursor on line 21 (second code block)
  vim.api.nvim_win_set_cursor(0, {21, 5})
  markdown_snip.goto_file()
  
  local code_bufnr_2 = vim.api.nvim_get_current_buf()
  local switched_buffer_2 = code_bufnr_2 ~= md_bufnr
  print_test_result("Buffer Switch JS", switched_buffer_2, "Switched to JS code buffer")
  
  if switched_buffer_2 then
    local cursor_pos_2 = vim.api.nvim_win_get_cursor(0)
    local expected_line_2 = 3 -- Line 3 in the JS code block
    local line_correct_2 = cursor_pos_2[1] == expected_line_2
    
    print_test_result("Line Position JS", line_correct_2, 
      string.format("Expected line %d, got %d", expected_line_2, cursor_pos_2[1]))
    
    local current_line_2 = vim.api.nvim_get_current_line()
    local expected_content_2 = '  console.log("This is line 3 of JS block");'
    local content_correct_2 = current_line_2 == expected_content_2
    print_test_result("Line Content JS", content_correct_2, 
      string.format("Expected '%s', got '%s'", expected_content_2, current_line_2))
    
    vim.cmd("bd!")
  end
  
  return true
end

-- Run the test
run_cursor_positioning_test()