# mise-tools.nvim

Manage LSP servers, linters, and formatters using [mise](https://mise.jdx.dev)
from Neovim.

Instead of using a Neovim-specific tool installer like mason.nvim,
mise-tools.nvim leverages mise — a polyglot tool version manager — so your dev
tools are available both inside Neovim and on the command line.

## Requirements

- Neovim >= 0.10
- [mise](https://mise.jdx.dev/getting-started.html) installed and activated in
  your shell

## Installation

### Package Managers

Add something like below to your plugins config:

```lua
{
  "tonyxwz/mise-tools.nvim",
  opts = {
    ensure_installed = { "lua_ls", "pyright", "gopls" },
  },
}
```

### Manual (native packages)

```bash
mkdir -p ~/.local/share/nvim/site/pack/plugins/start
git clone https://github.com/tonyxwz/mise-tools.nvim \
  ~/.local/share/nvim/site/pack/plugins/start/mise-tools.nvim
```

Then in your `init.lua`:

```lua
require("mise-tools").setup({
  ensure_installed = { "lua_ls", "pyright", "gopls" },
})
```

## Setup

```lua
require("mise-tools").setup({
  -- List of tools to ensure are installed.
  -- Names match lspconfig server names where applicable.
  ensure_installed = { "lua_ls", "pyright", "gopls" },

  -- Automatically install missing tools when setup() is called.
  -- Default: true
  auto_install = true,

  -- "global" runs `mise use --global <tool>` (available everywhere).
  -- "local" runs `mise use <tool>` (available only in the current directory).
  -- Default: "global"
  scope = "global",

  -- Override or extend the built-in registry.
  -- Each entry maps a friendly name to a mise package spec.
  registry = {
    -- Override an existing entry
    pyright = { mise_id = "npm:basedpyright", bin = "basedpyright-langserver", type = "lsp" },
    -- Add a custom tool
    my_lsp = { mise_id = "npm:my-custom-lsp", bin = "my-custom-lsp", type = "lsp" },
  },
})
```

## Commands

| Command                   | Description                                                                          |
| ------------------------- | ------------------------------------------------------------------------------------ |
| `:MiseInstall [names...]` | Install tools. With no args, installs all `ensure_installed` tools.                  |
| `:MiseUpdate [names...]`  | Update tools via `mise upgrade`. With no args, updates all `ensure_installed` tools. |
| `:MiseStatus`             | Show install status of all `ensure_installed` tools.                                 |

All commands support tab completion from the tool registry.

### Raw mise_id

In addition to registry names, you can use raw mise package identifiers anywhere
— in `ensure_installed`, `:MiseInstall`, or `:MiseUpdate`. This lets you install
any tool mise supports without adding it to the registry first:

```lua
require("mise-tools").setup({
  ensure_installed = {
    "lua_ls",                          -- registry name
    "npm:@tailwindcss/language-server", -- raw mise_id
    "cargo:taplo-cli",                 -- raw mise_id
  },
})
```

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

The plugin ships with a built-in registry mapping friendly names to mise package
identifiers. The current list:

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

You can extend this registry via the `registry` option in `setup()`.

## How It Works

mise-tools.nvim does **not** configure your LSP client. It only ensures tools
are installed and on your PATH via mise. You still configure
[nvim-lspconfig](https://github.com/neovim/nvim-lspconfig) (or any LSP client)
yourself:

```lua
-- mise-tools ensures the binary is installed and on PATH
require("mise-tools").setup({
  ensure_installed = { "lua_ls" },
})

-- You configure lspconfig as usual
require("lspconfig").lua_ls.setup({})
```

This separation means your tools work everywhere — in Neovim, on the command
line, in CI, and with other editors.

## License

MIT
