local M = {}

-- Lazy cache of fossil subcommands
local cached_commands = nil

local function parse_fossil_help(output)
  local commands = {}
  local current = nil

  for _, line in ipairs(output) do
    local cmd = line:match("^#%s*(%S+)")
    if cmd then
      current = { name = cmd, options = {} }
      table.insert(commands, current)
    elseif current then
      -- option line like: "  -b|--brief    Display a brief summary"
      local flags, desc = line:match("^%s*([-%w|=]+)%s+(.*)")
      if flags and flags:match("^%-") then
        local opts = vim.split(flags, "|", { trimempty = true })
        for _, opt in ipairs(opts) do
          table.insert(current.options, {
            flag = vim.trim(opt),
            desc = vim.trim(desc)
          })
        end
      end
    end
  end

  return commands
end

-- Extract subcommands from `fossil help`
local function get_commands()
  if not cached_commands then
    local output = vim.fn.systemlist({ "fossil", "help", "--all", "--verbose" })
    cached_commands = parse_fossil_help(output)
  end
  return cached_commands
end

-- Completion function for :Fossil
function M.complete(arg_lead, cmdline, cursor_pos)
  local results = {}
  local commands = get_commands()
  local args = vim.split(cmdline, "%s+")
  if #args <= 2 then
    -- completing command name
    for _, c in ipairs(commands) do
      if c.name:find("^" .. arg_lead) then
        table.insert(results, c.name)
      end
    end
  else
    -- completing options for the given command
    local cmdname = args[2]
    for _, c in ipairs(commands) do
      if c.name == cmdname then
        for _, opt in ipairs(c.options) do
          if opt.flag:find("^" .. arg_lead) then
            table.insert(results, opt.flag)
          end
        end
      end
    end

    -- fallback to file completion
    if vim.tbl_isempty(results) then
      results = vim.fn.getcompletion(arg_lead, "file")
    end
  end
  return results
end

return M
