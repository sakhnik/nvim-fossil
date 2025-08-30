vim.api.nvim_create_user_command("Fossil", function(opts)
  require'cli-wrap'.run(opts.fargs)
end, {
  nargs = "+",
  complete = function(arg_lead, cmdline, cursor_pos)
    return require'cli-wrap.completion'.complete(arg_lead, cmdline, cursor_pos)
  end
})
