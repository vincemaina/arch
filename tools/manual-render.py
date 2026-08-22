#!/usr/bin/env python3
"""Turn the manual's markdown chapters into one self-contained HTML file.

Why this exists rather than pandoc: pandoc, weasyprint and wkhtmltopdf are all
absent from this machine, and the cheapest of them costs more than the whole
manual weighs. Nothing here may be added to setup/packages/ either, since the
manual is repository tooling and never reaches the built system. So the input
dialect is ours to define, and this reads exactly that dialect and nothing else.

The important property is not that it renders markdown. It is that it REFUSES
anything it does not understand, with a file and a line number. A renderer that
quietly drops an image or flattens a nested list would put this document in the
same category as every other bug this repository has hit: looks correct, does
nothing.
"""

import html
import re
import sys
from pathlib import Path


class Bad(Exception):
    def __init__(self, path, lineno, message):
        super().__init__(f"{path}:{lineno}: {message}")


# ---------------------------------------------------------------- inline

CODE = re.compile(r"`([^`]+)`")
BOLD = re.compile(r"\*\*(.+?)\*\*")
ITALIC = re.compile(r"(?<!\*)\*([^*]+)\*(?!\*)")
LINK = re.compile(r"\[([^\]]+)\]\(([^)]+)\)")


def plain(text):
    """A heading's text with its markup taken off, for the table of contents.
    Escaping the raw line instead puts literal backticks in the index, which is
    what the first build of this document did."""
    text = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", text)
    return re.sub(r"`|\*", "", text)


def slug(text):
    text = re.sub(r"`|\*", "", text).strip().lower()
    return re.sub(r"[^a-z0-9]+", "-", text).strip("-")


def inline(text, path, lineno, chapters, here=None):
    """Code spans are extracted before anything else touches the string, so a
    `*` or a `[` inside one cannot be read as emphasis or a link."""
    spans = []

    def stash(m):
        spans.append(html.escape(m.group(1)))
        return f"\x00{len(spans) - 1}\x00"

    text = CODE.sub(stash, text)
    if "`" in text:
        raise Bad(path, lineno, "unmatched backtick")
    text = html.escape(text)

    def link(m):
        # Two chapters may both have a section called "The bar", so every
        # anchor is scoped to its chapter. A link written the natural way -
        # other-chapter.md#the-bar - therefore has to be rewritten to match,
        # and so does a bare #the-bar within one chapter.
        label, href = m.group(1), m.group(2)
        target = href.split("#", 1)
        name = Path(target[0]).stem
        if target[0].endswith(".md") and name in chapters:
            anchor = f"{name}--{target[1]}" if len(target) > 1 else f"ch-{name}"
            return f'<a href="#{anchor}">{label}</a>'
        if href.startswith("#") and here:
            return f'<a href="#{here}--{href[1:]}">{label}</a>'
        if href.startswith("#"):
            return f'<a href="{href}">{label}</a>'
        return f'<a class="ext" href="{html.escape(href)}">{label}</a>'

    text = LINK.sub(link, text)
    text = BOLD.sub(r"<strong>\1</strong>", text)
    text = ITALIC.sub(r"<em>\1</em>", text)
    for i, code in enumerate(spans):
        text = text.replace(f"\x00{i}\x00", f"<code>{code}</code>")
    return text


# ---------------------------------------------------------------- blocks

FORBIDDEN = [
    (re.compile(r"!\["), "images are not supported; describe it in words"),
    (re.compile(r"^\s*<"), "raw HTML is not supported"),
    (re.compile(r"^\s*[-*+] \[[ xX]\]"), "task lists are not supported"),
    (re.compile(r"^\[[^\]]+\]:"), "reference-style links are not supported"),
    (re.compile(r"\[\^"), "footnotes are not supported"),
    (re.compile(r"^#{4,} "), "headings deeper than ### are not supported"),
    (re.compile(r"^\s{4,}[-*+] "), "lists nest one level only (2 spaces)"),
    (re.compile(r"^\s*[*+] "), "use - for bullets, not * or +"),
]


