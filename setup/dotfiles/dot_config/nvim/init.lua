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
-- Formatting and linting, and the servers that come from pacman, are TASK-81. The colourscheme is
-- TASK-82, so until then this uses the default and looks like nothing else on
-- the desktop. Running SQL is TASK-83. Keeping those separate is what stops
-- this file becoming a distribution nobody understands.
--
-- THE PLUGIN LOCKFILE
--
-- This paragraph said "when there is one" until TASK-199, which added the first
-- plugin and turned every sentence below from a plan into a description. The
-- list itself is lua/plugins.lua.
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
vim.keymap.set({ 'n', 'v' }, '<Space>', '<Nop>', { silent = true, desc = 'Leader (does nothing on its own)' })

-- ---------------------------------------------------------------------------
-- Options
-- ---------------------------------------------------------------------------

local o = vim.opt

-- Absolute line numbers. Relative numbers were tried - they make `12j` a
-- thing you can see rather than count - and rejected: TASK-116, they read as
-- noise rather than as a distance once you are used to plain numbers.
o.number = true

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

-- Signs go IN the number column, and the number column is only as wide as the
-- numbers in it. Between them these are three of the six terminal columns that
-- used to sit between the window edge and the first character of the file -
-- measured with wincol(), not guessed.
--
-- `signcolumn = 'yes'` was here first, and its reason still holds: without a
-- reserved column the whole buffer shifts sideways the moment a diagnostic
-- appears, which is far more distracting than the empty space. `number` keeps
-- that promise and costs nothing, because there is no separate column to
-- reserve - a sign is drawn over the line number of the line it belongs to.
-- The trade is that on a line with a sign you see the sign instead of the
-- number, which is the same information you were going to look at anyway.
--
-- A sign is two cells wide, so 'yes' was two columns rather than one.
o.signcolumn = 'number'

-- 'numberwidth' is a MINIMUM, not a width: nvim widens it as the line count
-- grows, so 4 only ever meant "pad short files out". 2 is one digit and the
-- space after it, and a file of 100 lines still gets its three digits.
o.numberwidth = 2

-- Keep some context above and below the cursor rather than working on the last
-- line of the screen.
o.scrolloff = 8

-- Nothing below the end of the buffer. The column of ~ is vim saying a line
-- does not exist, which the absent line number already says - and it says it
-- in the same column the numbers use, so removing it hands that space back
-- rather than leaving a gap where it was.
o.fillchars:append({ eob = ' ' })

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
-- Nothing is bound that was not chosen
-- ---------------------------------------------------------------------------
--
-- Neovim ships 87 global mappings before any configuration at all. Most are
-- fine and a few are genuinely useful, but none of them was chosen, and the
-- cost of that is meeting one by accident and not knowing what happened - which
-- is the opposite of how every other keybinding on this desktop works, where
-- checks/sway-bindings.sh prints the complete table and fails on a duplicate.
--
-- So: every default mapping is deleted unless it is named below. Adding one
-- back is a line here, which means it was decided rather than inherited.
--
-- This does NOT touch vim's own grammar. dd, ciw, yy, %, K and the rest are the
-- editor's commands, not mappings, and are unaffected - the list below is only
-- about things nvim maps on top.
--
-- The 40 bracket pairs ([b ]b [q ]q [t ]t and friends) are the clearest case
-- for this: useful if you know them, invisible if you do not, and none of them
-- was ever mentioned.

-- Built-in plugins are disabled rather than un-mapped, because they load AFTER
-- this file and would simply put their mappings back. matchit is the one that
-- matters: it adds %, [%, ]%, g% and a%, none of which was chosen. Vim's own %
-- is a built-in motion and is unaffected - matchit only extends it to language
-- keywords.
vim.g.loaded_matchit = 1
vim.g.loaded_matchparen = 0     -- kept: highlighting the matching bracket is passive
vim.g.loaded_netrwPlugin = 1    -- yazi is the file manager; netrw maps gx and more
vim.g.loaded_tutor_mode_plugin = 1

