local M = {}

local this_dir = debug.getinfo(1, "S").source:match("@(.*/)")
local fossil_editor = this_dir .. "../scripts/editor.sh"
local spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

local function open_fossil_editor_buffer(tempfile)
    local buf = vim.fn.bufadd(tempfile)
    vim.fn.bufload(buf)

    -- Open in a split window
    vim.cmd('split')
    vim.api.nvim_win_set_buf(0, buf)

    -- Set buffer options
    vim.bo[buf].buftype = ''  -- normal file buffer
    vim.bo[buf].swapfile = false
    vim.bo[buf].filetype = 'fossilcommit'

    vim.api.nvim_create_autocmd({"BufWipeout", "BufUnload"}, {
      buffer = buf,
      callback = function()
        os.remove('/tmp/nvim-fossil.edit')
      end
    })
end

local function run_fossil(args)
  local cmd = vim.list_extend({ "fossil" }, args)

  -- open scratch buffer once
  vim.cmd("new")
  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = false

  -- set filetype
  local subcmd = args[1]
  if subcmd == "diff" then
    vim.bo[buf].filetype = "diff"
  elseif subcmd == "timeline" or subcmd == "status" then
    vim.bo[buf].filetype = "fossil"
  else
    vim.bo[buf].filetype = "text"
  end

  local win = vim.api.nvim_get_current_win()
  local spinner_timer
  local spinner_index = 1
  local job_id

  local function start_spinner()
    spinner_timer = vim.loop.new_timer()
    spinner_timer:start(0, 100, vim.schedule_wrap(function()
      if not vim.api.nvim_win_is_valid(win) then
        spinner_timer:stop()
        return
      end
      local name = spinner_frames[spinner_index] .. " Running: fossil " .. table.concat(args, " ")
      --pcall(vim.api.nvim_buf_set_name, buf, name)
      vim.wo[win].winbar = name
      spinner_index = (spinner_index % #spinner_frames) + 1
    end))
  end

  local function stop_spinner()
    if spinner_timer then
      spinner_timer:stop()
      spinner_timer:close()
      spinner_timer = nil
      if vim.api.nvim_win_is_valid(win) then
        local name = "✓ fossil " .. table.concat(args, " ")
        vim.wo[win].winbar = name
        --pcall(vim.api.nvim_buf_set_name, buf, name)
      end
    end
  end

  -- autocmd to kill the job if buffer is wiped
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = buf,
    once = true,
    callback = function()
      if job_id then
        vim.fn.jobstop(job_id)
        stop_spinner()
        vim.notify("Fossil job killed because buffer was closed", vim.log.levels.WARN)
      end
    end,
  })

  job_id = vim.fn.jobstart(cmd, {
    env = { EDITOR = fossil_editor },
    stdout_buffered = false,
    stderr_buffered = false,
    on_stdout = function(_, data, _)
      if not data then return end
      local clean = {}
      for _, l in ipairs(data) do
        if l ~= "" then table.insert(clean, l) end
      end
      if #clean > 0 and vim.api.nvim_buf_is_valid(buf) then
        vim.bo[buf].modifiable = true
        vim.api.nvim_buf_set_lines(buf, -1, -1, false, clean)
        vim.bo[buf].modifiable = false
      end
    end,
    on_stderr = function(_, data, _)
      if data and #data > 0 and data[1] ~= "" then
        for _, line in ipairs(data) do
          local tempfile = line:match("fossil:edit;([^\007]*)")
          if tempfile then
            open_fossil_editor_buffer(tempfile)
          end
        end
        vim.notify(table.concat(data, "\n"), vim.log.levels.ERROR)
      end
    end,
    on_exit = function()
      vim.schedule(stop_spinner)
    end,
  })

  if job_id > 0 then
    start_spinner()
  else
    vim.notify("Failed to start fossil job", vim.log.levels.ERROR)
  end
end

-- Run a fossil command asynchronously and show results in scratch buffer
function M.run(args)
  if #args == 0 then
    vim.notify("No fossil command given", vim.log.levels.ERROR)
    return
  end

  run_fossil(args)
end

return M
