# CLAUDE HACKS


## Git Repository Management

Treat Git history as part of the project's documentation. The repository should tell a clear story of how the project evolved, not simply contain periodic snapshots of the working directory.

* **Commit at meaningful milestones.** Decide when a logical unit of work is complete enough to deserve a commit. Avoid committing every tiny edit, but also avoid combining an entire feature or long session into one enormous commit.
* **Make commits tell the story.** Each commit should represent one coherent change and have a concise message explaining what changed and, where useful, why. Someone scanning `git log` should be able to understand the project's progression.
* **Keep commits focused.** Avoid mixing unrelated refactoring, formatting, bug fixes, and feature work into the same commit when they can reasonably be separated.
* **Prefer working branches for meaningful changes.** Create a short-lived branch for features, fixes, refactors, experiments, or other substantial work rather than developing directly on `main`.
* **Keep branches short-lived and focused on one objective.** Do not create unnecessary branch hierarchies or maintain several partially completed branches unless there is a clear reason.
* **Prefer PRs as the review boundary.** When a coherent piece of work is ready, create a PR containing the relevant commits. The PR description should summarise:

  * what changed;
  * why it changed;
  * important implementation decisions;
  * how it was tested;
  * anything that deserves human review or follow-up.
* **Do not merge to `main` automatically unless explicitly permitted.** Where possible, leave completed work as a reviewable PR for me to approve and merge.
* **Preserve useful history.** Do not rewrite, squash, rebase, or force-push shared history unless there is a clear reason. It is fine to clean up obviously noisy commits before presenting a PR, but retain meaningful intermediate decisions where they help explain the development of the feature.
* **Do not commit broken states deliberately.** Commits should ideally build, run, and pass the relevant checks so that individual points in the history remain useful.
* **Never commit secrets, credentials, generated junk, large local artefacts, or environment-specific files.** Update `.gitignore` when appropriate.
* **Use Git proactively.** You have permission to create commits, branches, and PRs when doing so improves the organisation, traceability, or reviewability of the work; you do not need to wait for explicit instructions each time.

The goal is for both the commit history and PR history to act as a readable timeline of the project: **commits explain the individual steps; PRs explain the larger units of work.**

## Project Management