local KEEP = {
  -- The LSP bindings are NOT kept here, deliberately. They became defaults in
  -- 0.11, and keeping a default is not the same as choosing one - which this
  -- config found out the expensive way. The pruning above removed K and ]d and
  -- [d along with everything else unlisted, because they were not written down,
  -- so hovering and stepping through diagnostics silently stopped working while
  -- rename and code actions kept going. The list looked deliberate and had a
  -- hole in it.
  --
  -- They are all set explicitly in lua/lsp.lua now, next to the servers they
  -- depend on, each with a description the shortcuts panel can show. Defaults
  -- describe themselves as 'vim.lsp.buf.code_action()', which is a function
  -- name rather than an answer to "what does this key do".

  -- Commenting, which replaced a plugin everyone used to install.
  ['gc']  = 'comment a motion',
  ['gcc'] = 'comment this line',

  -- Kept because this config sets them itself, further down.
  ['<Esc>'] = 'clear the search highlight',
  ['J'] = 'join lines without moving the cursor',
  ['n'] = 'next match, centred',
  ['N'] = 'previous match, centred',
}

-- Deleting is done before anything below adds its own, so the additions cannot
-- be removed by their own policy.
local removed = 0
for _, mode in ipairs({ 'n', 'i', 'v', 'x', 'o', 's', 'c', 't' }) do
  for _, map in ipairs(vim.api.nvim_get_keymap(mode)) do
    if not KEEP[map.lhs] then
      -- pcall because a handful are <Plug> mappings that refuse to be deleted,
      -- and one refusing is not a reason to stop removing the rest.
      if pcall(vim.keymap.del, mode, map.lhs) then
        removed = removed + 1
      end
    end
  end
end

-- EVERY MAPPING CARRIES A DESCRIPTION, and that is the enforceable half of the
-- policy. A description is what a person chose to write, so anything arriving
-- without one arrived without being chosen - a plugin's defaults, or a line
-- added in a hurry. checks/session.sh fails on a mapping with no description,
-- which turns "shortcuts should all be deliberate" from an intention into
-- something that breaks the build.
--
-- It is also what the shortcuts helper reads, so writing the description is not
-- an extra chore - it is the thing that makes the binding show up in the list.

-- Readable by the shortcuts helper, and by anyone wondering what happened.
vim.g.removed_default_mappings = removed
vim.g.kept_default_mappings = KEEP

-- ---------------------------------------------------------------------------
-- Keymaps
-- ---------------------------------------------------------------------------
--
-- Deliberately few. Every binding here has to be remembered, and the ones that
-- earn their place are the ones fixing something actively annoying rather than
-- the ones saving a keystroke.

-- Escape clears the search highlight as well as leaving whatever mode you are
-- in. Nothing else wants Escape in normal mode.
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>', { desc = 'Clear search highlight' })

-- Move between splits without the Ctrl-w prefix. Note these are nvim splits,
-- not sway windows - sway has $mod+h/j/k/l for that, and the two do not
-- collide because sway takes its bindings before the terminal sees them.
--
-- ONE, NOT FOUR, AND THE THREE ABSENCES ARE DELIBERATE. <C-k> is Escape,
-- <C-j> is Enter and <C-h> is Backspace now: keyd rewrites all three below the
-- compositor (setup/system/keyd/default.conf), so nvim receives the real key
-- and never sees the chord. Lines for them here would look exactly like the
-- one below and could never fire, which is the shape of nearly every bug this
-- repository has had. `<C-w>k`, `<C-w>j` and `<C-w>h` all still work, and are
-- now the only way to reach those three splits.
--
-- <C-f> was Tab from that same layer for a while and page-forward went with
-- it. TASK-124 took that one back out, so <C-f> pages forward here again and
-- there is nothing to work around. The keyd config says why f was the wrong
-- key to spend and what would be spent instead.
vim.keymap.set('n', '<C-l>', '<C-w>l', { desc = 'Split right' })

-- Keep the cursor where it was when joining lines, and keep the search result
-- centred when jumping through matches. Both are small and both are the kind of
-- thing that is invisible until it is missing.
vim.keymap.set('n', 'J', 'mzJ`z', { desc = 'Join lines, keeping the cursor put' })
vim.keymap.set('n', 'n', 'nzzzv', { desc = 'Next match, centred' })
vim.keymap.set('n', 'N', 'Nzzzv', { desc = 'Previous match, centred' })

