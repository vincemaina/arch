# The manual

How to use this desktop, and how to change it.

The rest of the repository documents itself for whoever is *building* it:
[DECISIONS.md](../../DECISIONS.md) carries the reasoning behind every choice,
[FLOW.md](../../FLOW.md) the installation path, [CLAUDE.md](../../CLAUDE.md) the
architecture, and [docs/software/](../software/README.md) a roll call of every
package with what it costs. None of them is a manual. This is.

Read it in order the first time. After that, chapter 3 and chapter 8 are the two
you will come back to.

## Part one — using it

| | |
| --- | --- |
| 1 | [Getting started](01-getting-started.md) — what this machine is, what happens when you turn it on, and the first five minutes |
| 2 | [The desktop](02-the-desktop.md) — windows, workspaces, the bar, notifications |
| 3 | [The keyboard](03-the-keyboard.md) — every shortcut, the modes, and the scroll layer that lives below the compositor |
| 4 | [Applications](04-applications.md) — the terminal, the shell, the editor, the browsers, files, git, the calendar, virtual machines |
| 5 | [Making it yours](05-making-it-yours.md) — themes, wallpapers, the bar, and what is machine-local rather than tracked |
| 6 | [Getting work done](06-working.md) — focus music, the timer, clipboard history, screenshots, the notification centre |

## Part two — editing it

| | |
| --- | --- |
| 7 | [How it is put together](07-how-it-is-put-together.md) — the two entrypoints, the two execution contexts, and the boundary between them |
| 8 | [Recipes](08-recipes.md) — adding a package, a dotfile, a keybinding, a theme, a session unit, a colour |
| 9 | [Installing on a new machine](09-installing.md) — from a live ISO to a working desktop |
| 10 | [Keeping it healthy](10-keeping-it-healthy.md) — the checks, updates, drift, and reading a failure |

## Reading it as one page

```bash
./tools/manual.sh --open
```

That renders every chapter into one self-contained HTML page at
`docs/manual/build/manual.html`: a contents column that stays on screen and
follows where you are, and links between every chapter. Ten files on disk is
how it is written; one page is how it is read.

Self-contained means no stylesheet to fetch, no font to download and nothing to
install. Copy the file to a phone, or to the laptop you are about to install
this onto — precisely the moment the machine it describes does not exist yet —
and it still works. A browser will print it if you want it on paper; the print
stylesheet breaks pages between chapters and spells out where each external
link points, since a printed link is otherwise useless.

`./sync.sh` builds it too, and installs the result where the `manual` command
and the launcher entry can find it. So the manual on a machine is as current as
its last sync — stale in the same visible way as every other dotfile, rather
than in a new invisible one.

There is no pandoc here and there is not going to be: the manual is repository
tooling, so nothing it needs may be added to `setup/packages/`, and it was only
ever needed for PDF — producing HTML never required it.
`tools/manual-render.py` reads a markdown dialect this repository defines and
**refuses anything outside it** rather than rendering it wrongly.

## Writing it

The dialect is: one `#` title on the first line, `##` and `###` headings,
paragraphs, `-` bullets nested at most one level, numbered lists, fenced code
blocks, pipe tables, `>` blockquotes, `---` rules, and inline code, bold,
italic and links. Images, raw HTML, footnotes, task lists and reference-style
links all fail the build with a file and a line number.

Chapter 3 contains no shortcut table. It contains the line `{{shortcuts}}`, and
the build substitutes the output of `tools/shortcuts.sh --markdown` — which
parses the actual sway and zsh configuration. A hand-kept shortcut table is
wrong the first time somebody changes a binding and forgets the document.

Everything else is checked:

```bash
./checks/manual.sh
```

It fails if the manual names a file, a helper or a `$mod` keybinding that does
not exist, and if a cross-chapter link is labelled with a filename instead of a
title.

That is a floor rather than a ceiling, and the limit is worth knowing precisely:
it cannot tell you a sentence is untrue, only that the things it names are real.
When `$mod+minus` moved from the scratchpad to shrinking a window, the check
caught the chapter still naming `$mod+Shift+minus`, which had become unbound —
but said nothing about `$mod+minus` itself, which was still bound and now meant
something completely different. Existence is checkable. Meaning is not.
