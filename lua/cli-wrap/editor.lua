local M = {}
M.__index = M

local this_dir = debug.getinfo(1, "S").source:match("@(.*/)")
M.sh = this_dir .. "../../scripts/editor.sh"

local function open_editor_buffer(tempfile)
    local buf = vim.fn.bufadd(tempfile)
    vim.fn.bufload(buf)

    -- Open in a split window
    vim.cmd('split')
    vim.api.nvim_win_set_buf(0, buf)

    -- Set buffer options
    vim.bo[buf].buftype = ''  -- normal file buffer
    vim.bo[buf].swapfile = false
    -- TODO: make customizable
    vim.bo[buf].filetype = 'fossilcommit'

    vim.api.nvim_create_autocmd({"BufWipeout", "BufUnload"}, {
      buffer = buf,
      callback = function()
        os.remove('/tmp/nvim-cli-wrap.edit')
      end
    })
end

function M.check(line)
  local tempfile = line:match("nvim%-cli%-wrap:edit;([^\007]*)")
  if tempfile then
    open_editor_buffer(tempfile)
  end
end

return M
