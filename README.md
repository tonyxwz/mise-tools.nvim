# mise-tools.nvim

Manage LSP servers, linters, and formatters using [mise](https://mise.jdx.dev)
from Neovim.

Instead of using a Neovim-specific tool installer like mason.nvim,
mise-tools.nvim leverages mise — a polyglot tool version manager — so dev
tools are available both inside Neovim and on the command line.

## Requirements

- Neovim >= 0.11
- [mise](https://mise.jdx.dev/getting-started.html) installed and activated in
  the shell

## Installation

### Package Managers

Add something like below to the plugins config:

```lua
{
  "tonyxwz/mise-tools.nvim",
  opts = {
    ensure_installed = true,
  },
}
```

### Manual (native packages)

```bash
mkdir -p ~/.local/share/nvim/site/pack/plugins/start
git clone https://github.com/tonyxwz/mise-tools.nvim \
  ~/.local/share/nvim/site/pack/plugins/start/mise-tools.nvim
```

## How It Works

1. Define LSP configs using Neovim's built-in `vim.lsp.config` API
   (or use `lsp/*.lua` files from nvim-lspconfig).
2. Set `ensure_installed = true` (or a list of specific server names).
3. mise-tools automatically handles the rest: when a file is opened, it checks
   if the matching LSP server's binary is on PATH. If missing, it installs via
   mise, then calls `vim.lsp.enable()` to activate the server.

There is no need to call `vim.lsp.enable()` manually for servers managed by
mise-tools.

### Example

```lua
-- 1. Define LSP configs (or use lsp/*.lua files)
vim.lsp.config['lua_ls'] = {
  cmd = { 'lua-language-server' },
  filetypes = { 'lua' },
  root_markers = { '.luarc.json', '.git' },
}

vim.lsp.config['pyright'] = {
  cmd = { 'pyright-langserver', '--stdio' },
  filetypes = { 'python' },
  root_markers = { 'pyproject.toml', 'setup.py', '.git' },
}

-- 2. Let mise-tools handle install + enable for all configured servers
require("mise-tools").setup({
  ensure_installed = true,
})
```

When a `.lua` file is opened, mise-tools will:
- Check if `lua-language-server` is on PATH
- If missing, run `mise use --global lua-language-server@latest`
- Call `vim.lsp.enable('lua_ls')` to start the server

## Setup

```lua
require("mise-tools").setup({
  -- true = ensure all servers defined in vim.lsp.config.
  -- Can also be a list of specific server names, e.g. { "lua_ls", "pyright" }.
  ensure_installed = true,

  -- Automatically install missing tools when a matching filetype is opened.
  -- Default: true
  auto_install = true,

  -- "global" runs `mise use --global <tool>` (available everywhere).
  -- "local" runs `mise use <tool>` (available only in the current directory).
  -- Default: "global"
  scope = "global",

  -- Override or extend the built-in registry.
  -- Each entry maps a server name to a mise package spec.
  registry = {
    -- Override an existing entry
    pyright = { mise_id = "npm:basedpyright", bin = "basedpyright-langserver", type = "lsp" },
    -- Add a custom tool
    my_lsp = { mise_id = "npm:my-custom-lsp", bin = "my-custom-lsp", type = "lsp" },
  },
})
```

## Commands

| Command                   | Description                                                                         |
| ------------------------- | ----------------------------------------------------------------------------------- |
| `:MiseInstall [names...]` | Install tools. With no args, installs all `ensure_installed` tools.                 |
| `:MiseUpdate [names...]`  | Update tools via `mise upgrade`. With no args, updates all `ensure_installed` tools. |
| `:MiseStatus`             | Show install status of all `ensure_installed` tools.                                |
| `:MiseShow`               | Open a floating window displaying tool status.                                      |

All commands support tab completion from the tool registry.

### Raw mise_id

In addition to registry names, raw mise package identifiers can be used in
`:MiseInstall` or `:MiseUpdate`. This allows installing any tool mise supports
without adding it to the registry first:

```vim
" Install by registry name
:MiseInstall lua_ls

" Install by raw mise_id
:MiseInstall npm:@tailwindcss/language-server
:MiseInstall go:golang.org/x/tools/gopls
:MiseInstall cargo:taplo-cli
```

Supported mise backends include `npm:`, `cargo:`, `go:`, `pipx:`, `aqua:`,
`github:`, and more. See
[mise backends](https://mise.jdx.dev/dev-tools/backends/) for the full list.

## Health Check

Run `:checkhealth mise-tools` to verify:

- mise binary is on PATH
- mise version
- Each `ensure_installed` tool is available

## Built-in Registry

The plugin ships with a built-in registry mapping server names to mise package
identifiers. When a server in `ensure_installed` has a registry entry, the
plugin knows which mise package to install and which binary to check.

For servers **not** in the registry, the plugin falls back to `cmd[1]` from
`vim.lsp.config` to determine the binary to check on PATH, and uses the
server name as the mise_id.

### LSP Servers

| Name            | mise package                       | Executable                    |
| --------------- | ---------------------------------- | ----------------------------- |
| `lua_ls`        | `lua-language-server`              | `lua-language-server`         |
| `rust_analyzer` | `rust-analyzer`                    | `rust-analyzer`               |
| `taplo`         | `taplo`                            | `taplo`                       |
| `marksman`      | `marksman`                         | `marksman`                    |
| `zls`           | `zls`                              | `zls`                         |
| `helm_ls`       | `helm-ls`                          | `helm_ls`                     |
| `terraform_ls`  | `terraform-ls`                     | `terraform-ls`                |
| `elixir_ls`     | `elixir-ls`                        | `elixir-ls`                   |
| `pyright`       | `npm:pyright`                      | `pyright-langserver`          |
| `basedpyright`  | `npm:basedpyright`                 | `basedpyright-langserver`     |
| `ts_ls`         | `npm:typescript-language-server`   | `typescript-language-server`  |
| `bashls`        | `npm:bash-language-server`         | `bash-language-server`        |
| `yamlls`        | `npm:yaml-language-server`         | `yaml-language-server`        |
| `jsonls`        | `npm:vscode-langservers-extracted` | `vscode-json-language-server` |
| `html`          | `npm:vscode-langservers-extracted` | `vscode-html-language-server` |
| `cssls`         | `npm:vscode-langservers-extracted` | `vscode-css-language-server`  |
| `gopls`         | `go:golang.org/x/tools/gopls`      | `gopls`                       |

### Linters & Formatters

| Name         | mise package | Executable   |
| ------------ | ------------ | ------------ |
| `ruff`       | `ruff`       | `ruff`       |
| `shellcheck` | `shellcheck` | `shellcheck` |
| `stylua`     | `stylua`     | `stylua`     |
| `shfmt`      | `shfmt`      | `shfmt`      |

The registry can be extended via the `registry` option in `setup()`.

## Fun Fact

Neovim itself can be installed via mise: `mise use --global neovim`.

## License

MIT