def render_chapter(path, chapters, generated=None, fragment=False):
    """`generated` is the file tools/shortcuts.sh produced. A chapter splices it
    in with a line reading {{shortcuts}}, and it is parsed as its own unit so
    that a line number in an error still points at the chapter you wrote rather
    than at an offset into something no one edits."""
    raw = path.read_text().split("\n")
    here = path.stem
    out = []
    i = 0
    in_code = False
    heads = []

    while i < len(raw):
        line = raw[i]
        n = i + 1

        if line.startswith("```"):
            in_code = not in_code
            if in_code:
                lang = line[3:].strip()
                body = []
                i += 1
                while i < len(raw) and not raw[i].startswith("```"):
                    body.append(html.escape(raw[i]))
                    i += 1
                if i >= len(raw):
                    raise Bad(path, n, "unclosed code fence")
                in_code = False
                cls = f' class="lang-{lang}"' if lang else ""
                out.append("<pre><code%s>%s</code></pre>" % (cls, "\n".join(body)))
                i += 1
                continue

        for pattern, why in FORBIDDEN:
            if pattern.search(line):
                raise Bad(path, n, why)

        if i + 1 < len(raw) and re.fullmatch(r"=+|-{3,}", raw[i + 1].strip()) and line.strip():
            if raw[i + 1].strip().startswith("="):
                raise Bad(path, n + 1, "setext headings are not supported; use #")
            # `---` under text is a setext H2 in real markdown and a horizontal
            # rule here. Refuse rather than pick, since the writer meant one.
            raise Bad(path, n + 1, "put a blank line before --- so it cannot read as a heading")

        if line.startswith("### "):
            text = line[4:].strip()
            s = f"{here}--{slug(text)}"
            heads.append((3, text, s))
            out.append(f'<h3 id="{s}">{inline(text, path, n, chapters, here)}</h3>')
        elif line.startswith("## "):
            text = line[3:].strip()
            s = f"{here}--{slug(text)}"
            heads.append((2, text, s))
            out.append(f'<h2 id="{s}">{inline(text, path, n, chapters, here)}</h2>')
        elif line.strip() == "{{shortcuts}}":
            if generated is None:
                raise Bad(path, n, "{{shortcuts}} used but no generated file was supplied")
            body, sub_heads = render_chapter(generated, chapters, fragment=True)
            out.append(body)
            heads.extend(sub_heads)
        elif line.startswith("# "):
            if out:
                raise Bad(path, n, "a chapter has exactly one # title, on its first line")
            text = line[2:].strip()
            heads.append((1, text, f"ch-{path.stem}"))
            out.append(
                f'<h1 id="ch-{path.stem}">{inline(text, path, n, chapters, here)}</h1>'
            )
        elif re.fullmatch(r"-{3,}", line.strip()):
            out.append("<hr>")
        elif line.startswith("|"):
            rows, start = [], n
            while i < len(raw) and raw[i].startswith("|"):
                rows.append(raw[i])
                i += 1
            if len(rows) < 2 or not re.fullmatch(r"\|[\s:|-]+\|", rows[1].strip()):
                raise Bad(path, start + 1, "a table needs a | --- | separator row")
            out.append(table(rows, path, start, chapters, here))
            continue
        elif line.startswith("> "):
            body, start = [], n
            while i < len(raw) and (raw[i].startswith("> ") or raw[i].rstrip() == ">"):
                body.append(raw[i][2:] if len(raw[i]) > 2 else "")
                i += 1
            joined = "<br>".join(inline(b, path, start, chapters, here) for b in body)
            out.append(f"<blockquote>{joined}</blockquote>")
            continue
        elif re.match(r"^(- |\d+\. )", line):
            block, start = [], n
            # A wrapped line inside an item is indented to line up under the
            # text, which is three spaces after "1. " and two after "- ". Both
            # count as continuation; only "- " or "N. " after the indent starts
            # a nested item, and the first alternative has already claimed those.
            while i < len(raw) and (re.match(r"^(- |\d+\. |  - |  \d+\. )", raw[i]) or
                                    (re.match(r"^\s{2,}\S", raw[i]) and block)):
                block.append(raw[i])
                i += 1
            out.append(listing(block, path, start, chapters, here))
            continue
        elif not line.strip():
            pass
        else:
            body, start = [], n
            while i < len(raw) and raw[i].strip() and not re.match(
                r"^(#|```|\||> |- |\d+\. |-{3,}$)", raw[i]
            ):
                body.append(raw[i].strip())
                i += 1
            out.append(f'<p>{inline(" ".join(body), path, start, chapters, here)}</p>')
            continue

        i += 1

    if not fragment and (not heads or heads[0][0] != 1):
        raise Bad(path, 1, "a chapter must start with a # title")
    return "\n".join(out), heads


