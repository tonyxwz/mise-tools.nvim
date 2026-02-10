--- mise-tools.nvim user commands
--- Auto-loaded by Neovim at startup from plugin/ directory.

local function get_completion(_, cmd_line, _)
  local mise_tools = require("mise-tools")
  local registry = mise_tools.get_registry()
  local keys = vim.tbl_keys(registry)
  table.sort(keys)
  return keys
end

vim.api.nvim_create_user_command("MiseInstall", function(opts)
  local mise_tools = require("mise-tools")
  local names = #opts.fargs > 0 and opts.fargs or nil
  mise_tools.install(names)
end, {
  nargs = "*",
  complete = get_completion,
  desc = "Install tools via mise (default: all ensure_installed)",
})

vim.api.nvim_create_user_command("MiseUpdate", function(opts)
  local mise_tools = require("mise-tools")
  local names = #opts.fargs > 0 and opts.fargs or nil
  mise_tools.update(names)
end, {
  nargs = "*",
  complete = get_completion,
  desc = "Update tools via mise (default: all ensure_installed)",
})

vim.api.nvim_create_user_command("MiseStatus", function()
  local mise_tools = require("mise-tools")
  mise_tools.status()
end, {
  nargs = 0,
  desc = "Show install status of mise-managed tools",
})
