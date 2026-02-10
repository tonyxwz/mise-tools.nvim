--- mise-tools.nvim — manage dev tools via mise from Neovim.
---
--- Usage:
---   require("mise-tools").setup({
---     ensure_installed = { "lua_ls", "pyright", "gopls" },
---     auto_install = true,
---     scope = "global",
---     registry = {},
---   })

local installer = require("mise-tools.installer")
local builtin_registry = require("mise-tools.registry")

---@class MiseToolsConfig
---@field ensure_installed string[]      list of tool names to ensure installed
---@field auto_install boolean           whether to auto-install on setup() (default: true)
---@field scope string                   "global" or "local" (default: "global")
---@field registry table<string, MiseToolEntry>  user overrides/additions to the built-in registry

---@class MiseTools
local M = {}

---@type MiseToolsConfig
local defaults = {
  ensure_installed = {},
  auto_install = true,
  scope = "global",
  registry = {},
}

---@type MiseToolsConfig
M.config = vim.deepcopy(defaults)

--- The merged registry (built-in + user overrides). Populated after setup().
---@type table<string, MiseToolEntry>
M._registry = {}

--- Setup the plugin with user configuration.
---@param opts MiseToolsConfig?
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})

  -- Merge user registry overrides into built-in registry
  M._registry = vim.tbl_deep_extend("force", {}, builtin_registry, M.config.registry)

  -- Auto-install if enabled
  if M.config.auto_install and #M.config.ensure_installed > 0 then
    M.install()
  end
end

--- Get the merged registry (built-in + user overrides).
---@return table<string, MiseToolEntry>
function M.get_registry()
  return M._registry
end

--- Resolve tool names to { name = mise_id } map.
--- Accepts both registry names (e.g. "lua_ls") and raw mise_ids (e.g. "npm:pyright").
--- If names is nil or empty, uses ensure_installed.
---@param names string[]|nil
---@return table<string, string> map of name -> mise_id
local function resolve_tools(names)
  local registry = M._registry
  if not names or #names == 0 then
    names = M.config.ensure_installed
  end

  local packages = {}
  for _, name in ipairs(names) do
    local entry = registry[name]
    if entry then
      packages[name] = entry.mise_id
    else
      -- Treat as a raw mise_id (e.g. "npm:some-tool", "cargo:taplo-cli", "lua-language-server")
      packages[name] = name
    end
  end
  return packages
end

--- Install tools via mise.
--- Accepts both registry names (e.g. "lua_ls") and raw mise_ids (e.g. "npm:pyright").
--- If no names given, installs all tools in ensure_installed.
---@param names string[]|nil list of tool names or raw mise_ids, or nil for all ensure_installed
function M.install(names)
  local packages = resolve_tools(names)

  if vim.tbl_isempty(packages) then
    vim.notify("[mise-tools] No tools to install.", vim.log.levels.INFO)
    return
  end

  local count = vim.tbl_count(packages)
  vim.notify(string.format("[mise-tools] Installing %d tool(s)...", count), vim.log.levels.INFO)

  installer.install_many(packages, M.config.scope, function(name, ok, message)
    -- Per-tool callback
    local level = ok and vim.log.levels.INFO or vim.log.levels.ERROR
    vim.notify(string.format("[mise-tools] %s", message), level)
  end, function(results)
    -- All done callback
    local succeeded = 0
    local failed = 0
    for _, ok in pairs(results) do
      if ok then
        succeeded = succeeded + 1
      else
        failed = failed + 1
      end
    end
    local summary = string.format("[mise-tools] Done: %d succeeded, %d failed", succeeded, failed)
    local level = failed > 0 and vim.log.levels.WARN or vim.log.levels.INFO
    vim.notify(summary, level)
  end)
end

--- Update tools via mise.
--- Accepts both registry names (e.g. "lua_ls") and raw mise_ids (e.g. "npm:pyright").
--- If no names given, updates all tools in ensure_installed.
---@param names string[]|nil list of tool names or raw mise_ids, or nil for all ensure_installed
function M.update(names)
  local packages = resolve_tools(names)

  if vim.tbl_isempty(packages) then
    vim.notify("[mise-tools] No tools to update.", vim.log.levels.INFO)
    return
  end

  local count = vim.tbl_count(packages)
  vim.notify(string.format("[mise-tools] Updating %d tool(s)...", count), vim.log.levels.INFO)

  local completed = 0
  local results = {}

  for name, package in pairs(packages) do
    installer.update(package, function(ok, message)
      results[name] = ok
      local level = ok and vim.log.levels.INFO or vim.log.levels.ERROR
      vim.notify(string.format("[mise-tools] %s", message), level)

      completed = completed + 1
      if completed >= count then
        local succeeded = 0
        local failed = 0
        for _, v in pairs(results) do
          if v then
            succeeded = succeeded + 1
          else
            failed = failed + 1
          end
        end
        local summary = string.format("[mise-tools] Update done: %d succeeded, %d failed", succeeded, failed)
        local lvl = failed > 0 and vim.log.levels.WARN or vim.log.levels.INFO
        vim.notify(summary, lvl)
      end
    end)
  end
end

--- Print the status of all ensure_installed tools.
function M.status()
  local registry = M._registry
  local names = M.config.ensure_installed

  if #names == 0 then
    vim.notify("[mise-tools] No tools in ensure_installed.", vim.log.levels.INFO)
    return
  end

  vim.notify("[mise-tools] Checking tool status...", vim.log.levels.INFO)

  local completed = 0
  local total = #names
  local lines = {}

  for _, name in ipairs(names) do
    local entry = registry[name]
    -- Use mise_id from registry if available, otherwise treat name as a raw mise_id
    local mise_id = entry and entry.mise_id or name

    installer.check_status(mise_id, function(installed, active, version)
      local status
      if installed and active then
        status = string.format("installed (v%s, active)", version or "?")
      elseif installed then
        status = string.format("installed (v%s, inactive)", version or "?")
      else
        status = "not installed"
      end
      table.insert(lines, string.format("  %s (%s): %s", name, mise_id, status))

      completed = completed + 1
      if completed >= total then
        table.sort(lines)
        vim.notify("[mise-tools] Status:\n" .. table.concat(lines, "\n"), vim.log.levels.INFO)
      end
    end)
  end
end

--- Show a floating window with the status of ensure_installed tools.
function M.show()
  local ui = require("mise-tools.ui")
  ui.show(M.config.ensure_installed, M._registry)
end

return M
