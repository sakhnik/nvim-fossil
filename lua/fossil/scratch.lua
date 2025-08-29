---@class Scratch
---@field private args string[]
---@field private buf integer
---@field private win integer
---@field private spinner_index integer
---@field private spinner_timer userdata
local M = {}
M.__index = M

local spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

---Create new scratch object
function M.create()
  local self = {}
  return setmetatable(self, M)
end

---Open a new scratch window
---@param args string[]
---@param on_done fun()
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

  pcall(vim.api.nvim_buf_set_name, self.buf, "fossil " .. table.concat(self.args, " "))

  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = self.buf,
    once = true,
    callback = on_done
  })
end

---Append lines to the scratch buffer
---@param lines string[]
function M:append_lines(lines)
  if #lines > 0 and vim.api.nvim_buf_is_valid(self.buf) then
    vim.bo[self.buf].modifiable = true
    vim.api.nvim_buf_set_lines(self.buf, -1, -1, false, lines)
    vim.bo[self.buf].modifiable = false
  end
end

---Start spinner
function M:start_spinner()
  self.spinner_timer = vim.loop.new_timer()
  self.spinner_timer:start(0, 100, vim.schedule_wrap(function()
    if self.win then
      if not vim.api.nvim_win_is_valid(self.win) then
        self.spinner_timer:stop()
        return
      end
      vim.wo[self.win].winbar = spinner_frames[self.spinner_index] .. " Running"
      self.spinner_index = (self.spinner_index % #spinner_frames) + 1
    end
  end))
end

---Stop spinner
function M:stop_spinner()
  if self.spinner_timer then
    self.spinner_timer:stop()
    self.spinner_timer:close()
    self.spinner_timer = nil
    if self.win and vim.api.nvim_win_is_valid(self.win) then
      vim.wo[self.win].winbar = nil

      -- Close automatically if empty
      local lines = vim.api.nvim_buf_get_lines(self.buf, 0, -1, false)
      local is_empty = (#lines == 0) or (#lines == 1 and lines[1] == "")
      if is_empty then
        vim.api.nvim_win_close(self.win, true)
      end
    end
  end
end

return M
