--- Built-in registry mapping tool names to mise package specs.
---
--- Each entry maps a friendly name (typically matching the lspconfig server name)
--- to a table with:
---   - package: the mise package identifier (passed to `mise use <package>`)
---   - bin: the executable name to verify installation
---   - type: tool category ("lsp", "linter", "formatter") for future filtering
---
--- Users can override or extend this registry via setup({ registry = { ... } }).

---@class MiseToolEntry
---@field mise_id string   mise package identifier (e.g. "lua-language-server", "npm:pyright")
---@field bin string       executable name to check on PATH
---@field type string      tool category: "lsp", "linter", "formatter"

---short id -> Mise Entry
---@type table<string, MiseToolEntry>
local registry = {
  -- Language servers available in mise's built-in registry
  lua_ls = { mise_id = "lua-language-server", bin = "lua-language-server", type = "lsp" },
  rust_analyzer = { mise_id = "rust-analyzer", bin = "rust-analyzer", type = "lsp" },
  taplo = { mise_id = "taplo", bin = "taplo", type = "lsp" },
  marksman = { mise_id = "marksman", bin = "marksman", type = "lsp" },
  zls = { mise_id = "zls", bin = "zls", type = "lsp" },
  helm_ls = { mise_id = "helm-ls", bin = "helm_ls", type = "lsp" },
  terraform_ls = { mise_id = "terraform-ls", bin = "terraform-ls", type = "lsp" },
  elixir_ls = { mise_id = "elixir-ls", bin = "elixir-ls", type = "lsp" },

  -- npm-based language servers
  pyright = { mise_id = "npm:pyright", bin = "pyright-langserver", type = "lsp" },
  basedpyright = { mise_id = "npm:basedpyright", bin = "basedpyright-langserver", type = "lsp" },
  ts_ls = { mise_id = "npm:typescript-language-server", bin = "typescript-language-server", type = "lsp" },
  bashls = { mise_id = "npm:bash-language-server", bin = "bash-language-server", type = "lsp" },
  yamlls = { mise_id = "npm:yaml-language-server", bin = "yaml-language-server", type = "lsp" },
  jsonls = { mise_id = "npm:vscode-langservers-extracted", bin = "vscode-json-language-server", type = "lsp" },
  html = { mise_id = "npm:vscode-langservers-extracted", bin = "vscode-html-language-server", type = "lsp" },
  cssls = { mise_id = "npm:vscode-langservers-extracted", bin = "vscode-css-language-server", type = "lsp" },

  -- go-based language servers
  gopls = { mise_id = "go:golang.org/x/tools/gopls", bin = "gopls", type = "lsp" },

  -- Linters / formatters (for future use, included in registry for extensibility)
  ruff = { mise_id = "ruff", bin = "ruff", type = "linter" },
  shellcheck = { mise_id = "shellcheck", bin = "shellcheck", type = "linter" },
  stylua = { mise_id = "stylua", bin = "stylua", type = "formatter" },
  shfmt = { mise_id = "shfmt", bin = "shfmt", type = "formatter" },
}

return registry
