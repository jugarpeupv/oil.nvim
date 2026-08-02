local fs = require('oil.fs')
local oil = require('oil')
local parser = require('oil.mutator.parser')
local test_adapter = require('oil.adapters.test')
local test_util = require('spec.test_util')
local view = require('oil.view')

describe('oil header', function()
  after_each(function()
    test_util.reset_editor()
  end)

  it('is not shown by default', function()
    test_adapter.test_set('/foo/bar.txt', 'file')
    vim.cmd.edit({ args = { 'oil-test:///foo/' } })
    test_util.wait_oil_ready()
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
    assert.is_true(lines[1]:match('^/%d+') ~= nil, 'expected line 1 to be an entry')
  end)

  it('shows the cwd on the first line when enabled', function()
    test_adapter.test_set('/foo/bar.txt', 'file')
    require('oil.config').header = { cwd = true, format = 'short' }
    vim.cmd.edit({ args = { 'oil-test:///foo/' } })
    test_util.wait_oil_ready()
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
    assert.equals('/foo', lines[1])
    assert.is_true(lines[2]:match('^/%d+') ~= nil, 'expected line 2 to be an entry')
  end)

  it('updates the header when navigating to a subdirectory', function()
    test_adapter.test_set('/foo/bar/baz.txt', 'file')
    require('oil.config').header = { cwd = true, format = 'short' }
    vim.cmd.edit({ args = { 'oil-test:///foo/' } })
    test_util.wait_oil_ready()
    assert.equals('/foo', vim.api.nvim_buf_get_lines(0, 0, 1, true)[1])
    vim.cmd.edit({ args = { 'oil-test:///foo/bar/' } })
    test_util.wait_oil_ready()
    assert.equals('/foo/bar', vim.api.nvim_buf_get_lines(0, 0, 1, true)[1])
  end)

  it('get_entry_on_line skips the header', function()
    test_adapter.test_set('/foo/bar.txt', 'file')
    require('oil.config').header = { cwd = true, format = 'short' }
    vim.cmd.edit({ args = { 'oil-test:///foo/' } })
    test_util.wait_oil_ready()
    assert.is_nil(oil.get_entry_on_line(0, 1))
    assert.equals('bar.txt', oil.get_entry_on_line(0, 2).name)
  end)

  it('toggles the header on and off', function()
    require('oil.config').header = { cwd = false, format = 'short' }
    test_adapter.test_set('/foo/bar.txt', 'file')
    vim.cmd.edit({ args = { 'oil-test:///foo/' } })
    test_util.wait_oil_ready()
    view.toggle_header()
    vim.wait(1000, function()
      return not vim.api.nvim_buf_get_lines(0, 0, 1, true)[1]:match('^/%d+')
    end)
    assert.equals('/foo', vim.api.nvim_buf_get_lines(0, 0, 1, true)[1])
    view.toggle_header()
    vim.wait(1000, function()
      return vim.api.nvim_buf_get_lines(0, 0, 1, true)[1]:match('^/%d+')
    end)
    assert.is_true(vim.api.nvim_buf_get_lines(0, 0, 1, true)[1]:match('^/%d+') ~= nil)
  end)

  it('allows the cursor on the header line', function()
    require('oil.config').header = { cwd = true, format = 'short' }
    test_adapter.test_set('/foo/bar.txt', 'file')
    vim.cmd.edit({ args = { 'oil-test:///foo/' } })
    test_util.wait_oil_ready()
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    assert.equals(1, vim.api.nvim_win_get_cursor(0)[1])
  end)

  it('selecting the header line navigates to the path shown on it', function()
    require('oil.config').header = { cwd = true, format = 'short' }
    test_adapter.test_set('/foo/bar/baz.txt', 'file')
    vim.cmd.edit({ args = { 'oil-test:///foo/bar/' } })
    test_util.wait_oil_ready()
    assert.equals('/foo/bar', vim.api.nvim_buf_get_lines(0, 0, 1, true)[1])
    vim.api.nvim_buf_set_lines(0, 0, 1, true, { '/foo' })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    oil.select()
    test_util.wait_oil_ready()
    assert.equals('oil-test:///foo/', vim.api.nvim_buf_get_name(0))
    assert.equals('/foo', vim.api.nvim_buf_get_lines(0, 0, 1, true)[1])
  end)

  it('insert-mode <CR> on the header line navigates to the shown path', function()
    require('oil.config').header = { cwd = true, format = 'short' }
    test_adapter.test_set('/foo/bar/baz.txt', 'file')
    vim.cmd.edit({ args = { 'oil-test:///foo/bar/' } })
    test_util.wait_oil_ready()
    vim.api.nvim_buf_set_lines(0, 0, 1, true, { '/foo' })
    vim.api.nvim_win_set_cursor(0, { 1, 5 })
    test_util.feedkeys({ 'i<CR>' }, 20)
    vim.wait(2000, function()
      return vim.api.nvim_buf_get_name(0) == 'oil-test:///foo/'
    end)
    assert.equals('oil-test:///foo/', vim.api.nvim_buf_get_name(0))
    test_util.wait_oil_ready()
    assert.equals('/foo', vim.api.nvim_buf_get_lines(0, 0, 1, true)[1])
  end)

  it('warns when the header path does not exist (files adapter)', function()
    local TmpDir = require('spec.tmpdir')
    local tmpdir = TmpDir.new()
    tmpdir:create({ 'subdir/' })
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(bufnr, 'oil://' .. tmpdir.path .. '/subdir/')
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, { tmpdir.path .. '/missing' })
    require('oil.config').header = { cwd = true, format = 'short' }
    local notified = {}
    local orig_notify = vim.notify
    vim.notify = function(msg, level)
      table.insert(notified, { msg = msg, level = level })
    end
    require('oil.util').navigate_to_header_path(bufnr, true)
    vim.notify = orig_notify
    tmpdir:dispose()
    assert.equals(1, #notified)
    assert.is_true(notified[1].msg:match('does not exist') ~= nil)
    assert.equals(vim.log.levels.WARN, notified[1].level)
  end)

  it('parser ignores the header line', function()
    test_adapter.test_set('/foo/bar.txt', 'file')
    require('oil.config').header = { cwd = true, format = 'short' }
    vim.cmd.edit({ args = { 'oil-test:///foo/' } })
    test_util.wait_oil_ready()
    local diffs, errors = parser.parse(0)
    assert.are.same({}, diffs)
    assert.are.same({}, errors)
  end)

  it('formats the header as a short ~ path for the files adapter', function()
    local home = vim.fn.expand('~')
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(bufnr, 'oil://' .. fs.os_to_posix_path(home .. '/projects/foo') .. '/')
    require('oil.config').header = { cwd = true, format = 'short' }
    require('oil.config').header.format = 'short'
    assert.equals('~/projects/foo', view.get_header_text(bufnr))
    require('oil.config').header.format = 'full'
    assert.equals(fs.join(home, 'projects/foo'), view.get_header_text(bufnr))
  end)
end)