-- Ctrl+S writes the file, which is the one thing every other editor on this
-- machine already agrees on. `update` rather than `write`: an unmodified
-- buffer is left alone rather than given a new mtime for nothing.
--
-- IT ARRIVES, WHICH IS NOT OBVIOUS. Ctrl+S is XOFF - the terminal's own
-- "stop sending" - and in a shell it suspends output until Ctrl+Q. It reaches
-- nvim because nvim puts the terminal in raw mode and turns that off, and
-- because nothing in between claims it: keyd's [control] layer rewrites j, k,
-- h, l and semicolon and not s, and foot binds only Ctrl+Shift+*. Measured by
-- sending a real 0x13 down a pty and reading the file back off disk, in both
-- modes, rather than by trying it once in a terminal.
--
-- `<cmd>` rather than `:` in insert mode, which is the whole reason both modes
-- can share one right-hand side: it runs the command without leaving the mode,
-- so you keep typing where you were.
vim.keymap.set({ 'n', 'i' }, '<C-s>', '<cmd>update<CR>', { desc = 'Write the file' })

-- Ctrl+Q leaves, which is the other half of the same habit and the other thing
-- every editor on this machine already agrees on. `confirm qa` rather than
-- `qa`: every window, and a prompt rather than a refusal or a silent discard
-- if something is still unsaved. `confirm` is written out even though
-- `o.confirm` above already turns the refusal into that dialog - a key whose
-- whole job is "close everything" should not depend on an option two hundred
-- lines away staying true.
--
-- IT ARRIVES, FOR THE SAME REASON CTRL+S DOES. Ctrl+Q is XON, the resume half
-- of the flow-control pair Ctrl+S starts: in a shell it un-freezes a terminal,
-- and zsh binds it to push-line on top of that. Neither is in the way here,
-- because nvim puts the terminal in raw mode and turns IXON off - and nothing
-- between claims it either: keyd's [control] layer rewrites k, semicolon, j, h
-- and l and not q, foot binds nothing on it, and sway took $mod+q rather than
-- Ctrl+q. Measured by sending a real 0x11 down a pty and watching a <C-q>
-- mapping fire, rather than by trying it once in a terminal.
--
-- WHAT IT COSTS IS BLOCKWISE VISUAL, AND THAT IS NOT A MAPPING.
--
-- Ctrl+Q was already doing something. It is vim's own alias for Ctrl+V - enter
-- blockwise visual mode - and being a built-in command rather than a mapping,
-- the pruning above never saw it. So this line is an overwrite, not a free key,
-- and the pruning's promise that nothing here was inherited does not cover it.
--
-- That would normally cost nothing, because Ctrl+V is the real key for the
-- mode. In this terminal Ctrl+V is not available: foot consumes it for paste
-- (TASK-187) and the program never sees it. Ctrl+Q was therefore the ONLY way
-- into blockwise visual on this machine, and taking it would have removed the
-- mode from the editor rather than moved it.
--
-- It does not, because foot's [text-bindings] send \x16 - the byte Ctrl+V makes
-- - on Ctrl+Shift+V. Measured, both halves, by reading the mode indicator back
-- off a pty rather than inferring it: 0x11 and 0x16 each put nvim in VISUAL
-- BLOCK today. So blockwise visual is Ctrl+Shift+V here, alongside the
-- interrupt and quoted-insert that moved to the same modifier for the same
-- reason. In any other terminal Ctrl+V still works and nothing was spent.
vim.keymap.set({ 'n', 'i' }, '<C-q>', '<cmd>confirm qa<CR>', { desc = 'Quit neovim' })

-- ---------------------------------------------------------------------------
-- Autosave
-- ---------------------------------------------------------------------------
--
-- Ctrl+S above is the write you decide on. This is the one you do not have to
-- remember, and it is here because forgetting had a visible cost: opening a
-- notes file was greeting this machine with E325 ATTENTION and a swap file
-- "modified: YES", which is nvim saying an earlier session died holding
-- changes that never reached the disk. Closing the terminal instead of
-- quitting is all it takes, and this machine had four of them.
--
-- MEASURED, AND IT IS WHY THERE IS NO SWAP-FILE CODE HERE. A stale swap file
-- is only a problem when it holds unsaved changes. kill -9 with a dirty buffer
-- and reopening the file produces the entire dialog; kill -9 after a write
-- produces nothing at all - nvim compares the swap against the file, finds
-- them identical, and deletes it on the way in without saying so. Saving IS
-- the fix. A SwapExists autocmd guessing which swap files are safe to delete
-- would be answering a question that no longer gets asked.
--
-- Debounced rather than on leaving insert mode, which was the other candidate:
-- a write on <Esc> never lands mid-word, but it also never happens while you
-- are still typing, which is exactly when the terminal gets closed. The trade
-- is that anything watching the file sometimes sees a half-finished line.
-- Accepted deliberately - see DECISIONS.md.

