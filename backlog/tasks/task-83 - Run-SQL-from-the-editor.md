---
id: TASK-83
title: Run SQL from the editor
status: To Do
assignee: []
created_date: '2026-08-21 14:21'
labels:
  - dev
  - dotfiles
dependencies:
  - TASK-24
ordinal: 85000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
SQL is the language named as predominant, and it is the one where an editor plugin changes the work rather than just annotating it. A language server tells you a keyword is misspelled; a database client lets you run the query and look at the rows, which is the actual job.

vim-dadbod and vim-dadbod-ui are the established pair: browse a connection's schemas and tables, write a query in a buffer, execute it and get the results in a split. Neither is packaged, so both come through whatever plugin management TASK-24 settles on, and both are plugins rather than binaries - so unlike a language server, this does not wait on TASK-43.

Worth deciding while doing it:

  * Where connection details live. They are credentials, so not in this repository - the same problem TASK-61.3 has for a calendar account and TASK-38 has for an ssh key, and the third time it comes up it should probably be solved once rather than three times.
  * Whether results open in a split, a tab or a floating window, which is a working-style question rather than a technical one and is best answered by trying it on a real query.
  * Whether the SQL dialect in use needs anything specific. Formatting and completion differ between Postgres, MySQL and SQLite far more than syntax highlighting suggests.

The SQL language server is deliberately not part of this. sqls is not in the official repositories, so it belongs with the other unpackaged servers and waits on TASK-43 - but the client half is the more useful half and does not need it.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A query can be written and run against a real database from inside the editor, and the results are readable
- [ ] #2 Schemas and tables can be browsed without leaving the editor
- [ ] #3 Connection details are not committed to this repository, and how secrets are handled is decided in a way TASK-38 and TASK-61.3 can reuse rather than solved a third time
- [ ] #4 Tried on a real query before being committed to, not judged from a screenshot
<!-- AC:END -->
