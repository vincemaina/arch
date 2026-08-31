---
id: TASK-199
title: 'Rendered markdown in neovim, with the cursor line staying editable'
status: Done
assignee:
  - '@claude'
created_date: '2026-08-31 10:05'
updated_date: '2026-08-31 10:33'
labels: []
dependencies: []
type: feature
ordinal: 204000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Markdown buffers should look rendered rather than raw - headings styled, bullets as bullets, `[text](url)` showing just the text, tables aligned, checkboxes as boxes - while the line the cursor is on reverts to its source so it can still be edited. The Typora behaviour, in a modal editor.

render-markdown.nvim (MeanderingProgrammer) does exactly this; its anti-conceal feature is the cursor-line reveal. markview.nvim is the heavier alternative.

Three things make this more than a one-line install:

- It would be the first third-party plugin in this config. init.lua documents vim.pack and the tracked nvim-pack-lock.json at length, but nothing has ever exercised either. This is where that story stops being hypothetical.
- The plugin defines its own highlight groups. Left at defaults it is the one thing on screen not wearing the selected palette, so it needs linking into colors/arch.lua.tmpl the way TASK-82 did the rest of the editor.
- Its icons are Nerd Font glyphs, which this repository has lost silently before when pasted. They must be written by codepoint.

The treesitter prerequisites are already met: nvim bundles both the markdown and markdown_inline parsers with highlight queries, so the parser-and-query guard in init.lua already starts treesitter on markdown buffers.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Opening a markdown file renders headings, list bullets, links, tables and checkboxes rather than showing raw syntax
- [x] #2 The line the cursor is on shows its raw markdown source, and reverts to rendered when the cursor leaves
- [x] #3 The plugin is installed through vim.pack, and nvim-pack-lock.json is tracked in the repository
- [x] #4 Rendered markdown follows the selected theme, in both light and dark modes, rather than the plugin defaults
- [x] #5 Every Nerd Font glyph the configuration sets is written by codepoint, not pasted
- [x] #6 A fresh install ends up with the plugin present, without a manual step
- [x] #7 checks/session.sh and checks/manual.sh pass, and the manual describes the behaviour
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add setup/dotfiles/dot_config/nvim/lua/plugins.lua: the vim.pack.add call for render-markdown.nvim pinned to the v8 major with vim.version.range, wrapped so a machine with no network cannot fail to start the editor, plus the plugin setup. Required from init.lua BEFORE vim.cmd.colorscheme, so the colourscheme has the last word on highlights.
2. Configure it against what it actually defaults to, read from the v8.13.0 source rather than the README: anti_conceal is already enabled with above/below 0, which is the cursor-line reveal asked for. Turn OFF heading.sign - signcolumn is "number" on this machine (TASK-170), so a heading sign would replace the line number rather than sit beside it. Icons stay as shipped, written by codepoint.
3. Track the lockfile. Add setup/dotfiles/dot_config/nvim/nvim-pack-lock.json to the source state so chezmoi writes it, which is what makes every machine take the same revision.
4. Add run_onchange_after_install-nvim-plugins.sh.tmpl, hashing the lockfile the way the language-server script hashes package-lock.json, and running nvim headless once so a fresh install has the plugin on disk without anyone opening the editor.
5. Add a RenderMarkdown section to colors/arch.lua.tmpl defining every group the plugin uses, not only the wrong ones: colorscheme runs highlight clear, which is exactly the kind of invisible half-applied state this repository keeps finding. Headings get the role colours, code and quotes the surface shades, callouts stay linked to the Diagnostic groups so severity is decided in one place.
6. Verify on the running machine rather than from the file: nvim --headless asking for the applied highlights, a rendered markdown buffer captured with the cursor on and off a link, and the startup cost measured against the 15ms budget the config is written to.
7. Update docs/manual/ - chapter 4 for what it does, chapter 5 for how to turn it off - and run checks/session.sh, checks/manual.sh and checks/packages.sh.

8. AMENDED during implementation, twice. Step 1 said plugins.lua must be required BEFORE the colourscheme; it is required AFTER it. The reason the original order looked necessary turned out not to be real - vim.pack does not source a plugins plugin/ directory while init.lua is being sourced, so a plugins highlight defaults arrive after everything in init.lua either way and lose to the colourscheme regardless of where the require sits. Running after it is what gives plugins.lua vim.o.background, which it needs to decide whether headings get a band.

