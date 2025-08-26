vim.api.nvim_create_user_command("Fossil", function(opts)
  require'fossil'.run(opts.fargs)
end, {
  nargs = "+",
  complete = function(arg_lead, cmdline, cursor_pos)
    return require'fossil.completion'.complete(arg_lead, cmdline, cursor_pos)
  end
})
