local M = {}

local this_dir = debug.getinfo(1, "S").source:match("@(.*/)")
local fossil_editor = this_dir .. "../scripts/editor.sh"

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

  local job_id
  local scratch = require'fossil.scratch'.create()
  local scratch_opened = false

  local function ensure_scratch_opened()
    if scratch_opened then
      return
    end
    scratch_opened = true
    scratch:open(args, function()
      if job_id then
        vim.print("!!! kill")
        vim.fn.jobstop(job_id)
        scratch:stop_spinner()
        vim.notify("Fossil job killed because buffer was closed", vim.log.levels.WARN)
        job_id = nil
      end
    end)
  end

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

      ensure_scratch_opened()
      scratch:append_lines(clean)
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
      ensure_scratch_opened()
      vim.schedule(function() scratch:stop_spinner() end)
      if job_id then
        vim.fn.jobstop(job_id)
        job_id = nil
      end
    end,
  })

  if job_id > 0 then
    scratch:start_spinner()
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