Prefer [backlog.md](https://github.com/MrLesk/Backlog.md) for project management.
This tool allows tasks and epics to be stored in markdown.
During init you can install various skills that provide context
on how to use this tool.
It's a tool we can both use to keep track of work.

## Subfolder [CLAUDE.md](http://CLAUDE.md)

Experimenting with having [CLAUDE.md](http://CLAUDE.md) files in every subfolder

* Describes every file \+ subfolder in that folder  
* Setup test to check every subfolder has a [CLAUDE.md](http://CLAUDE.md) file, and that the [CLAUDE.md](http://CLAUDE.md) file references all the files inside that folder

## Claude Skills

Encouraging Claude to make skills as it goes.  
Useful for working with external tools \+ apis \+ packages.

1. Get claude to do web research on using the tool  
2. Get claude to create a skill that has what it’s learned  
3. Restart claude code to make the new skill available

## Isolated Environments

Preferably VMs, but docker containers are an acceptable middle ground.

**Container approach**  
Inside a local repo, you can add a Dockerfile and docker-compose.yaml \+ a bash script that allows you to create a container that shares the same working directory via file-mounts.  
This means you have claude running in a isolated container, with auto-mode or dangerously skip permissions — while still being able to view files and manage commits via an IDE.

**VM approach**  
Similar to above, except the code and runtime lives on an entirely different machine.  
This is more expensive, but requires spending some money, if you don’t have your own local  
VM.

## Web Research

I’ve noticed, getting Claude to do web research before doing work massively improves performance.

## Test Suites

Test suites are great as it’s an easy way for Claude to catch regression issues, without having to go back and check everything itself.  
It’s also useful for enforcing some claude practises we want e.g. having [CLAUDE.md](http://CLAUDE.md) in every folder.  
So tests can be used not just to monitor the code, but also to monitor Claude’s working practises.

## Roadmaps

Roadmaps are the best starting point for a project.  
It helps keep both the agent and I clear on where we’re going, what’s been done etc.  
Now this doesn’t have to be one big roadmap file — you can have one [ROADMAP.md](http://ROADMAP.md) that provides a high-level summary that then links to individual roadmap files for each layer of the project e.g. feature by feature, or phase by phase.
Or do it in backlog.md as mentioned above.

## Planning

Getting Claude to create a plan first is always a good idea. It forces Claude to think about what it’s going to do before starting. This is a great opportunity to get Claude to do web research too. Now Claude has its own plan mode, but I think it’s also useful to have these plans committed in git, as it serves as a log of decisions made. It also allows us to have tight coupling between roadmaps and plans, where plans provide the full brief with the context and everything, and the roadmap turns that into actional steps that reference the plan where more context is needed.

## Compare at least 3 solutions before an architectural decision

Don't blindly go with the first idea that works. For any meaningful design decision (clustering method, embedding provider, client-data/sync library, data model, background-jobs approach) enumerate and genuinely weigh **at least 3 options** before committing — ideally backed by a quick spike or measurement, not just prose. The first thing that works is rarely the best thing.

Real example from this project: the first topic-clustering method (single-linkage / threshold) looked great on a 16-item test set, so it nearly got chosen. A proper bake-off against community detection (Louvain/Leiden) and HDBSCAN — *at realistic scale* — flipped the decision entirely (single-linkage fragments topics as data grows). 

The comparison doubles as the decision record: write down what was compared, what was chosen, and why, in a plan/research doc — so the reasoning isn't lost.

## Test at realistic scale, not just toy data

A result on a handful of items can reverse at thousands. Before trusting a design, validate it on realistic-**volume** and realistic-**shape** data — generate synthetic stress data and/or seed the tool with a realistic corpus (e.g. `scripts/seed.py`). Watch for behaviours that only appear with scale/density: clustering "chaining", O(n²) costs, fragmentation, latency. "It works on the demo data" is not "it works."

## Keep tests hermetic — no real API calls in the suite

Every subsystem backed by an external API (LLM, embeddings, web search) must have a deterministic **fake that's forced ON in tests**. When you add a new external-API-backed subsystem, add its fake to the test harness in the *same* change. Telltale signs of a leak: test runtime jumping (5s → 50s) and unexpected API cost. (We once shipped a chat feature whose tests silently hit the real Anthropic API because a `CHAT=fake` flag was missing — caught only by a suspiciously slow, paid test run.)

## Persist user data before best-effort enrichment

Order operations so a failure in a non-critical step can never lose user-facing data. Commit the raw/user input and the core result **first**, in their own transaction; do enrichment (embeddings, search indexing, AI titles) **afterwards** as best-effort, logged-on-failure. Real example: an AI chat reply was being lost on refresh because it shared one DB transaction with an embedding step that threw — the user watched the streamed text vanish. Critical first, derived/best-effort second.

## Agentic Loops (End-to-End access)

Giving the agent access to tools like playwright (or other similar agent browsers) is a great way to allow the agent to test its own work, and check that things are working before telling me the work is done.  
Of course the playwright example is specific to web dev. But the core idea is just giving the agent access to the source code as well as the end product, allowing it to do it’s own end-to-end testing.  
Perhaps we could also encourage it to create end-to-end tests in addition to unit tests and integration tests.

## Smaller Models

I’ve been using Haiku today and honestly it’s doing a great job for the project I’m currently working on (lyst-sprint-assistant). It’s still getting everything right, but just doing it much faster and much cheaper. The only inconvenience is the very small context window, which I’m going through pretty quickly.  
But other than that it’s all pros for this project:

- MUCH faster  
- MUCH cheaper

I think the simpler Haiku model can be effective if you’ve built your project well. In my case, I’m creating loads of [CLAUDE.md](http://CLAUDE.md) files and skills, so haiku is able to understand the context of things easily without having to interpret code itself.  
And because it’s running in a container with end-to-end access it can sort of brute force it’s way to the correct solution. I.e. it doesn’t have to be really clever and anticipate everything from the get-go. It can just build and fix issues as it comes across them.

## Subagents \+ Worktrees

Ideally enabling agents to spawn subagents can be very powerful for a number of reasons.  
The obvious one is you can get more done, faster.  
But also it’s quite efficient for context windows as each subagent has its own context window. So main agent can process a user request or roadmap batch, and then spin up subagents to actually do the work. Those subagents can choose the skills they need to complete the task, as well as store their own context from coming across [CLAUDE.md](http://CLAUDE.md) files. These won’t pollute the context windows of other subagents working on different tasks. So everything in the context window is highly relevant to the task being worked on, and then when the task is done, the subagent is dropped and the context window is cleared — vs working in the main agent where the context window just grows and grows.

## Claude’s thoughts on what’s going well

I asked Claude in a project session what it thinks is going well and what could be better.  
Here’s what it said:

What's working really well:                                                                                                                                                                                                                                                                                                  
     
  1\. Small, focused files \+ CLAUDE.md everywhere — This is the biggest win. I can understand a 200-file codebase by reading \~20 CLAUDE.md summaries and filenames instead of opening files. This saves enormous amounts of context and speeds up orientation.                                                                  
  2\. Persistent memory system — Not re-explaining the project, your preferences, and patterns every session is huge for token efficiency. I can pick up where we left off.  
  3\. Clear architectural constraints in CLAUDE.md — Knowing "lib owns disk I/O," "providers are read-only," etc. means I make correct decisions without asking. This prevents wasted back-and-forth.                                                                                                                           
  4\. Plan mode \+ explicit approval before coding — We align on approach once, then I can execute. No rework from misaligned assumptions.                                                                                                                                                                                       
  5\. Git history as context — Recent commits tell me what's been done and the direction. Saves asking "what should I assume about this?"                                                                                                                                                                                       
  6\. Test suite with fast feedback — Running 272 tests in 1 second means I catch my mistakes immediately, not after you reload the browser.                                                                                                                                                                                    
                                                                                                                                                                                                                                                                                                                               
  What could level up for bigger batches:                                                                                                                                                                                                                                                                                      
                                                                                                                                                                                                                                                                                                                               
  1\. README.md files in key directories — Beyond just CLAUDE.md summaries, a human-readable "here's how these pieces talk to each other" narrative. The web/ README is great; more like that in storage/, providers/, etc.                                                                                                     
  2\. Type checking in CI — Add mypy or similar. Right now I rely on tests to catch type errors; type checking would catch them faster and let me refactor more confidently.  
  3\. More integration tests — The new web tests are good; extending this pattern to storage layer, providers, and their boundaries would let me refactor fearlessly.                                                                                                                                                           
  4\. Clearer data-flow diagrams — ASCII diagrams in key CLAUDE.md files showing "snapshot flows through storage → web → template" help me understand where to touch code.                                                                                                                                                      
  5\. Explicit "definition of done" — When you give me a feature, tell me: "Done means: code compiles, 272 tests pass, web UI works on these flows, no console errors." Lets me self-verify.                                                                                                                                    
  6\. Acceptance test hints — Like "verify this by navigating to /tickets/AENG-2527, clicking Related PRs, and checking they're clickable." Saves me guessing what you'll test.                                                                                                                                                 
                                                                                                                                                                                                                                                                                                                               
  For scaling to bigger batches:                                                                                                                                                                                                                                                                                               
                                                                                                                                                                                                                                                                                                                               
  \- Sub-agents for parallel work — Already possible. I can spin up an agent to explore the codebase while I work on something else. Just needs explicit go-ahead in the prompt.                                                                                                                                                
  \- Isolation with worktrees — You mentioned avoiding worktrees under Docker, but if we're doing bigger parallel work, isolated branches for different tasks would prevent merge conflicts.  
  \- Staged rollout — Instead of "implement feature X," maybe "implement API layer, verify tests, then UI layer, verify tests." Smaller checkpoints.                                                                                                                                                                            
                                                                                                                                                                                                                                                                                                                               
  Token/speed efficiency specifically:                                                                                                                                                                                                                                                                                         
                                                                                                                                                                                                                                                                                                                               
  \- Memoization in my memory system — I'm already doing this (storing architectural principles, user preferences), but being more aggressive about caching decisions ("when refactoring storage, always preserve the one-read-one-write symmetry") saves re-thinking.                                                          
  \- Grep before Read — I'm already doing this, but having a .clodeignore or similar to exclude large generated files, logs, and node\_modules from grep scope would speed up searches.  
  \- Lazy CLAUDE.md updates — Right now I update CLAUDE.md carefully with every change. A faster approach: commit code, update CLAUDE.md in a follow-up batch when the feature stabilizes. Trades documentation lag for speed.                                                                                                  
                                                                                                                                                                                                                                                                                                                               
  The workflow is already pretty solid — the small files \+ memory \+ tests \+ plan mode combination is doing a lot of the heavy lifting. The main gaps are around confidence (more tests) and communication (clearer acceptance criteria, diagrams).      