-- A second after the last keystroke: long enough that a burst of typing is one
-- write rather than dozens, short enough that "did that save?" is never worth
-- asking.
local AUTOSAVE_MS = 1000

-- All three are keyed by buffer number and all three are dropped on wipeout:
-- the pending timer, the mtime the file was last known to have on disk, and
-- whether writing this buffer has already failed once.
local autosave_timers = {}
local autosave_mtime = {}
local autosave_failed = {}

-- Buffers with no file behind them have nothing to write - the help viewer, a
-- terminal, the quickfix list, an unnamed scratch buffer. `nomodifiable` and
-- `readonly` are the ones where writing would be a mistake rather than a
-- no-op.
local function autosave_wanted(buf)
  return vim.api.nvim_buf_is_valid(buf)
    and not autosave_failed[buf]
    and vim.bo[buf].buftype == ''
    and vim.bo[buf].modifiable
    and not vim.bo[buf].readonly
    and vim.bo[buf].modified
    and vim.api.nvim_buf_get_name(buf) ~= ''
end

-- THE FILE CHANGING UNDERNEATH IS THE ONE CASE THAT MUST NOT BE WRITTEN, and
-- it is not an error case. `:update` does not fail when the file on disk has
-- changed since nvim read it - it asks, modally: "do you really want to write
-- to it (y/n)?". A prompt nobody asked for, arriving a second after you stop
-- typing, is worse than not saving, because it eats the next thing you press.
-- `git checkout` under an open buffer is enough to cause it, in this
-- repository more than most. So compare first and stay out of the way; a
-- deliberate Ctrl+S is the right place to answer that question.
local function autosave_file_moved(buf)
  local was = autosave_mtime[buf]
  return was ~= nil and vim.fn.getftime(vim.api.nvim_buf_get_name(buf)) ~= was
end

local function autosave_write(buf)
  if not autosave_wanted(buf) or autosave_file_moved(buf) then return end

  -- nvim_buf_call because the timer fires whenever it fires: by then the
  -- window may be showing something else, and `update` writes whatever buffer
  -- is current.
  --
  -- `silent` so "N lines written" does not overwrite the message area for a
  -- write nobody asked for. NOT `silent!`, which would swallow the errors as
  -- well - a write failing quietly once a second is the exact shape of bug
  -- this repository keeps finding.
  local ok, err = pcall(vim.api.nvim_buf_call, buf, function()
    vim.cmd('silent update')
  end)

  -- A write that cannot succeed will not start succeeding on the next
  -- keystroke: a file that is not writable, a directory that has been removed
  -- underneath. Say so once and stop, rather than repeating it for as long as
  -- the buffer is open.
  if not ok then
    autosave_failed[buf] = true
    vim.notify('Autosave stopped for this buffer: ' .. tostring(err),
      vim.log.levels.WARN)
  end
end

local function autosave_schedule(buf)
  if not autosave_wanted(buf) then return end

  local timer = autosave_timers[buf]
  if not timer then
    timer = vim.uv.new_timer()
    autosave_timers[buf] = timer
  end

  -- Starting a timer that is already running restarts it, and that restart is
  -- the whole debounce: the second is counted from the last change, not the
  -- first.
  timer:start(AUTOSAVE_MS, 0, vim.schedule_wrap(function()
    -- The completion popup being up means this is mid-word by definition, and
    -- writing dismisses it. Wait for the next quiet second instead.
    if vim.fn.pumvisible() == 1 then
      autosave_schedule(buf)
      return
    end
    autosave_write(buf)
  end))
end

vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
  callback = function(args) autosave_schedule(args.buf) end,
  desc = 'Autosave a second after the last change',
})

-- BufNewFile as well as BufReadPost, so a file that does not exist yet starts
-- with a known mtime (-1) rather than with none - otherwise the first write of
-- a new file is the one case the guard above cannot check.
vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufNewFile', 'BufWritePost' }, {
  callback = function(args)
    autosave_mtime[args.buf] = vim.fn.getftime(vim.api.nvim_buf_get_name(args.buf))
  end,
  desc = 'Remember the mtime the file has on disk',
})

