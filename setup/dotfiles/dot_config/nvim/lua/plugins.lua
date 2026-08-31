-- Plugins.
--
-- In its own module for the same reason lsp.lua is: init.lua is meant to stay a
-- file you can read, and a plugin list is the thing that turns a config into a
-- distribution. One plugin today. If it becomes ten, this is where the argument
-- for each of them lives.
--
-- WHAT vim.pack ACTUALLY DOES, which is not what the header of init.lua guessed
--
-- `vim.pack.add()` clones missing plugins with a partial blobless `git clone`
-- and checks out a revision, in parallel, blocking until they are all done.
-- Two of its defaults are wrong for a config that is applied by a script:
--
--   * `confirm` defaults to TRUE. The first start on a new machine would stop
--     and ask before installing - which is fine in front of a person and hangs
--     forever inside `nvim --headless` from a chezmoi script. It is off here.
--   * `load` defaults to FALSE while init.lua is being sourced. So this behaves
--     like `:packadd!`: the plugin's `lua/` is reachable immediately - which is
--     why `require` below works - but its `plugin/` directory is not sourced
--     until after init.lua finishes.
--
-- That second one is load-bearing for the colours. render-markdown registers
-- its highlight groups from `plugin/`, with `default = true`, which does not
-- overwrite a group that already exists. Because that happens after init.lua,
-- and `vim.cmd.colorscheme('arch')` happens inside it, every group the theme
-- names wins and only the ones it does not name fall back to the plugin's.
--
-- THE VERSION IS A RANGE, AND THE LOCKFILE IS THE ACTUAL ANSWER
--
-- `version` bounds what an update is allowed to take: the 8.x line, so a major
-- release with breaking configuration changes cannot arrive during a routine
-- `vim.pack.update()`. It is not what decides the revision installed. That is
-- nvim-pack-lock.json, which is tracked in this repository and applied by
-- chezmoi, and which vim.pack reads on its first call - so every machine
-- running this setup gets the same commit rather than whatever the range
-- resolved to on the day it was installed.
--
-- Updating is deliberate and looks like a diff: run `:lua vim.pack.update()`,
-- read the confirmation buffer, `:write` to accept, then `chezmoi re-add` the
-- lockfile and commit it. sync.sh already prints that re-add line for any
-- managed file that differs.

local M = {}

---@type table[]
local specs = {
  -- Markdown that looks rendered rather than raw - headings, bullets, links,
  -- tables, checkboxes - with the line the cursor is on falling back to its
  -- source so it can still be edited. See markdown_opts() below.
  {
    src = 'https://github.com/MeanderingProgrammer/render-markdown.nvim',
    version = vim.version.range('8'),
  },
}

-- Everything the plugin does differently from its own defaults, and why.
--
-- The defaults were read out of the v8 source rather than off the README: the
-- README documents the options, and what is actually shipped is what decides
-- whether a line here is doing anything. Anything not named below is the
-- plugin's default on purpose.
local function markdown_opts()
  local opts = {
    -- NOT SET, AND THAT IS THE POINT: `anti_conceal` is already
    -- { enabled = true, above = 0, below = 0 }, which is exactly the behaviour
    -- this was installed for - the cursor's own line un-renders and everything
    -- else stays rendered. Setting it again would only create a second place
    -- for it to be wrong.

    -- THE SIGN COLUMN IS THE NUMBER COLUMN HERE.
    --
    -- Both the heading and code-block renderers put a glyph in the sign column
    -- by default. TASK-170 set `signcolumn = 'number'`, which means a sign does
    -- not sit beside the line number, it REPLACES it - so every heading and
    -- every fenced block would lose its line number to an icon. A heading
    -- already carries an icon, and on the dark themes a band across the window
    -- as well; neither needs a second marker bought with the gutter that task
    -- narrowed.
    heading = { sign = false },
    code = { sign = false },

    -- No `latex` parser is packaged for Arch and neither converter (`utftex`,
    -- `latex2text`) is installed, so this can only ever decide it has nothing
    -- to do - once per formula, on every render. Off is honest.
    latex = { enabled = false },
  }

  -- THE HEADING BAND IS A DARK-THEME FEATURE, and it has to be turned off HERE
  -- rather than coloured away in the colourscheme.
  --
  -- Why it is off at all is measured, and the measurement is written out in
  -- colors/arch.lua.tmpl: a full-width band moves the background under the
  -- heading toward the text on a light palette, and `sepia` fell to 3.41:1 for
  -- its level-one heading - below the floor everything else here is held to.
  --
  -- Why it cannot be done in the colourscheme is the more useful half. The
  -- obvious move is to clear RenderMarkdownH1Bg..H6Bg, and it does not work:
  -- nvim treats both `{}` and `{ bg = 'NONE' }` as leaving the group UNDEFINED,
  -- so the plugin's own `default = true` link survives and level-one headings
  -- render with DiffText's background - the warning colour, full width. Asked
  -- of a running editor rather than assumed. Telling the plugin there are no
  -- background groups skips the render entirely, which is the honest version of
  -- the same intent.
  --
  -- `vim.o.background` is set by the colourscheme from the theme's declared
  -- `mode`, which is why M.setup() is called after it in init.lua.
  --
  -- Written as a statement rather than `x and nil or {}`: in Lua that
  -- expression evaluates to `{}` in BOTH directions, because `true and nil` is
  -- nil and `nil or {}` is `{}`.
  if vim.o.background ~= 'dark' then
    opts.heading.backgrounds = {}
  end

  return opts
end

function M.setup()
  -- pcall, because add() reaches the network on a machine that does not have
  -- the plugin yet. A laptop opening a file on a train should get an editor
  -- without markdown rendering, not an editor that refuses to start - and this
  -- is exactly the shape of failure the rest of this config guards: a thing
  -- that cannot work should do nothing, loudly, rather than take the session
  -- with it.
  local added, err = pcall(vim.pack.add, specs, { confirm = false })
  if not added then
    vim.notify('plugins: ' .. tostring(err), vim.log.levels.WARN)
    return
  end

  local ok, markdown = pcall(require, 'render-markdown')
  if ok then
    markdown.setup(markdown_opts())
  end
end

return M
