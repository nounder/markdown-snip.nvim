#!/bin/bash

# Run tests in a clean Neovim instance

set -e # Exit on any error

echo "Running markdown-snip.nvim tests..."
echo "=================================="

# Check if nvim is available
if ! command -v nvim &>/dev/null; then
  echo "Error: nvim command not found. Please install Neovim."
  exit 1
fi

# Find all test files that start with "test_"
TEST_FILES=(test/test_*.lua)

# Check if any test files exist
if [[ ${#TEST_FILES[@]} -eq 0 || ! -f "${TEST_FILES[0]}" ]]; then
  echo "Error: No test files found matching pattern 'test/test_*.lua'"
  exit 1
fi

echo "Found ${#TEST_FILES[@]} test file(s):"
for test_file in "${TEST_FILES[@]}"; do
  echo "  - $test_file"
done
echo ""

# Create a temporary directory for testing
TMPDIR=$(mktemp -d)
echo "Running tests in temporary directory: $TMPDIR"

# Copy plugin files to tmpdir
cp -r . "$TMPDIR/"

# Change to tmpdir and run each test
cd "$TMPDIR"

for test_file in "${TEST_FILES[@]}"; do
  echo "Running $test_file in clean Neovim instance..."
  nvim --clean --headless -c "luafile $test_file" -c "qall!"
  echo ""
done

# Clean up
cd - >/dev/null
rm -rf "$TMPDIR"

echo "All tests completed successfully!"

