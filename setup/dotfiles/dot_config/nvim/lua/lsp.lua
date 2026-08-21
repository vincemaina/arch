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
    -- Validation is OFF until asked for, per dialect. Without this the server
    -- attaches, answers completions and reports nothing at all - a misspelled
    -- property is simply accepted in silence, which reads as "css has no
    -- diagnostics" rather than as a missing setting.
    settings = {
      css  = { validate = true },
      scss = { validate = true },
      less = { validate = true },
    },
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
-- Servers that come from pacman
-- ---------------------------------------------------------------------------
--
-- These are on PATH, so they are named plainly rather than by absolute path -
-- unlike the npm ones above, which live somewhere nothing searches.

local packaged_servers = {
  -- Types, navigation and hover. Not linting or formatting: pyright does
  -- neither, which is why ruff is here too.
  pyright = {
    cmd = { 'pyright-langserver', '--stdio' },
    filetypes = { 'python' },
    root_markers = root('pyproject.toml', 'setup.py', 'setup.cfg',
                        'requirements.txt', 'Pipfile'),
    settings = {
      python = {
        analysis = {
          autoSearchPaths = true,
          useLibraryCodeForTypes = true,
          -- basic rather than strict. Strict reports a great deal about code
          -- that works, which is the fastest way to start ignoring
          -- diagnostics altogether.
          typeCheckingMode = 'basic',
        },
      },
    },
  },

  -- Linting and formatting, and fast enough to run on every keystroke. ruff
  -- deliberately has no hover or go-to-definition, so it sits alongside
  -- pyright rather than replacing it.
  ruff = {
    cmd = { 'ruff', 'server' },
    filetypes = { 'python' },
    root_markers = root('pyproject.toml', 'ruff.toml', '.ruff.toml'),
  },

  ts_ls = {
    cmd = { 'typescript-language-server', '--stdio' },
    filetypes = { 'javascript', 'javascriptreact', 'typescript',
                  'typescriptreact' },
    root_markers = root('tsconfig.json', 'jsconfig.json', 'package.json'),
  },

  marksman = {
    cmd = { 'marksman', 'server' },
    filetypes = { 'markdown' },
    root_markers = root('.marksman.toml'),
  },
}

-- ---------------------------------------------------------------------------

function M.setup()
  local enabled = {}

  local all = vim.tbl_extend('error', npm_servers, packaged_servers)

  for name, config in pairs(all) do
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
  M.expected = vim.tbl_keys(all)
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

-- ---------------------------------------------------------------------------
-- The keys
-- ---------------------------------------------------------------------------
--
-- Set here rather than left as 0.11's defaults, because the shortcuts policy
-- for this desktop is that every binding is one that was chosen - and because
-- the defaults were not surviving init.lua's pruning intact. That pruning
-- deletes every mapping not named in its KEEP list; the LSP entries named there
-- were the ones somebody remembered, so K, ]d and [d were removed and nobody
-- noticed until hover was reached for and did nothing.
--
-- Set globally rather than buffer-local on LspAttach. Buffer-local is tidier -
-- the keys would exist only where a server can answer them - but the shortcuts
-- panel asks a headless neovim what is mapped, with no file open, and would
-- therefore never see them. Discoverable beats tidy.
--
-- gd is the addition. 0.11 ships grr, gri and grt but nothing for the jump
-- people actually make most, because <C-]> goes through tagfunc instead - which
-- works and is not what anyone's hands do.
local keys = {
  { 'gd',  vim.lsp.buf.definition,      'Go to definition' },
  { 'gD',  vim.lsp.buf.declaration,     'Go to declaration' },
  { 'grr', vim.lsp.buf.references,      'Find references' },
  { 'gri', vim.lsp.buf.implementation,  'Go to implementation' },
  { 'grt', vim.lsp.buf.type_definition, 'Go to type definition' },
  { 'grn', vim.lsp.buf.rename,          'Rename the symbol under the cursor' },
  { 'gra', vim.lsp.buf.code_action,     'Code actions' },
  { 'gO',  vim.lsp.buf.document_symbol, 'List symbols in this document' },
  { 'K',   vim.lsp.buf.hover,           'Show what is under the cursor' },
  { ']d',  function() vim.diagnostic.jump({ count =  1, float = true }) end, 'Next diagnostic' },
  { '[d',  function() vim.diagnostic.jump({ count = -1, float = true }) end, 'Previous diagnostic' },
  { '<leader>d', vim.diagnostic.open_float, 'Show the diagnostic under the cursor' },
  { '<leader>q', vim.diagnostic.setloclist, 'List every diagnostic in this file' },
}

for _, k in ipairs(keys) do
  vim.keymap.set('n', k[1], k[2], { desc = k[3] })
end

-- gra in visual mode too, since a code action over a selection is how an
-- extract-to-function is offered.
vim.keymap.set('v', 'gra', vim.lsp.buf.code_action, { desc = 'Code actions' })

-- ---------------------------------------------------------------------------
-- Formatting
-- ---------------------------------------------------------------------------
--
-- FORMAT ON SAVE IS DELIBERATELY OFF.
--
-- It is the default in most example configurations, and it is the wrong default
-- here. Opening a file to read it and saving out of habit would reformat the
-- whole thing, in a repository that has its own style and no formatter config
-- of its own - producing a diff nobody asked for, in a file that was not being
-- worked on. That is the same objection as the shortcuts policy this editor
-- follows: nothing should happen that was not chosen.
--
-- So formatting is a key, and the key is <leader>f.
--
-- Every language here formats through its language server except markdown -
-- ruff for python, ts_ls for javascript and typescript, and the vscode servers
-- for html, css and json all advertise textDocument/formatting. marksman does
-- not, so markdown goes through prettier as an ordinary formatprg, which is a
-- built-in mechanism and needs no plugin.
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'markdown',
  callback = function()
    vim.opt_local.formatprg = 'prettier --parser markdown'
  end,
  desc = 'marksman does not format; prettier does',
})

local function format()
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
    if client:supports_method('textDocument/formatting') then
      vim.lsp.buf.format({ async = false })
      return
    end
  end

  -- No server offers it. formatprg is the fallback, applied to the whole buffer
  -- with the cursor put back - gggqG on its own leaves you at the top.
  if vim.bo.formatprg ~= '' then
    local view = vim.fn.winsaveview()
    vim.cmd('silent normal! gggqG')
    vim.fn.winrestview(view)
    return
  end

  vim.notify('Nothing formats ' .. (vim.bo.filetype == '' and 'this buffer'
    or vim.bo.filetype), vim.log.levels.WARN)
end

vim.keymap.set('n', '<leader>f', format, { desc = 'Format the buffer' })

return M