vim.api.nvim_create_autocmd('BufWipeout', {
  callback = function(args)
    local timer = autosave_timers[args.buf]
    if timer then
      timer:stop()
      timer:close()
    end
    autosave_timers[args.buf] = nil
    autosave_mtime[args.buf] = nil
    autosave_failed[args.buf] = nil
  end,
  desc = 'Drop the autosave timer with the buffer',
})

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

-- ---------------------------------------------------------------------------
-- Lists continue themselves
-- ---------------------------------------------------------------------------
--
-- Enter in a markdown list item starts the next one: same bullet, same indent,
-- next number, an empty checkbox. Writing a list otherwise means retyping the
-- marker on every line, which is the kind of thing the editor should be doing.
--
-- `formatoptions+=r` is the built-in half of this and is not enough. It
-- continues the leaders in `comments`, which for markdown are -, *, + and >:
-- a numbered item does not increment, and a checkbox comes back as a bare
-- bullet with the box lost. The `n` flag does know about numbered lists, but
-- only to tell `gq` how to wrap one - it has nothing to do with Enter.
--
-- Buffer-local and markdown only, which also makes it the one mapping here
-- that checks/session.sh's "every mapping carries a description" pass cannot
-- see: that reads the global table. The description is written anyway, because
-- the reason for the rule does not depend on the check reaching it.

-- The marker the NEXT line should start with, the indent to put it at, and
-- whatever content this item already has. nil when the line is not a list item.
local function list_marker(line)
  local indent, bullet, rest = line:match('^([ \t]*)([-*+])[ \t]+(.*)$')

  -- A numbered item cannot also match the bullet pattern, so this is an
  -- alternative rather than a second chance: 1. or 2), incremented.
  local n_indent, number, punct, n_rest = line:match('^([ \t]*)(%d+)([.)])[ \t]+(.*)$')
  if n_indent then
    indent, bullet, rest = n_indent, (tonumber(number) + 1) .. punct, n_rest
  end
  if not indent then return nil end

  -- A checkbox is a bullet with a box in front of the content, and the new box
  -- is always unticked - copying [x] down the list would be actively wrong.
  local box, body = rest:match('^(%[[ xX]%])[ \t]+(.*)$')
  if box then return indent, bullet .. ' [ ] ', body end

  return indent, bullet .. ' ', rest
end

