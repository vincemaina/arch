-- Neovim.
--
-- Built from scratch on what 0.12 already provides rather than on a
-- distribution, which is a much smaller job than it used to be. This version
-- ships a plugin manager (vim.pack), LSP configuration (vim.lsp.config),
-- completion (vim.lsp.completion), treesitter and `gc` commenting - all things
-- a guide written a year ago would have you install four plugins for.
--
-- Checked on this machine rather than taken from release notes. Bare startup
-- with no configuration measures 15ms, which is the budget everything here
-- spends from.
--
-- WHAT IS DELIBERATELY NOT HERE
--
-- Language servers, formatting and linting are TASK-81. The colourscheme is
-- TASK-82, so until then this uses the default and looks like nothing else on
-- the desktop. Running SQL is TASK-83. Keeping those separate is what stops
-- this file becoming a distribution nobody understands.
--
-- THE PLUGIN LOCKFILE, WHEN THERE IS ONE
--
-- vim.pack writes $XDG_CONFIG_HOME/nvim/nvim-pack-lock.json - inside the
-- directory chezmoi owns. That is the same shape as the mimeapps.list problem:
-- a file both the repository and a program write.
--
-- The resolution is different here, though, and it is the one the lockfile
-- deserves: track it. A lockfile changing IS a deliberate act - you ran
-- vim.pack.update() and chose to take new plugin revisions - so it should show
-- up as a diff and be committed, exactly like a package manifest. sync.sh
-- already prints the `chezmoi re-add` command for a file that differs, which is
-- the whole workflow.
--
-- The alternative, ignoring it, would mean two machines syncing this repository
-- could end up on different plugin revisions, which is the thing a lockfile
-- exists to prevent.

-- Space is the leader, and unmapping it first stops it also moving the cursor
-- right in normal mode while you are part-way through a sequence.
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '
vim.keymap.set({ 'n', 'v' }, '<Space>', '<Nop>', { silent = true })

-- ---------------------------------------------------------------------------
-- Options
-- ---------------------------------------------------------------------------

local o = vim.opt

o.number = true
-- Relative numbers make `12j` a thing you can see rather than count. The
-- current line still shows its absolute number, which is what `number` above
-- is doing alongside this.
o.relativenumber = true

-- Four spaces, no tabs, as the default. Per-language overrides are below -
-- javascript and its relatives conventionally use two, and fighting a
-- language's convention is a losing game when the formatter will win anyway.
o.expandtab = true
o.shiftwidth = 4
o.tabstop = 4
o.softtabstop = 4
o.smartindent = true

-- Case-insensitive search until you type a capital, which is almost always the
-- behaviour wanted and almost never the one configured.
o.ignorecase = true
o.smartcase = true

-- Undo that survives closing the file. The history lives in the state
-- directory, not here, so it is not something the repository tracks.
o.undofile = true

-- The system clipboard is the only clipboard. On Wayland this goes through
-- wl-clipboard, which is a declared package because the screenshot helper
-- already needed it.
o.clipboard = 'unnamedplus'

-- Always reserve the sign column. Without this the whole buffer shifts sideways
-- the moment a diagnostic appears, which is far more distracting than a column
-- of empty space.
o.signcolumn = 'yes'

-- Keep some context above and below the cursor rather than working on the last
-- line of the screen.
o.scrolloff = 8

-- New splits go where the eye expects: to the right, and below.
o.splitright = true
o.splitbelow = true

-- True colour, which the terminal supports and which the colourscheme in
-- TASK-82 will need.
o.termguicolors = true

-- Do not wrap code. Prose is handled per-filetype below, where wrapping is
-- right and breaking mid-word is not.
o.wrap = false

-- Faster than the 4s default, which is what CursorHold and the swap file wait
-- on. 250ms matches the keyboard repeat delay set in the sway config, for no
-- deeper reason than that it is the same order of "responsive".
o.updatetime = 250

-- Ask rather than refuse when quitting with unsaved changes.
o.confirm = true

-- ---------------------------------------------------------------------------
-- Keymaps
-- ---------------------------------------------------------------------------
--
-- Deliberately few. Every binding here has to be remembered, and the ones that
-- earn their place are the ones fixing something actively annoying rather than
-- the ones saving a keystroke.