def table(rows, path, lineno, chapters, here=None):
    def cells(row):
        # A cell may contain \| for a literal pipe - tools/shortcuts.sh emits
        # those - so split on unescaped pipes only.
        parts = re.split(r"(?<!\\)\|", row.strip())
        return [p.strip().replace("\\|", "|") for p in parts[1:-1]]

    head = cells(rows[0])
    body = [cells(r) for r in rows[2:]]
    for r in body:
        if len(r) != len(head):
            raise Bad(path, lineno, f"row has {len(r)} cells, header has {len(head)}")
    th = "".join(f"<th>{inline(c, path, lineno, chapters, here)}</th>" for c in head)
    trs = "".join(
        "<tr>" + "".join(f"<td>{inline(c, path, lineno, chapters, here)}</td>" for c in r) + "</tr>"
        for r in body
    )
    return f"<table><thead><tr>{th}</tr></thead><tbody>{trs}</tbody></table>"


def listing(block, path, lineno, chapters, here=None):
    """A nested list belongs INSIDE the item above it, not beside it. Browsers
    forgive the sibling form, which is exactly why it survives unnoticed until
    something less forgiving reads the file.

    Each item's continuation lines are joined into one string BEFORE any inline
    markup is read, because a code span may be wrapped across a line break and
    reading the lines separately would see two unmatched backticks."""
    ordered = bool(re.match(r"^\d+\. ", block[0]))
    tag = "ol" if ordered else "ul"
    items = []          # [text, [nested text, ...]]

    for line in block:
        m = re.match(r"^(\s*)(- |\d+\. )(.*)$", line)
        if not m:
            text = line.strip()
            if not items:
                raise Bad(path, lineno, "a list continuation line needs an item above it")
            if items[-1][1]:
                items[-1][1][-1] += " " + text
            else:
                items[-1][0] += " " + text
            continue
        indent, _, text = m.groups()
        if len(indent) >= 2:
            if not items:
                raise Bad(path, lineno, "a nested list item needs a parent item above it")
            items[-1][1].append(text)
        else:
            items.append([text, []])

    out = [f"<{tag}>"]
    for text, nested in items:
        out.append("<li>" + inline(text, path, lineno, chapters, here))
        if nested:
            out.append("<ul>")
            out.extend(f"<li>{inline(n, path, lineno, chapters, here)}</li>" for n in nested)
            out.append("</ul>")
        out.append("</li>")
    out.append(f"</{tag}>")
    return "".join(out)



# ---------------------------------------------------------------- document