-- THE SPLIT IS DONE TO THE BUFFER, NOT BY SENDING KEYS, and the two attempts
-- that came first are worth recording because both looked right.
--
-- Returning `<CR>` and letting autoindent reproduce the indent works today and
-- only because `smartindent` happens to copy it; the moment markdown gets an
-- indentexpr it is someone else's decision. Returning `<CR><C-u>` and writing
-- the whole leader out to be sure is worse: measured, `<C-u>` at column 0 of
-- the fresh line finds nothing before the cursor and eats the line break
-- instead, because `backspace` contains `eol` - so Enter silently did nothing
-- at all on any unindented item, and worked on the indented ones.
--
-- Editing the text directly has no such question in it. It also means the
-- mapping cannot be an expr one, which may not change text.
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'markdown',
  callback = function(args)
    vim.keymap.set('i', '<CR>', function()
      local line = vim.api.nvim_get_current_line()
      local row, col = unpack(vim.api.nvim_win_get_cursor(0))

      -- With the completion popup open, Enter belongs to the popup.
      local indent, marker, content
      if vim.fn.pumvisible() == 0 then
        indent, marker, content = list_marker(line)
      end

      -- Not a list, or the cursor is still inside the marker rather than past
      -- it - splitting a marker in half should split a line, not make two.
      if not marker or col < #line - #content then
        -- 'i' rather than a bare 'n': feedkeys APPENDS to the typeahead by
        -- default, so a fast typist whose next keystrokes are already queued
        -- gets the newline after them rather than where it was pressed. That
        -- is not a theoretical race - it is what a scripted test does every
        -- time, which is how it was found.
        vim.api.nvim_feedkeys(vim.keycode('<CR>'), 'ni', false)
        return
      end

      -- An empty item is how you stop. Enter clears the marker instead of
      -- adding another one nobody asked for, which otherwise leaves deleting
      -- it by hand as the only way out of a list.
      if content == '' then
        vim.api.nvim_set_current_line('')
        vim.api.nvim_win_set_cursor(0, { row, 0 })
        return
      end

      local leader = indent .. marker
      vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, #line,
        { '', leader .. line:sub(col + 1) })
      vim.api.nvim_win_set_cursor(0, { row + 1, #leader })
    end, {
      buffer = args.buf,
      desc = 'Continue the list on the next line',
    })
  end,
  desc = 'Markdown lists continue themselves on Enter',
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
-- The queries have to be findable, and by default they are not.
--
-- A parser is only half of treesitter highlighting: the other half is a set of
-- queries saying which nodes are a keyword, a string, a function name. Arch's
-- tree-sitter-* packages ship both, but they put the queries in
-- /usr/share/tree-sitter/queries/<lang>/, which is not on nvim's runtimepath -
-- nvim only looks along that path, and its own bundled queries live in
-- /usr/share/nvim/runtime/queries/.
--
-- Without this line the result is worse than having no parser at all.
-- vim.treesitter.start() succeeds, and starting it DISABLES the regex syntax
-- highlighting that was colouring the file perfectly well - then finds no
-- queries and highlights nothing. A python file opens completely grey, with no
-- error anywhere to say why. That is exactly what happened, and it got past a
-- check that only looked for errors on startup.
vim.opt.runtimepath:append('/usr/share/tree-sitter')

-- pcall around `start` itself, and not around a check beforehand. The obvious
-- guard - pcall(vim.treesitter.get_parser, ...) - looks right and does not
-- work: get_parser returns nil rather than raising when there is no parser, so
-- pcall reports success and `start` then throws anyway. Opening any python or
-- sql file printed a stack trace, which is exactly the sort of thing that looks
-- correct in the file and is wrong on screen.
-- A parser is not enough: the highlight query has to exist too.
--
-- vim.treesitter.start() DISABLES regex syntax highlighting, so starting it
-- with a parser but no query leaves the file completely grey - worse than never
-- having installed the parser. Arch ships tree-sitter-bash with a parser and no
-- queries at all, so bash is exactly that case and there will be others.
--
-- Checking for the query before starting makes the failure impossible rather
-- than fixing it one language at a time: no query means treesitter stays off
-- and vim's regex highlighting keeps colouring the file, which is worse than
-- treesitter and much better than nothing.
vim.api.nvim_create_autocmd('FileType', {
  callback = function(args)
    local lang = vim.treesitter.language.get_lang(args.match)
    if not lang then return end
    local ok, query = pcall(vim.treesitter.query.get, lang, 'highlights')
    if ok and query then
      pcall(vim.treesitter.start, args.buf, lang)
    end
  end,
  desc = 'Enable treesitter only where both a parser and a highlight query exist',
})

-- ---------------------------------------------------------------------------
-- Language servers
-- ---------------------------------------------------------------------------
--
-- In their own module because there will be more of them: this covers the ones
-- that come from npm (TASK-84), and the packaged ones are TASK-81. Keeping the
-- list somewhere other than this file is what stops init.lua turning into the
-- distribution this was meant not to be.
-- ---------------------------------------------------------------------------
-- Colours
-- ---------------------------------------------------------------------------
--
-- Generated from the selected theme, like everything else on this desktop.
-- colors/arch.lua is a chezmoi template; edit .chezmoidata/themes.toml.
--
-- Before the language servers, so that if anything below it fails the editor is
-- at least readable rather than readable-and-grey.
vim.cmd.colorscheme('arch')

-- ---------------------------------------------------------------------------
-- Plugins
-- ---------------------------------------------------------------------------
--
-- AFTER the colourscheme, and that is not arbitrary either. The colourscheme is
-- what sets `vim.o.background` from the theme's declared mode, and the plugin
-- configuration branches on it - a light palette gets no heading bands. Called
-- earlier, it would read whatever `background` happened to be and configure the
-- editor for the wrong half of the themes.
--
-- The highlight ordering is unaffected by which side of this line it sits on:
-- vim.pack does not source a plugin's `plugin/` directory while init.lua is
-- being sourced, so the groups a plugin registers arrive after everything here
-- either way - and being registered with `default = true`, they lose to every
-- group the colourscheme named. lua/plugins.lua writes that out in full.
require('plugins').setup()

require('lsp').setup()

-- Machine-local configuration, loaded last so it can override anything above.
-- pcall rather than a bare dofile: this file is untracked and may be missing or
-- broken, and neither should stop the editor starting. Measured - a pcall of a
-- missing file returns cleanly and Neovim carries on.
pcall(dofile, vim.fn.stdpath('config') .. '/local.lua')