-- Escape clears the search highlight as well as leaving whatever mode you are
-- in. Nothing else wants Escape in normal mode.
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Move between splits without the Ctrl-w prefix. Note these are nvim splits,
-- not sway windows - sway has $mod+h/j/k/l for that, and the two do not
-- collide because sway takes its bindings before the terminal sees them.
vim.keymap.set('n', '<C-h>', '<C-w>h', { desc = 'Split left' })
vim.keymap.set('n', '<C-j>', '<C-w>j', { desc = 'Split down' })
vim.keymap.set('n', '<C-k>', '<C-w>k', { desc = 'Split up' })
vim.keymap.set('n', '<C-l>', '<C-w>l', { desc = 'Split right' })

-- Keep the cursor where it was when joining lines, and keep the search result
-- centred when jumping through matches. Both are small and both are the kind of
-- thing that is invisible until it is missing.
vim.keymap.set('n', 'J', 'mzJ`z')
vim.keymap.set('n', 'n', 'nzzzv')
vim.keymap.set('n', 'N', 'Nzzzv')

-- ---------------------------------------------------------------------------
-- Per-language indentation
-- ---------------------------------------------------------------------------
--
-- Two spaces where the language's ecosystem uses two. This is not a preference
-- so much as an admission: prettier and the rest will reformat to the community
-- convention regardless, so matching it here avoids the editor and the
-- formatter disagreeing on every save.

local indent_two = { 'javascript', 'javascriptreact', 'typescript',
                     'typescriptreact', 'html', 'css', 'scss', 'json',
                     'jsonc', 'yaml', 'lua', 'markdown' }

vim.api.nvim_create_autocmd('FileType', {
  pattern = indent_two,
  callback = function()
    vim.bo.shiftwidth = 2
    vim.bo.tabstop = 2
    vim.bo.softtabstop = 2
  end,
  desc = 'Two-space indent for languages whose ecosystems use two',
})

-- Prose wraps, and wraps at words rather than mid-word. `linebreak` alone does
-- nothing without `wrap`, which is off globally above.
vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'markdown', 'text', 'gitcommit' },
  callback = function()
    vim.wo.wrap = true
    vim.wo.linebreak = true
  end,
  desc = 'Wrap prose at word boundaries',
})

-- Briefly highlight whatever was just yanked, so it is obvious what went to the
-- clipboard. One of the few genuinely useful things that costs nothing.
vim.api.nvim_create_autocmd('TextYankPost', {
  callback = function() vim.hl.on_yank() end,
  desc = 'Flash the yanked text',
})

-- ---------------------------------------------------------------------------
-- Treesitter
-- ---------------------------------------------------------------------------
--
-- Parsers come from pacman, not from a plugin that downloads and compiles them
-- at runtime. That is the same argument that ruled out Mason for language
-- servers on TASK-73: anything installed outside the manifests is invisible to
-- this repository and absent from a rebuilt machine.
--
-- Nvim ships c, lua, markdown, query, vim and vimdoc. The Arch repositories add
-- python, javascript and bash, and those are declared in packages/dev.txt.
--
-- NOT AVAILABLE, and a known gap rather than an oversight: typescript, sql,
-- html, css, json, yaml and toml have no package. They land in the same
-- decision as the missing language servers - see TASK-84 and TASK-43. Until
-- then those filetypes get vim's regex highlighting, which is worse but not
-- nothing.
-- pcall around `start` itself, and not around a check beforehand. The obvious
-- guard - pcall(vim.treesitter.get_parser, ...) - looks right and does not
-- work: get_parser returns nil rather than raising when there is no parser, so
-- pcall reports success and `start` then throws anyway. Opening any python or
-- sql file printed a stack trace, which is exactly the sort of thing that looks
-- correct in the file and is wrong on screen.
vim.api.nvim_create_autocmd('FileType', {
  callback = function(args)
    local lang = vim.treesitter.language.get_lang(args.match)
    if lang then
      pcall(vim.treesitter.start, args.buf, lang)
    end
  end,
  desc = 'Enable treesitter wherever a parser is actually installed',
})
