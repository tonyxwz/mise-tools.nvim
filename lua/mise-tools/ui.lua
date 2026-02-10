--- Floating window UI for mise-tools.nvim
--- Displays the status of ensure_installed tools in a floating window.

---@class MiseToolsUI
local M = {}

local ns = vim.api.nvim_create_namespace("mise-tools")

--- Create a centered floating window.
---@param width number
---@param height number
---@return number buf buffer handle
---@return number win window handle
local function create_float(width, height)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].filetype = "mise-tools"

  local ui = vim.api.nvim_list_uis()[1]
  local row = math.floor((ui.height - height) / 2)
  local col = math.floor((ui.width - width) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = " mise-tools ",
    title_pos = "center",
  })

  -- Close on q or Esc
  local close = function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end
  vim.keymap.set("n", "q", close, { buffer = buf, nowait = true })
  vim.keymap.set("n", "<Esc>", close, { buffer = buf, nowait = true })

  return buf, win
end

--- Format a status icon.
---@param installed boolean
---@param active boolean
---@return string
local function status_icon(installed, active)
  if installed and active then
    return "+"
  elseif installed then
    return "~"
  else
    return "x"
  end
end

--- Render lines into the buffer, replacing existing content.
---@param buf number
---@param lines string[]
local function set_lines(buf, lines)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
end

--- Show the floating status window.
---@param ensure_installed string[]
---@param registry table<string, MiseToolEntry>
function M.show(ensure_installed, registry)
  local installer = require("mise-tools.installer")

  if #ensure_installed == 0 then
    vim.notify("[mise-tools] No tools in ensure_installed.", vim.log.levels.INFO)
    return
  end

  -- Calculate window size based on editor dimensions
  local ui_width = vim.o.columns
  local ui_height = vim.o.lines

  local width = math.max(60, math.floor(ui_width * 0.6))
  local height = math.max(#ensure_installed + 4, math.floor(ui_height * 0.4))
  local max_height = math.floor(ui_height * 0.8)
  height = math.min(height, max_height)

  local buf, win = create_float(width, height)

  -- Initial content: loading state
  local lines = { "  Loading tool status..." }
  set_lines(buf, lines)

  -- Fetch status for each tool asynchronously
  local completed = 0
  local total = #ensure_installed
  local tool_statuses = {}

  for i, name in ipairs(ensure_installed) do
    local entry = registry[name]
    local mise_id = entry and entry.mise_id or name

    installer.check_status(mise_id, function(installed, active, version)
      tool_statuses[i] = {
        name = name,
        mise_id = mise_id,
        installed = installed,
        active = active,
        version = version,
      }

      completed = completed + 1
      if completed >= total then
        M._render(buf, tool_statuses, width)
      end
    end)
  end
end

--- Render the final tool status into the buffer.
---@param buf number
---@param tool_statuses table[]
---@param width number
function M._render(buf, tool_statuses, width)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local lines = {}
  local highlights = {}

  -- Header
  table.insert(lines, string.format("  %-20s %-25s %s", "Name", "Package", "Status"))
  table.insert(lines, "  " .. string.rep("-", width - 4))

  -- Tool rows
  local installed_count = 0
  for _, tool in ipairs(tool_statuses) do
    local icon = status_icon(tool.installed, tool.active)
    local status_str
    if tool.installed and tool.active then
      status_str = string.format("v%s", tool.version or "?")
      installed_count = installed_count + 1
    elseif tool.installed then
      status_str = string.format("v%s (inactive)", tool.version or "?")
      installed_count = installed_count + 1
    else
      status_str = "not installed"
    end

    local line = string.format("  [%s] %-18s %-25s %s", icon, tool.name, tool.mise_id, status_str)
    local line_idx = #lines
    table.insert(lines, line)

    -- Track highlight info
    table.insert(highlights, {
      line = line_idx,
      icon = icon,
    })
  end

  -- Footer
  table.insert(lines, "  " .. string.rep("-", width - 4))
  table.insert(lines, string.format("  %d/%d installed", installed_count, #tool_statuses))

  set_lines(buf, lines)

  -- Apply highlights
  for _, hl in ipairs(highlights) do
    local hl_group
    if hl.icon == "+" then
      hl_group = "DiagnosticOk"
    elseif hl.icon == "~" then
      hl_group = "DiagnosticWarn"
    else
      hl_group = "DiagnosticError"
    end
    -- Highlight the icon bracket section [+], [~], or [x]
    vim.api.nvim_buf_set_extmark(buf, ns, hl.line, 2, {
      end_col = 5,
      hl_group = hl_group,
    })
  end
end

return M