9. ALSO AMENDED: step 5 said "defining every group the plugin uses". The heading backgrounds are the exception on the light themes, and unavoidably so - nvim treats a cleared highlight spec as an undefined group, so the plugins own default link survives it. They are turned off through the plugins configuration instead.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Installed render-markdown.nvim v8.13.0 (rev f422cb5) through vim.pack. New: lua/plugins.lua (the plugin list and its options), nvim-pack-lock.json (tracked), run_onchange_after_install-nvim-plugins.sh.tmpl. Changed: init.lua (requires plugins AFTER the colourscheme), colors/arch.lua.tmpl (a RenderMarkdown section naming every group, plus @markup.quote which was unnamed and rendering salmon), CLAUDE.md, DECISIONS.md, the manual, and checks/manual.sh.

Verified on a headless sway output with foot running the rendered config under NVIM_APPNAME, not by reading the files back:

- Cursor on line 3 shows the raw [text](url); every other line renders. Cursor on line 1 shows a raw "#" heading while line 6 keeps its band. That is anti-conceal, which is on by default at above/below 0 - so it is deliberately NOT set in the config.
- vim.pack installed headlessly with confirm=false and no prompt; vim.pack.get() reports rev f422cb5, matching the tracked lockfile. Deleting the plugin directory and re-running the install script reinstalled it and reported "1 plugin(s) installed".
- Startup, mean of nine headless runs, twice: 11.5 -> 14.4 ms with no file, 33.1 -> 48.2 ms opening a markdown file. Still inside the 15 ms budget init.ua names.

Three things were wrong first and are recorded where they were wrong:

1. The band on a light theme costs contrast rather than buying it. Computed for all eleven palettes: sepia H1 fell to 3.41:1 and H2 to 4.05:1 banded, against 4.69:1 plain. Bands are now dark-theme only, the same shape as the bars glow. Code panels stay everywhere because they use surface, which CursorLine already puts behind a whole line of text.
2. Clearing a highlight group does not define it. Both {} and { bg = "NONE" } leave RenderMarkdownH1Bg undefined, so the plugins default=true link to DiffText survived and light themes rendered a full-width warning-coloured band. Asked of a running editor. The band is turned off through the plugins own config instead, which is why plugins.lua now runs after the colourscheme - it needs vim.o.background.
3. The install scripts count was blank on exactly the fresh install it exists for: vim.packs progress lines end in a carriage return, so an anchored sed match found nothing once there was something to install.

checks/manual.sh needed a fix rather than the prose bending around it: its link regex read the `[text](url)` example inside a code span as a link to a file called "url". It now strips fenced blocks and inline code before scanning, with a negative control confirming real broken links are still found.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Neovim now draws markdown rendered rather than raw - headings with an icon and their own colour, bullets, links showing only their text, tables aligned, checkboxes, code panels, callouts - and un-draws the one line the cursor is on so it stays editable. render-markdown.nvim v8.13.0 (rev f422cb5), installed by vim.pack, pinned by a tracked nvim-pack-lock.json and put on disk at apply time by run_onchange_after_install-nvim-plugins.sh.tmpl, so a fresh install needs no manual step. It is the first plugin this configuration has had, which turned the lockfile paragraph init.lua had carried since it was written into a description rather than a plan.

Every RenderMarkdown highlight group is named by colors/arch.lua.tmpl rather than left to the plugins defaults, because :colorscheme runs highlight clear and a group the theme does not name works until the theme is switched. Heading bands are dark-theme only: computed across all eleven palettes, banding cost sepia its level-one heading contrast, 4.69:1 down to 3.41:1.

Verified against a running editor rather than the files: captured on a headless sway output with the cursor on and off a link on both a dark and a light theme; vim.pack.get() reporting the revision the lockfile names; the install script reinstalling from scratch after the plugin directory was deleted; and startup measured at 11.5 -> 14.4 ms bare and 33.1 -> 48.2 ms on a markdown file, means of nine runs. checks/session.sh 140 passed, checks/manual.sh 8 passed, checks/sway-commands.sh and checks/sway-bindings.sh clean. checks/packages.sh fails on fifteen packages installed by hand on this machine, all pre-existing and unrelated.
<!-- SECTION:FINAL_SUMMARY:END -->
