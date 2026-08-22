---
id: TASK-104
title: 'Semantic search over notes, with a local embedding model'
status: To Do
assignee: []
created_date: '2026-08-22 03:11'
labels: []
dependencies: []
priority: low
type: feature
ordinal: 106000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The piece of TASK-102 that is achievable now, on this hardware, without reopening TASK-43.

Semantic search needs an EMBEDDING model, not a chat model, and that changes what it costs. ollama (extra, 65.76 MiB, no GPU required) runs embedding models directly - nomic-embed-text, bge-m3, qwen3-embedding 0.6B - so this needs neither python-torch nor python-sentence-transformers, both of which are unpackaged.

At personal-notes scale a vector database is the wrong tool. A few thousand vectors is a few hundred KB; brute-force cosine similarity in numpy is instant and needs no index, no daemon and no schema migration. python-numpy and sqlite are both official, so qdrant and chromadb being unpackaged does not matter.

So the whole thing is: ollama serving an embedding model, a table of (path, chunk, vector), and a rofi front end - built from packages that are all in the official repositories.

DEPENDS ON TASK-62. There are no notes yet. Worth doing in that order rather than building a search tool with nothing to search.

Worth deciding when picked up: what gets embedded besides notes - this repository's own markdown is an obvious candidate, and DECISIONS.md plus the backlog would make 'why did we do it that way' answerable - and whether re-embedding is incremental or a full pass, since a full pass over a growing corpus is the thing that quietly becomes slow.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Notes are searchable by meaning rather than by substring, demonstrated on a query where grep returns nothing useful and the search returns the right note
- [ ] #2 It runs on CPU without a GPU, and the time to embed the corpus and to answer a query are both measured rather than assumed
- [ ] #3 Everything it needs is in the official repositories, or TASK-43 is explicitly reopened
- [ ] #4 Re-embedding after an edit does not re-process the whole corpus
- [ ] #5 The model and where its vectors live are recorded, so a rebuilt machine reproduces the index rather than silently starting empty
<!-- AC:END -->
