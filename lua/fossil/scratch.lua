local M = {}
M.__index = M

local spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

function M.create()
  local self = {}
  return setmetatable(self, M)
end

function M:open(args, on_done)
  self.args = args
  local subcmd = self.args[1]

  -- open scratch buffer once
  vim.cmd("new")
  self.buf = vim.api.nvim_get_current_buf()
  vim.bo[self.buf].buftype = "nofile"
  vim.bo[self.buf].bufhidden = "wipe"
  vim.bo[self.buf].swapfile = false
  vim.bo[self.buf].modifiable = false

  -- set filetype
  if subcmd == "diff" then
    vim.bo[self.buf].filetype = "diff"
  elseif subcmd == "timeline" or subcmd == "status" then
    vim.bo[self.buf].filetype = "fossil"
  else
    vim.bo[self.buf].filetype = "text"
  end

  self.win = vim.api.nvim_get_current_win()
  self.spinner_index = 1

  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = self.buf,
    once = true,
    callback = on_done
  })
end

function M:append_lines(lines)
  if #lines > 0 and vim.api.nvim_buf_is_valid(self.buf) then
    vim.bo[self.buf].modifiable = true
    vim.api.nvim_buf_set_lines(self.buf, -1, -1, false, lines)
    vim.bo[self.buf].modifiable = false
  end
end

function M:start_spinner()
  self.spinner_timer = vim.loop.new_timer()
  self.spinner_timer:start(0, 100, vim.schedule_wrap(function()
    if self.win then
      if not vim.api.nvim_win_is_valid(self.win) then
        self.spinner_timer:stop()
        return
      end
      local name = spinner_frames[self.spinner_index] .. " Running: fossil " .. table.concat(self.args, " ")
      --pcall(vim.api.nvim_buf_set_name, buf, name)
      vim.wo[self.win].winbar = name
      self.spinner_index = (self.spinner_index % #spinner_frames) + 1
    end
  end))
end

function M:stop_spinner()
  if self.spinner_timer then
    self.spinner_timer:stop()
    self.spinner_timer:close()
    self.spinner_timer = nil
    if self.win and vim.api.nvim_win_is_valid(self.win) then
      local name = "✓ fossil " .. table.concat(self.args, " ")
      vim.wo[self.win].winbar = name
      --pcall(vim.api.nvim_buf_set_name, buf, name)
    end
  end
end

return M
