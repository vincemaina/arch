---
id: TASK-102
title: local agent
status: Done
assignee:
  - '@claude'
created_date: '2026-08-22 02:23'
updated_date: '2026-08-22 03:16'
labels: []
dependencies: []
priority: low
type: feature
ordinal: 104000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Explore possibility of having a local agent that runs within the operating system. It should be able to answer questions, help debug things. And power day to day operations on the pc, without network calls, private data leakage etc.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
SPIKE. No implementation - findings and a recommendation.

THE HARDWARE DECIDES MOST OF IT. This VM is 3.8 GiB of RAM with 1.5 GiB free, 4 cores, and a virtio GPU: +virgl, so no CUDA and no ROCm. Nothing useful for chat runs here. 33 GiB of disk is free, so storage is not the constraint - memory and the absence of a GPU are. Everything below is therefore about the real machine, and this VM can only be used to build and test the plumbing.

WHAT IS PACKAGED, which settles more than it looks:
  ollama              extra, 65.76 MiB, depends only on glibc/libstdc++/libgcc.
                      No GPU required - CPU inference works out of the box.
  ollama-cuda         extra, 987.70 MiB, and only useful with an NVIDIA card.
  python-openai       extra. ollama serves an OpenAI-compatible API, so the
                      client side needs nothing from outside the repositories.
  python-numpy, python-pydantic, python-httpx, uv, sqlite - all official.

NOT packaged, and therefore blocked on TASK-43: llama.cpp, python-torch,
python-sentence-transformers, qdrant, chromadb. Every one of them has an
official-repo alternative below, so the AUR does not need reopening for this.

THE MOST IMPORTANT FINDING IS THAT THE FOUR USE CASES ARE NOT ONE PROBLEM.

Semantic search over notes needs an EMBEDDING model, not a chat model. ollama
runs embedding models itself - nomic-embed-text, bge-m3, qwen3-embedding 0.6B -
so this needs no torch and no sentence-transformers. Embedding models are
small, run acceptably on CPU, and the whole job is a few hundred KB of vectors
for a personal notes corpus. At that scale a vector database is the wrong tool:
brute-force cosine similarity in numpy over a few thousand vectors is instant,
which is why qdrant and chromadb being unpackaged does not matter. THIS PIECE
WOULD WORK ON THIS MACHINE TODAY. It is also the highest value for the least
cost, and it depends on TASK-62 - there are no notes to embed yet.

Asking about the calendar is a TOOL problem, not a model problem. It needs
something that can call a calendar and read back; a 4B model can do that
adequately. The work is the tool layer, not the intelligence.

Asking about the system - what is running, why did this fail, what does this
config do - is where a small local model is genuinely useful, because the
context is on the machine and the questions are bounded.

Asking about what you are working on is where local models are weakest, and it
is the one already solved: Claude Code does it now, with far more capability
than anything that fits in 16 GiB.

MODELS WORTH TRYING, from current guidance rather than memory. 8 GiB: Qwen3 4B,
Gemma 3 4B or Phi-4-mini. 16 GiB: Qwen3 14B or Gemma 3 12B, described as the
sweet spot for daily work. All at Q4_K_M quantisation. Qwen3 is the safest
general default; Phi is the small-hardware option.

RECOMMENDATION: split this ticket rather than build 'a local agent'.

1. Semantic search over notes - ollama plus an embedding model plus numpy and
   sqlite, all official packages. Buildable and testable here. Depends on
   TASK-62 existing first.
2. A local model for system questions - real hardware only, and worth deciding
   after the move rather than before.
3. Calendar and work questions - already served by Claude Code, and worth being
   honest that a local model would be a downgrade in capability bought with
   privacy. That is a real trade, but it should be made deliberately.

The thing NOT to do is install ollama on this VM and conclude local models are
useless. They would be, here, for reasons that say nothing about the machine
this repository is actually for.

HARDWARE NUMBERS, added after the spike because the obvious next question was 'what do I actually need to buy'.

VRAM IS THE BINDING CONSTRAINT, NOT SYSTEM RAM. A model runs at usable speed only if it fits in VRAM; once it spills to system RAM it falls off a cliff. Current figures: CPU-only inference runs 5-30x slower than GPU - an i7-12700 manages about 12 tok/s where an RTX 3060 does 80+.

Calibration that makes those numbers mean something: reading speed is roughly 7-10 tokens per second. So 20 tok/s feels immediate, 12 tok/s is usable, and below about 5 is unpleasant enough that the tool stops being reached for.

BY USE CASE, since they differ by an order of magnitude:

  Embeddings / semantic search (TASK-104) - embedding models are 100-600M
  parameters. CPU is fine, needs 1-2 GiB, no GPU at all. This works on almost
  anything and is why it was split out.

  Calendar and system questions - a 4B model at Q4_K_M. Needs ~3 GiB VRAM, or
  CPU-only at around 12 tok/s with Phi-4-mini. Usable without a GPU.

  Anything resembling code reasoning - 14B and up. Qwen3 14B at Q4_K_M is about
  9 GiB of VRAM, which is 30-40 tok/s on a 12 GiB card and unusable on CPU.

THREE TIERS:

  No GPU, 16 GiB system RAM - embeddings plus a 4B model for bounded questions.
  Genuinely useful for TASK-104 and for 'what is this unit doing'. Not useful
  for anything about code.

  12 GiB VRAM (RTX 3060 12 GiB used, or 4070) with 32 GiB system RAM - Qwen3 14B
  at 30-40 tok/s. This is the tier where a local model becomes a thing you
  actually reach for rather than a demo.

  16-24 GiB VRAM (4060 Ti 16 GiB, or a 3090) - bigger models and, more usefully,
  long context, which is what a question about a large file actually needs.

WORTH SAYING PLAINLY: none of these tiers beats Claude Code for questions about
work in progress, and buying a GPU to approximate it would be spending money to
get something worse. The case for local is privacy, offline operation, and
questions about THIS machine that no hosted model has the context for. Those are
real, and they are what the hardware should be justified against.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Spike, not an implementation. The hardware settles most of it: this VM is 3.8 GiB with no CUDA or ROCm, so nothing useful for chat runs here, and the real machine is the only place the question can be answered. What is packaged settles the rest - ollama is in extra at 66 MiB and needs no GPU, python-openai speaks its OpenAI-compatible API, and numpy plus sqlite cover storage, so nothing here requires reopening TASK-43 despite llama.cpp, torch, sentence-transformers, qdrant and chromadb all being unpackaged.

The finding that matters is that the four use cases are not one problem. Semantic search over notes needs an embedding model rather than a chat model, is small enough to run on CPU today, and is split out as TASK-104. Calendar questions are a tool problem, not a model problem. System questions are where a small local model genuinely earns its place, on real hardware. Questions about work in progress are the one case already solved by Claude Code, and a local model would be a capability downgrade bought with privacy - a real trade, but one to make deliberately rather than by accident.
<!-- SECTION:FINAL_SUMMARY:END -->
