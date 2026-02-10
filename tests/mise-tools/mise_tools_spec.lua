local mise_tools = require("mise-tools")
local registry = require("mise-tools.registry")

describe("mise-tools", function()
  -- Reset state before each test
  before_each(function()
    mise_tools.config = {
      ensure_installed = {},
      auto_install = false,
      scope = "global",
      registry = {},
    }
    mise_tools._registry = {}
    mise_tools._handled = {}
    -- Clear autocommands from previous setup() calls
    pcall(vim.api.nvim_del_augroup_by_name, "mise-tools")
  end)

  describe("setup", function()
    it("uses default config when no args given", function()
      mise_tools.setup()
      assert.are.same({}, mise_tools.config.ensure_installed)
      assert.is_true(mise_tools.config.auto_install)
      assert.are.equal("global", mise_tools.config.scope)
    end)

    it("merges user config into defaults", function()
      mise_tools.setup({
        ensure_installed = { "lua_ls", "pyright" },
        auto_install = false,
        scope = "local",
      })
      assert.are.same({ "lua_ls", "pyright" }, mise_tools.config.ensure_installed)
      assert.are.equal("local", mise_tools.config.scope)
      assert.is_false(mise_tools.config.auto_install)
    end)

    it("accepts ensure_installed = true", function()
      mise_tools.setup({
        ensure_installed = true,
        auto_install = false,
      })
      assert.is_true(mise_tools.config.ensure_installed)
    end)

    it("creates a FileType autocommand group", function()
      mise_tools.setup()
      local group = vim.api.nvim_get_autocmds({ group = "mise-tools", event = "FileType" })
      assert.is_true(#group > 0)
    end)

    it("resets _handled state on each setup call", function()
      mise_tools._handled = { lua_ls = true }
      mise_tools.setup({ auto_install = false })
      assert.are.same({}, mise_tools._handled)
    end)
  end)

  describe("get_ensure_installed", function()
    it("returns empty list for default config", function()
      mise_tools.setup()
      -- default ensure_installed is {}, auto_install is true but no servers listed
      local names = mise_tools.get_ensure_installed()
      assert.are.equal("table", type(names))
    end)

    it("returns the list when ensure_installed is a table", function()
      mise_tools.setup({
        ensure_installed = { "lua_ls", "pyright" },
        auto_install = false,
      })
      local names = mise_tools.get_ensure_installed()
      assert.are.same({ "lua_ls", "pyright" }, names)
    end)

    it("returns a table when ensure_installed is true", function()
      mise_tools.setup({
        ensure_installed = true,
        auto_install = false,
      })
      local names = mise_tools.get_ensure_installed()
      assert.are.equal("table", type(names))
    end)
  end)

  describe("registry", function()
    it("built-in registry has expected entries", function()
      assert.is_not_nil(registry.lua_ls)
      assert.are.equal("lua-language-server", registry.lua_ls.mise_id)
      assert.are.equal("lua-language-server", registry.lua_ls.bin)
      assert.are.equal("lsp", registry.lua_ls.type)
    end)

    it("built-in registry contains npm-based servers", function()
      assert.is_not_nil(registry.pyright)
      assert.are.equal("npm:pyright", registry.pyright.mise_id)
      assert.are.equal("lsp", registry.pyright.type)
    end)

    it("built-in registry contains go-based servers", function()
      assert.is_not_nil(registry.gopls)
      assert.are.equal("go:golang.org/x/tools/gopls", registry.gopls.mise_id)
    end)

    it("get_registry returns merged registry after setup", function()
      mise_tools.setup({
        auto_install = false,
        registry = {
          my_custom = { mise_id = "npm:my-custom-lsp", bin = "my-custom-lsp", type = "lsp" },
        },
      })

      local merged = mise_tools.get_registry()
      assert.is_not_nil(merged.lua_ls)
      assert.is_not_nil(merged.my_custom)
      assert.are.equal("npm:my-custom-lsp", merged.my_custom.mise_id)
    end)

    it("user registry overrides built-in entries", function()
      mise_tools.setup({
        auto_install = false,
        registry = {
          pyright = { mise_id = "npm:basedpyright", bin = "basedpyright-langserver", type = "lsp" },
        },
      })

      local merged = mise_tools.get_registry()
      assert.are.equal("npm:basedpyright", merged.pyright.mise_id)
      assert.are.equal("basedpyright-langserver", merged.pyright.bin)
    end)
  end)

  describe("raw mise_id support", function()
    it("accepts raw mise_ids in ensure_installed without errors", function()
      mise_tools.setup({
        auto_install = false,
        ensure_installed = { "lua_ls", "npm:some-unknown-tool", "cargo:taplo-cli" },
      })
      assert.are.same(
        { "lua_ls", "npm:some-unknown-tool", "cargo:taplo-cli" },
        mise_tools.config.ensure_installed
      )
    end)

    it("accepts raw mise_ids in install() arguments", function()
      mise_tools.setup({ auto_install = false })
      assert.has_no.errors(function()
        mise_tools.install({ "npm:some-unknown-tool" })
      end)
    end)
  end)

  describe("tool types", function()
    it("all entries have a valid type field", function()
      local valid_types = { lsp = true, linter = true, formatter = true }
      for name, entry in pairs(registry) do
        assert.is_not_nil(entry.type, string.format("%s missing type field", name))
        assert.is_true(valid_types[entry.type], string.format("%s has invalid type: %s", name, entry.type))
      end
    end)

    it("all entries have mise_id and bin fields", function()
      for name, entry in pairs(registry) do
        assert.is_not_nil(entry.mise_id, string.format("%s missing mise_id field", name))
        assert.is_not_nil(entry.bin, string.format("%s missing bin field", name))
        assert.is_true(#entry.mise_id > 0, string.format("%s has empty mise_id", name))
        assert.is_true(#entry.bin > 0, string.format("%s has empty bin", name))
      end
    end)
  end)
end)
