--- Async wrapper around mise CLI commands.
---
--- All functions use vim.system() (Neovim >= 0.10) to run mise commands
--- asynchronously, avoiding UI blocking.

---@class MiseInstaller
local M = {}

--- Find the mise binary path.
---@return string|nil path to mise binary, or nil if not found
function M.find_mise()
  local path = vim.fn.exepath("mise")
  if path == "" then
    return nil
  end
  return path
end

--- Run a mise command asynchronously.
---@param args string[] command arguments (e.g. {"use", "--global", "lua-language-server@latest"})
---@param callback fun(ok: boolean, stdout: string, stderr: string) called on completion
function M.run(args, callback)
  local mise = M.find_mise()
  if not mise then
    vim.schedule(function()
      callback(false, "", "mise binary not found on PATH")
    end)
    return
  end

  local cmd = { mise, unpack(args) }
  vim.system(cmd, { text = true }, function(result)
    vim.schedule(function()
      local ok = result.code == 0
      callback(ok, result.stdout or "", result.stderr or "")
    end)
  end)
end

--- Install a tool using `mise use`.
--- This both installs the tool and activates it on PATH.
---@param package string mise package identifier (e.g. "lua-language-server", "npm:pyright")
---@param scope string "global" or "local"
---@param callback fun(ok: boolean, message: string) called on completion
function M.install(package, scope, callback)
  local args = { "use" }
  if scope == "global" then
    table.insert(args, "--global")
  end
  table.insert(args, package .. "@latest")

  M.run(args, function(ok, stdout, stderr)
    if ok then
      callback(true, string.format("Installed %s", package))
    else
      callback(false, string.format("Failed to install %s: %s", package, stderr))
    end
  end)
end

--- Update a tool using `mise upgrade`.
---@param package string mise package identifier
---@param callback fun(ok: boolean, message: string) called on completion
function M.update(package, callback)
  M.run({ "upgrade", package }, function(ok, stdout, stderr)
    if ok then
      callback(true, string.format("Updated %s", package))
    else
      callback(false, string.format("Failed to update %s: %s", package, stderr))
    end
  end)
end

--- Check if a tool is installed and active via `mise ls --json`.
---@param package string mise package identifier
---@param callback fun(installed: boolean, active: boolean, version: string|nil)
function M.check_status(package, callback)
  -- Normalize package name: strip backend prefix for `mise ls` query
  -- e.g. "npm:pyright" -> query "npm:pyright", "lua-language-server" -> query "lua-language-server"
  M.run({ "ls", "--json", package }, function(ok, stdout, stderr)
    if not ok or stdout == "" or stdout == "{}" or stdout == "{}\n" then
      callback(false, false, nil)
      return
    end

    local success, data = pcall(vim.json.decode, stdout)
    if not success or type(data) ~= "table" then
      callback(false, false, nil)
      return
    end

    -- mise ls --json returns { "<tool>": [ { version, installed, active, ... } ] }
    for _, versions in pairs(data) do
      if type(versions) == "table" then
        for _, entry in ipairs(versions) do
          if entry.installed then
            callback(true, entry.active or false, entry.version)
            return
          end
        end
      end
    end

    callback(false, false, nil)
  end)
end

--- Resolve the full path of a tool's binary using `mise which`.
---@param bin_name string executable name (e.g. "lua-language-server")
---@param callback fun(path: string|nil) called with the resolved path, or nil
function M.which(bin_name, callback)
  M.run({ "which", bin_name }, function(ok, stdout, _)
    if ok and stdout ~= "" then
      callback(vim.trim(stdout))
    else
      callback(nil)
    end
  end)
end

--- Install multiple tools concurrently, calling a final callback when all complete.
---@param packages table<string, string> map of tool_name -> mise_package
---@param scope string "global" or "local"
---@param on_each fun(name: string, ok: boolean, message: string) called per tool
---@param on_done fun(results: table<string, boolean>) called when all complete
function M.install_many(packages, scope, on_each, on_done)
  local total = vim.tbl_count(packages)
  if total == 0 then
    on_done({})
    return
  end

  local completed = 0
  local results = {}

  for name, package in pairs(packages) do
    M.install(package, scope, function(ok, message)
      results[name] = ok
      on_each(name, ok, message)
      completed = completed + 1
      if completed >= total then
        on_done(results)
      end
    end)
  end
end

return M
