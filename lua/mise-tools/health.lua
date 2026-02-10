--- Health check for mise-tools.nvim
--- Run with :checkhealth mise-tools

local M = {}

function M.check()
  vim.health.start("mise-tools.nvim")

  -- Check mise binary
  local mise_path = vim.fn.exepath("mise")
  if mise_path == "" then
    vim.health.error("mise binary not found on PATH", {
      "Install mise: https://mise.jdx.dev/getting-started.html",
      "Ensure mise is activated in your shell (mise activate)",
    })
    return
  end
  vim.health.ok("mise found: " .. mise_path)

  -- Check mise version
  local result = vim.system({ mise_path, "--version" }, { text = true }):wait()
  if result.code == 0 then
    vim.health.ok("mise version: " .. vim.trim(result.stdout))
  else
    vim.health.warn("Could not determine mise version")
  end

  -- Check plugin setup
  local ok, mise_tools = pcall(require, "mise-tools")
  if not ok then
    vim.health.error("Failed to load mise-tools module")
    return
  end

  local config = mise_tools.config
  if #config.ensure_installed == 0 then
    vim.health.info("No tools in ensure_installed")
    return
  end

  vim.health.info(string.format("ensure_installed: %s", table.concat(config.ensure_installed, ", ")))
  vim.health.info(string.format("scope: %s", config.scope))
  vim.health.info(string.format("auto_install: %s", tostring(config.auto_install)))

  -- Check each tool
  local registry = mise_tools.get_registry()
  for _, name in ipairs(config.ensure_installed) do
    local entry = registry[name]
    if not entry then
      vim.health.warn(string.format("%s: not found in registry", name))
    else
      -- Synchronous check: try to find the binary
      local bin_path = vim.fn.exepath(entry.bin)
      if bin_path ~= "" then
        vim.health.ok(string.format("%s: %s found at %s", name, entry.bin, bin_path))
      else
        vim.health.warn(string.format("%s: %s not found on PATH", name, entry.bin), {
          string.format("Run :MiseInstall %s to install", name),
        })
      end
    end
  end
end

return M
