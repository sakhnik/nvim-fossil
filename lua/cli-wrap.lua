local M = {}

local editor = require'cli-wrap.editor'

local function run_fossil(args)
  local cmd = vim.list_extend({ "fossil" }, args)

  local job_id
  local scratch = require'cli-wrap.scratch'.create()
  local scratch_opened = false

  local function ensure_scratch_opened()
    if scratch_opened then
      return
    end
    scratch_opened = true
    scratch:open(args, function()
      if job_id then
        vim.fn.jobstop(job_id)
        scratch:stop_spinner()
        vim.notify("Fossil job killed because buffer was closed", vim.log.levels.WARN)
        job_id = nil
      end
    end)
  end

  job_id = vim.fn.jobstart(cmd, {
    env = { EDITOR = editor.sh },
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
          editor.check(line)
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
