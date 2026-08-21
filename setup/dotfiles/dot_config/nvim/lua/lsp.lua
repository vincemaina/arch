-- Language servers.
--
-- nvim 0.12 configures these itself through vim.lsp.config and vim.lsp.enable,
-- so nvim-lspconfig is not needed to describe a server - only to supply
-- defaults for servers nobody wants to describe. With this few, describing them
-- is clearer than depending on a plugin to know what they are called.
--
-- WHY THE COMMANDS ARE ABSOLUTE PATHS
--
-- These servers are npm packages installed into ~/.local/lib/language-servers,
-- and that directory is not on anyone's PATH. That is deliberate: putting it
-- there would mean depending on the session PATH, which this desktop has
-- already been bitten by twice - the launcher's desktop entries and the bar's
-- click commands both had to learn to name things absolutely because
-- ~/.local/bin is not on the PATH sway hands to what it spawns.
--
-- Naming them here costs one variable and removes the whole class of problem.

local M = {}

-- The npm-installed servers. See run_onchange_after_install-language-servers.sh
-- for how they get there, and dot_local/lib/language-servers/package.json for
-- what is pinned.
local npm_bin = vim.fn.expand('~/.local/lib/language-servers/node_modules/.bin')

-- The html and css servers offer no completions at all unless the client says
-- it supports snippets. That much is a documented quirk. What is not documented
-- is that handing vim.lsp.config a partial `capabilities` table REPLACES the
-- defaults rather than merging into them - so declaring only snippetSupport
-- left the server believing the editor could do nothing else, and it declined
-- to attach at all. No error: the buffer simply had no client.
--
-- So start from the real defaults and add to them.
local function snippet_capabilities()
  local caps = vim.lsp.protocol.make_client_capabilities()
  caps.textDocument.completion.completionItem.snippetSupport = true
  return caps
end

-- Common to every server here. root_markers is what decides the project
-- directory: the first marker found walking upwards wins, and .git last means a
-- repository is the fallback when a language's own marker is absent.
local function root(...)
  local markers = { ... }
  table.insert(markers, '.git')
  return markers
end

-- ---------------------------------------------------------------------------
-- Servers that come from npm
-- ---------------------------------------------------------------------------
--
-- html, css and json come from one package, vscode-langservers-extracted, which
-- is the language servers pulled out of VS Code. Emmet is separate.
--
-- Each needs --stdio; they speak LSP over stdin and stdout and do nothing at all
-- without it, which is a quiet failure rather than an error.

local npm_servers = {
  html = {
    cmd = { npm_bin .. '/vscode-html-language-server', '--stdio' },
    filetypes = { 'html' },
    root_markers = root('package.json'),
    capabilities = snippet_capabilities(),
    init_options = {
      provideFormatter = true,
      embeddedLanguages = { css = true, javascript = true },
    },
  },

  cssls = {
    cmd = { npm_bin .. '/vscode-css-language-server', '--stdio' },
    filetypes = { 'css', 'scss', 'less' },
    root_markers = root('package.json'),
    capabilities = snippet_capabilities(),
    init_options = { provideFormatter = true },
  },

  jsonls = {
    cmd = { npm_bin .. '/vscode-json-language-server', '--stdio' },
    filetypes = { 'json', 'jsonc' },
    root_markers = root('package.json'),
    init_options = { provideFormatter = true },
  },

  emmet = {
    cmd = { npm_bin .. '/emmet-language-server', '--stdio' },
    -- Emmet is an abbreviation expander, so it belongs anywhere markup is
    -- written rather than only in .html files.
    filetypes = { 'html', 'css', 'scss', 'less',
                  'javascriptreact', 'typescriptreact' },
    root_markers = root('package.json'),
  },
}

-- ---------------------------------------------------------------------------

function M.setup()
  local enabled = {}

  for name, config in pairs(npm_servers) do
    -- Only enable a server whose executable is actually there. A missing one
    -- would otherwise fail on every matching file with an error about a command
    -- that could not be spawned, which says nothing useful about the cause -
    -- the cause is that ./sync.sh has not run since the list changed.
    if vim.fn.executable(config.cmd[1]) == 1 then
      vim.lsp.config(name, config)
      table.insert(enabled, name)
    end
  end

  if #enabled > 0 then
    vim.lsp.enable(enabled)
  end

  M.enabled = enabled
  M.expected = vim.tbl_keys(npm_servers)
end

-- ---------------------------------------------------------------------------
-- What happens when a server attaches
-- ---------------------------------------------------------------------------
--
-- nvim 0.11 gave LSP its own default keymaps, and they are already there
-- without configuring anything: K hovers, grn renames, gra is code actions,
-- grr finds references, gri goes to implementation, gO lists document symbols,
-- and Ctrl-S in insert mode shows signature help. Repeating them here would be
-- restating the defaults, which is how a config starts drifting from the manual.
--
-- Completion is the one thing that does NOT come on by itself. 0.12 ships
-- vim.lsp.completion, and it stays off until a buffer asks for it - so a server
-- can be attached and answering, with nothing ever appearing as you type. That
-- was the state this was in: four servers connected and no completion anywhere.
--
-- autotrigger means it fires on the characters the server nominates - `<` in
-- html, `.` in most languages - rather than only on Ctrl-X Ctrl-O. That is the
-- difference between completion existing and completion being usable.
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client:supports_method('textDocument/completion') then
      vim.lsp.completion.enable(true, args.data.client_id, args.buf, {
        autotrigger = true,
      })
    end
  end,
  desc = 'Turn on LSP completion, which is off by default',
})

-- popup is what makes the completion menu show documentation beside it rather
-- than only a list of names, and noselect stops the first entry being inserted
-- before it has been chosen.
vim.opt.completeopt = { 'menu', 'menuone', 'noselect', 'popup' }

-- Diagnostics, shown rather than merely collected. The defaults in 0.12 put
-- them in the sign column and nowhere else, so a message has to be hovered for.
vim.diagnostic.config({
  virtual_text = { current_line = true },
  severity_sort = true,
  float = { border = 'rounded', source = true },
})

return M