CSS = """
:root {
  --ink: #1a1a1a; --dim: #555; --rule: #d8d8d8; --bg: #ffffff;
  --panel: #f6f6f4; --accent: #7a4a1f; --code: #2c2c2c;
}
@media screen and (prefers-color-scheme: dark) {
  :root {
    --ink: #dcdcdc; --dim: #9a9a9a; --rule: #333; --bg: #16171a;
    --panel: #1e1f23; --accent: #d9a066; --code: #d0d0d0;
  }
}
* { box-sizing: border-box; }
body {
  margin: 0; background: var(--bg); color: var(--ink);
  font: 16px/1.65 "Iosevka Aile", "Source Sans 3", "DejaVu Sans", system-ui, sans-serif;
}
main { max-width: 46rem; margin: 0 auto; padding: 3.5rem 1.5rem 8rem; flex: 1 1 auto; min-width: 0; }

#toc { padding: 2rem 1.5rem; border-bottom: 1px solid var(--rule); }
#toc .brand { display: none; }

/* The contents stay on screen. This is one page of about twelve thousand
   words, and a table of contents you have to scroll back to is a table of
   contents you stop using. Below 64rem there is no room for a column beside
   the text, so it becomes a block at the top instead. */
@media screen and (min-width: 64rem) {
  body { display: flex; align-items: flex-start; }
  #toc {
    position: sticky; top: 0; align-self: stretch;
    flex: 0 0 20rem; width: 20rem; height: 100vh; overflow-y: auto;
    padding: 2.5rem 1rem 4rem 2rem; border-right: 1px solid var(--rule);
    background: var(--bg);
  }
  #toc .brand { display: block; font-weight: 650; font-size: 1.05rem; margin-bottom: 1.5rem; }
  #toc { border-bottom: 0; }
}
h1, h2, h3 { line-height: 1.25; font-weight: 650; }
h1 { font-size: 2.1rem; margin: 0 0 2rem; padding-bottom: .6rem; border-bottom: 2px solid var(--rule); }
h2 { font-size: 1.35rem; margin: 2.6rem 0 .8rem; }
h3 { font-size: 1.08rem; margin: 1.9rem 0 .5rem; color: var(--dim); }
p, ul, ol, table, blockquote, pre { margin: 0 0 1rem; }
li { margin: .25rem 0; }
li > ul { margin: .3rem 0 .3rem; }
a { color: var(--accent); text-decoration-thickness: 1px; text-underline-offset: 2px; }
code {
  font-family: "Iosevka Nerd Font", "JetBrains Mono", "DejaVu Sans Mono", monospace;
  font-size: .88em; background: var(--panel); color: var(--code);
  padding: .1em .35em; border-radius: 3px;
}
pre {
  background: var(--panel); border: 1px solid var(--rule); border-radius: 5px;
  padding: .85rem 1rem; overflow-x: auto;
}
pre code { background: none; padding: 0; font-size: .84rem; line-height: 1.5; }
blockquote {
  margin-left: 0; padding: .1rem 0 .1rem 1rem;
  border-left: 3px solid var(--rule); color: var(--dim);
}
table { border-collapse: collapse; width: 100%; font-size: .92rem; }
th, td { text-align: left; padding: .4rem .6rem; border-bottom: 1px solid var(--rule); vertical-align: top; }
th { font-weight: 650; border-bottom-width: 2px; }
td code { white-space: nowrap; }
hr { border: 0; border-top: 1px solid var(--rule); margin: 2rem 0; }

.title { padding: 6rem 0 4rem; text-align: left; }
.title h1 { font-size: 2.8rem; border: 0; margin-bottom: .5rem; }
.title .sub { color: var(--dim); font-size: 1.05rem; }
.title .built { color: var(--dim); font-size: .85rem; margin-top: 3rem; }
nav a { text-decoration: none; color: var(--ink); }
nav a:hover { text-decoration: underline; }
nav ol { list-style: none; padding: 0; margin: 0; counter-reset: ch; }
nav > ol > li { counter-increment: ch; margin: .9rem 0 .3rem; font-weight: 650; }
nav > ol > li::before { content: counter(ch) ".  "; color: var(--dim); }
nav ol ol { padding-left: 1.65rem; font-weight: 400; font-size: .9rem; }
nav ol ol li { margin: .12rem 0; }
nav ol ol a { color: var(--dim); }
nav .here > a { color: var(--accent); }
nav ol ol .here > a { color: var(--accent); font-weight: 600; }

/* Every section is listed until the script says otherwise, so a browser with
   no JavaScript gets the whole contents rather than eleven headings and no
   way to reach anything under them. */
html[data-js] nav > ol > li > ol { display: none; }
html[data-js] nav > ol > li.here > ol { display: block; }
nav ol ol li::before { content: ""; }
.chapter { page-break-before: always; }

@media print {
  :root {
    --ink: #000; --dim: #444; --rule: #bbb; --bg: #fff;
    --panel: #f2f2f2; --accent: #000; --code: #000;
  }
  @page { margin: 18mm 16mm; }
  body { font-size: 10.5pt; display: block; }
  main { max-width: none; padding: 0; }
  #toc {
    position: static; width: auto; height: auto; overflow: visible;
    padding: 0 0 1rem; border: 0; page-break-after: always;
  }
  #toc .brand { display: none; }
  html[data-js] nav > ol > li > ol { display: block; }
  a.ext::after { content: " (" attr(href) ")"; font-size: .82em; color: var(--dim); }
  h1, h2, h3 { page-break-after: avoid; }
  pre, table, blockquote { page-break-inside: avoid; }
  .title { padding: 0 0 3rem; }
}
"""


