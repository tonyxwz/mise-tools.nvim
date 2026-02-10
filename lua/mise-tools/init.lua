--- mise-tools.nvim — manage dev tools via mise from Neovim.
---
--- Usage:
---   -- 1. Define your LSP configs (or use lsp/*.lua files / nvim-lspconfig)
---   vim.lsp.config['lua_ls'] = {
---     cmd = { 'lua-language-server' },
---     filetypes = { 'lua' },
---     root_markers = { '.luarc.json', '.git' },
---   }
---
---   -- 2. Let mise-tools handle install + enable
---   require("mise-tools").setup({
---     ensure_installed = true,  -- all servers from vim.lsp.config
---     -- or: ensure_installed = { "lua_ls", "pyright" },
---     auto_install = true,
---     scope = "global",
---   })

local installer = require("mise-tools.installer")
local builtin_registry = require("mise-tools.registry")

---@class MiseToolsConfig
---@field ensure_installed boolean|string[]  true = all from vim.lsp.config, or a list of server names
---@field auto_install boolean               whether to auto-install missing tools (default: true)
---@field scope string                       "global" or "local" (default: "global")
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

--- Track servers that have already been enabled or are being installed,
--- to avoid redundant work.
---@type table<string, boolean>
M._handled = {}

--- Get the effective list of server names from ensure_installed.
--- If ensure_installed is true, returns all keys from vim.lsp._enabled_configs
--- (servers that have been defined via vim.lsp.config).
--- If ensure_installed is a table, returns it as-is.
---@return string[]
function M.get_ensure_installed()
  local ei = M.config.ensure_installed
  if ei == true then
    -- Collect all server names that have a config defined
    local names = {}
    -- vim.lsp._enabled_configs tracks configs that have been set up;
    -- we iterate the keys from vim.lsp.config by trying known registry names
    -- plus any enabled configs
    if vim.lsp._enabled_configs then
      for name, _ in pairs(vim.lsp._enabled_configs) do
        table.insert(names, name)
      end
    end
    table.sort(names)
    return names
  elseif type(ei) == "table" then
    return ei
  else
    return {}
  end
end

--- Resolve the binary to check for a given server name.
--- Uses the registry bin field if available, otherwise falls back to
--- cmd[1] from the user's vim.lsp.config.
---@param name string server name
---@return string|nil binary name to check on PATH
local function resolve_bin(name)
  local registry = M._registry
  local entry = registry[name]
  if entry and entry.bin then
    return entry.bin
  end
  -- Fall back to cmd[1] from vim.lsp.config
  local ok, lsp_cfg = pcall(function()
    return vim.lsp.config[name]
  end)
  if ok and lsp_cfg and lsp_cfg.cmd and lsp_cfg.cmd[1] then
    return lsp_cfg.cmd[1]
  end
  return nil
end

--- Check if a server's filetypes include the given filetype.
---@param name string server name
---@param ft string filetype to check
---@return boolean
local function server_matches_filetype(name, ft)
  local ok, lsp_cfg = pcall(function()
    return vim.lsp.config[name]
  end)
  if not ok or not lsp_cfg or not lsp_cfg.filetypes then
    return false
  end
  return vim.tbl_contains(lsp_cfg.filetypes, ft)
end

--- Handle a FileType event: for each ensure_installed server matching
--- the filetype, check if the binary is available. If yes, enable.
--- If not, install via mise then enable.
---@param ft string the filetype
local function on_filetype(ft)
  for _, name in ipairs(M.get_ensure_installed()) do
    if not M._handled[name] and server_matches_filetype(name, ft) then
      M._handled[name] = true

      local bin = resolve_bin(name)
      if bin and vim.fn.exepath(bin) ~= "" then
        -- Binary already on PATH, just enable
        vim.lsp.enable(name)
      elseif M.config.auto_install then
        -- Binary missing, install then enable
        local entry = M._registry[name]
        local mise_id = entry and entry.mise_id or name

        vim.notify(string.format("[mise-tools] Installing %s...", name), vim.log.levels.INFO)
        installer.install(mise_id, M.config.scope, function(ok_install, message)
          if ok_install then
            vim.notify(string.format("[mise-tools] %s", message), vim.log.levels.INFO)
            vim.lsp.enable(name)
          else
            vim.notify(string.format("[mise-tools] %s", message), vim.log.levels.ERROR)
            -- Allow retry on next FileType event
            M._handled[name] = nil
          end
        end)
      else
        -- auto_install disabled, just enable (LSP will handle the missing binary error)
        vim.lsp.enable(name)
      end
    end
  end
end

--- Setup the plugin with user configuration.
---@param opts MiseToolsConfig?
function M.setup(opts)
  opts = opts or {}

  -- ensure_installed can be boolean or table, handle it before deep extend
  local ei = opts.ensure_installed
  opts.ensure_installed = nil
  M.config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts)
  if ei ~= nil then
    M.config.ensure_installed = ei
  end

  -- Merge user registry overrides into built-in registry
  M._registry = vim.tbl_deep_extend("force", {}, builtin_registry, M.config.registry)

  -- Reset handled state
  M._handled = {}

  -- Register FileType autocommand for reactive install + enable
  local group = vim.api.nvim_create_augroup("mise-tools", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    callback = function(args)
      local ft = args.match
      if ft and ft ~= "" then
        on_filetype(ft)
      end
    end,
    desc = "mise-tools: auto-install and enable LSP servers on FileType",
  })

  -- Handle already-open buffers (e.g. the buffer that was open when setup() was called)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      local ft = vim.bo[buf].filetype
      if ft and ft ~= "" then
        on_filetype(ft)
      end
    end
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
    names = M.get_ensure_installed()
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
  local names = M.get_ensure_installed()

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
  ui.show(M.get_ensure_installed(), M._registry)
end

return M