# Marks where you are in the contents, and folds away the sections of chapters
# you are not reading. It sets data-js on the root itself, so if this never runs
# the stylesheet leaves every section listed rather than hiding them behind a
# script that is not there.
SPY = """
document.documentElement.setAttribute('data-js','');
var toc = document.getElementById('toc');
var links = {};
toc.querySelectorAll('a[href^="#"]').forEach(function (a) {
  links[a.getAttribute('href').slice(1)] = a;
});
var heads = [].slice.call(document.querySelectorAll('main h1[id], main h2[id]'));
var current = null;
function mark() {
  var found = null;
  for (var i = 0; i < heads.length; i++) {
    if (heads[i].getBoundingClientRect().top <= 130) found = heads[i].id; else break;
  }
  if (!found && heads.length) found = heads[0].id;
  if (found === current) return;
  current = found;
  toc.querySelectorAll('.here').forEach(function (li) { li.classList.remove('here'); });
  var a = links[found];
  if (!a) return;
  for (var li = a.parentElement; li && li !== toc; li = li.parentElement) {
    if (li.tagName === 'LI') li.classList.add('here');
  }
  // scrollIntoView() scrolls EVERY scrollable ancestor, the window included.
  // Clicking a chapter in the contents therefore scrolled the page straight
  // back to the top, because this handler ran and dragged the window to where
  // the link was. Move only the contents column, and only when it can move.
  if (toc.scrollHeight > toc.clientHeight) {
    var want = a.offsetTop - toc.clientHeight / 2;
    toc.scrollTop = want > 0 ? want : 0;
  }
}
window.addEventListener('scroll', mark, {passive: true});
window.addEventListener('resize', mark);
window.addEventListener('load', mark);
window.addEventListener('hashchange', mark);
mark();
"""


def build(manual_dir, out_path, built_line, generated=None):
    files = sorted(p for p in manual_dir.glob("*.md") if re.match(r"^\d\d-", p.name))
    if not files:
        raise SystemExit(f"no NN-*.md chapters found in {manual_dir}")
    names = {p.stem for p in files}

    bodies, toc = [], []
    for path in files:
        body, heads = render_chapter(path, names, generated=generated)
        bodies.append(f'<section class="chapter">{body}</section>')
        title = heads[0]
        subs = [h for h in heads if h[0] == 2]
        entry = f'<li><a href="#{title[2]}">{html.escape(plain(title[1]))}</a>'
        if subs:
            entry += "<ol>" + "".join(
                f'<li><a href="#{s[2]}">{html.escape(plain(s[1]))}</a></li>' for s in subs
            ) + "</ol>"
        toc.append(entry + "</li>")

    doc = f"""<!doctype html>
<html lang="en"><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>The manual</title>
<style>{CSS}</style>
</head><body>
<nav id="toc"><a class="brand" href="#top">The manual</a><ol>{''.join(toc)}</ol></nav>
<main>
<header class="title" id="top">
<h1>The manual</h1>
<p class="sub">Using and editing this Arch Linux desktop.</p>
<p class="built">{html.escape(built_line)}</p>
</header>
{''.join(bodies)}
</main>
<script>{SPY}</script>
</body></html>
"""
    out_path.write_text(doc)
    return len(files), len(doc)


def main():
    manual_dir = Path(sys.argv[1])
    out_path = Path(sys.argv[2])
    built_line = sys.argv[3] if len(sys.argv) > 3 else ""
    generated = Path(sys.argv[4]) if len(sys.argv) > 4 else None
    try:
        count, size = build(manual_dir, out_path, built_line, generated=generated)
    except Bad as e:
        print(f"manual: {e}", file=sys.stderr)
        raise SystemExit(1)
    print(f"{count} chapters, {size // 1024} KiB")


if __name__ == "__main__":
    main()
