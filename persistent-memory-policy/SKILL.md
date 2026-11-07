---
name: persistent-memory-policy
description: Govern autonomous use of the optional engineering-memory MCP server for the current project. Use persistent memory to recall and preserve expensive-to-rediscover engineering knowledge while keeping repository sources authoritative, isolating memory by project, avoiding duplicates and secrets, and maintaining stale knowledge without making memory a repository dependency.
---

# Persistent Memory Policy

Use the `engineering-memory` MCP server as an optional cross-session engineering
memory when it is available.

Persistent memory is intended to reduce repeated investigation and preserve
durable engineering knowledge. It is not an authoritative source of project
requirements, architecture, source code, configuration, or documentation.

Cross-session execution and workstream continuation are governed by any
applicable work-context guidance. This policy continues to govern durable
engineering knowledge; it does not duplicate work-context selection,
replacement, recovery, checkpoint, or closure protocols.

Routine recall, storage, and correction of memory are autonomous agent
operations. Do not ask the user to curate ordinary memories, choose tags,
approve routine storage, or explicitly request recall.

Do not query memory for every prompt.

## Availability

- Treat persistent memory as an optional enhancement, never as a repository prerequisite.
- If `engineering-memory` or its required tools are unavailable, continue the
  task using repository sources and current user instructions.
- Do not fail or block a repository task solely because persistent memory is unavailable.
- Do not install, configure, start, repair, or repeatedly reconnect the server
  unless the user explicitly requests it.
- Mention unavailable persistent memory only when:
  - the user explicitly asks to recall prior memory; or
  - its absence materially limits the result.

## Project Scope

Every memory operation must use one stable `project:*` tag, referred to below
as `<project-scope>`.

Resolve it once per task in this order:

1. Use the single explicit `project:*` tag in applicable repository instructions.
2. Otherwise derive it from the canonical Git remote owner and repository name,
   normalized to lowercase kebab case.
3. If no canonical remote exists, derive it from the repository-root directory
   name using the same normalization.
4. If the identity is ambiguous or likely to collide with another project, do
   not write memory until an authoritative project scope is available.

Do not infer project scope from existing memory results. Once resolved, use the
same tag for recall, storage, updates, superseding, and duplicate checks.

For normal recall:

- require `<project-scope>`;
- require `status:active`;
- use `tag_match: all`;
- set `include_superseded: false`;
- normally limit results to 3–5 relevant memories.

Ignore:

- unscoped memories;
- memories belonging to other projects;
- superseded memories during ordinary recall.

Use `include_superseded: true` only when investigating history, changes over
time, superseded decisions, or previous approaches.

Never combine knowledge from different projects in one memory.

## Authority

The following sources are authoritative over persistent memory:

1. current user instructions;
2. repository requirements and specifications;
3. tracked plans and authoritative continuation artifacts or state explicitly
   defined by their owning workflows;
4. ADRs and design documents;
5. versioned configuration;
6. source code;
7. tests and verification evidence;
8. other current repository documentation.

Persistent memory is supporting engineering context, not a replacement for
these sources.

Before relying on a recalled memory:

- verify its project scope;
- verify that it is active;
- consider its provenance and age when relevant;
- confirm that it does not conflict with authoritative repository information.

If memory conflicts with an authoritative source, follow the authoritative
source and treat the memory as stale.

Do not silently preserve a stale active memory after detecting a confirmed conflict.

## When to Recall

Search persistent memory when previous engineering experience could materially
reduce repeated work.

Typical reasons to recall include:

- a similar problem may have been investigated before;
- a previous architectural or implementation decision may affect the task;
- there may be a known constraint or environment-specific behavior;
- an approach may already have failed;
- a workaround may already have been verified;
- a non-obvious root cause may already be known;
- historical context may explain current code or configuration;
- a stable user preference relevant to engineering work may matter.

Recall is particularly valuable before an investigation that would otherwise
require substantial:

- code exploration;
- debugging;
- experimentation;
- build or integration attempts;
- environment diagnosis;
- architectural reasoning.

Do not search memory merely because the server is available.

### Default Recall Shape

Use a semantic query describing the current engineering question and scope it to:

```json
{
  "tags": [
    "<project-scope>",
    "status:active"
  ],
  "tag_match": "all",
  "include_superseded": false,
  "limit": 5
}
```

Prefer a semantic query expressing the problem or concept rather than only
exact identifiers.

## When to Store

After completing meaningful investigation, implementation, debugging,
verification, design work, or technical analysis, consider whether the work
produced durable knowledge worth preserving.

Store knowledge when recovering or validating it again would require meaningful:

- investigation;
- experimentation;
- debugging;
- reasoning;
- historical context;
- cross-file interpretation;
- external or environment-specific observation.

The important criterion is the **cost of rediscovery**, not merely whether some
supporting evidence exists in the repository.

A fact may be worth storing even when its evidence exists in source code or
documentation if reconstructing the conclusion would require substantial
analysis.

Conversely, do not store information that can be recovered cheaply and
unambiguously from the repository.

### Good Memory Candidates

Prefer durable, confirmed knowledge such as:

- verified root causes;
- important implementation discoveries;
- failed approaches and why they failed;
- experimentally confirmed constraints;
- reliable workarounds;
- non-obvious environment behavior;
- important design decisions and their rationale when the rationale is not
  already clearly authoritative elsewhere;
- interactions between components that required substantial investigation to establish;
- stable engineering preferences relevant across sessions.

Examples of good memory value:

- a race condition whose cause required debugging to establish;
- an approach that repeatedly fails under a specific environment condition;
- a required initialization order discovered through investigation;
- a workaround verified against a real deployment;
- a performance behavior established through measurement.

### Do Not Store

Do not store:

- source files or large excerpts of source code;
- full logs or stack traces;
- temporary TODOs;
- current branches;
- transient reasoning plans, duplicated plan checklists, or copied
  workflow-owned continuation state;
- generated summaries merely because they were generated;
- routine file locations;
- ordinary module structure;
- commands already clearly documented;
- facts cheaply discoverable from current repository contents;
- unverified hypotheses;
- speculative conclusions;
- transient runtime state;
- authoritative requirements copied from the repository;
- ADR or design-document contents merely duplicated into memory;
- secrets or sensitive credentials.

Persistent memory should preserve the **result of expensive engineering
learning**, not mirror the repository.

A compact cross-session work-context pointer is not prohibited merely because
it references current execution state. It is a separate planning record governed
by applicable work-context guidance, must point back to authoritative repository
artifacts, and must not copy complete checklists or workflow-owned continuation
state from them.

## Autonomous Storage

Routine memory storage is autonomous.

Do not ask the user to:

- decide whether an ordinary confirmed finding should be stored;
- write the memory content;
- choose metadata or tags;
- approve routine `memory_store`;
- manually perform duplicate checks.

When a durable memory candidate is identified:

1. perform a scoped semantic search for an equivalent active memory;
2. determine whether the candidate adds materially new knowledge;
3. reuse, update, or supersede existing knowledge where appropriate;
4. store a new memory only when no equivalent active memory already captures
   the same knowledge.

Do not create multiple active memories expressing the same practical conclusion
in different wording.

An explicit user request such as "remember this" should strongly favor storage
unless prohibited by security, scope, or authority rules.

An explicit user correction should strongly favor updating or superseding the
affected memory.

## Memory Content

Each memory should be understandable in a future session without requiring the
original conversation.

Prefer concise, self-contained content containing:

- the durable conclusion;
- relevant conditions or scope;
- the reason or consequence when it affects future use;
- provenance when it affects confidence or interpretation.

Prefer one coherent engineering fact or decision per memory.

Do not force artificial atomicity when separating tightly coupled information
would make the memory misleading.

For example, a verified root cause and its required workaround may belong in the
same memory when the workaround only makes sense because of that root cause.

### Example

Good:

> Concurrent IntelliJ synchronization of two Gradle roots can race when both
> roots compile the same shared included build. Sequential synchronization avoids
> the concurrent compilation path. Confirmed during investigation of the Gradle
> synchronization failure.

Poor:

> Gradle issue.

Poor:

> Root A uses build-logic.

Poor:

> See README for Gradle details.

## Metadata

Every project memory must include:

- the resolved `<project-scope>` tag;
- a lifecycle status such as `status:active`.

Use additional metadata when it improves retrieval, interpretation, or lifecycle
management.

Values such as `kind:*`, `source:*`, `area:*`, `workstream:*`, and lifecycle
markers are tags. Use only memory types actually supported by the live MCP
contract; do not invent a custom memory type from a tag value.

Recommended metadata includes:

- `kind:decision`
- `kind:constraint`
- `kind:discovery`
- `kind:root-cause`
- `kind:failed-attempt`
- `kind:workaround`
- `kind:preference`
- `kind:environment`

Source metadata may include values such as:

- `source:investigation`
- `source:experiment`
- `source:user-confirmed`
- `source:verification`

Area tags such as `area:gradle`, `area:idea`, or `area:database` may be added
when useful.

Optional implementation history is stored as supported `milestone` memory with
both `kind:implementation-history` and `outcome:completed`. Keep `status:active`
so normal durable-memory recall can retrieve it; `outcome:completed` describes
the result and does not close the durable memory.

Do not invent metadata merely to satisfy a taxonomy.

`kind:*`, `source:*`, and `area:*` tags are aids to retrieval and interpretation,
not authoritative classifications.

Prefer meaningful memory content and project scoping over excessive tagging.

## Search Before Store

Before storing a new memory:

1. search active memories within `<project-scope>`;
2. use a semantic query representing the proposed knowledge;
3. inspect the closest matches;
4. avoid creating an equivalent active duplicate.

If an existing memory already expresses the same useful conclusion, do not
create another one.

If the existing memory is incomplete but still valid, update or extend it when
the available memory operations support that safely.

If the new knowledge contradicts or replaces the old knowledge, use the
superseding workflow.

## Stale and Superseded Knowledge

Do not delete useful engineering history merely because it became outdated.

When a confirmed active memory is replaced by newer knowledge:

1. locate the affected active memory;
2. preserve the new knowledge as the active state;
3. mark the old knowledge as superseded when supported;
4. preserve enough provenance to understand why and when the knowledge changed;
5. verify that normal recall returns the current knowledge;
6. retain historical knowledge for explicit history queries when useful.

Prefer a clear lifecycle:

```text
active → superseded
```

rather than two contradictory active memories.

For routine corrections, use the simplest supported update or supersede
operation that leaves only the current knowledge active.

For significant architectural or historical decisions, preserve stronger
provenance such as:

- replacement memory identifier or hash;
- date of replacement;
- reason for superseding.

Do not create elaborate version history for trivial corrections.

## Repository Information and Memory

Do not duplicate repository content merely for convenience.

However, distinguish between:

- information that is **cheaply readable** from the repository; and
- conclusions that are **expensive to derive** from repository evidence.

For example:

- "The project uses PostgreSQL 15" when directly declared in configuration is
  normally not worth storing.
- "A particular replication configuration increases WAL generation significantly
  under the measured workload" may be worth storing if that conclusion required
  investigation or measurement.

A memory may also serve as a concise pointer to expensive-to-rediscover knowledge
whose authoritative evidence remains in the repository.

When practical, include enough provenance to direct future work back to the
authoritative source rather than copying the source into memory.

## Failed Approaches

Failed approaches are particularly valuable when repeating them would consume
meaningful engineering time.

Store a failed approach when:

- it was seriously attempted;
- the failure was confirmed;
- the reason for failure is understood well enough to be useful;
- another agent could plausibly try the same approach again.

Include:

- what was attempted;
- under what relevant conditions;
- why it failed;
- any known alternative or workaround when confirmed.

Do not store every minor failed command or transient experiment.

## User Preferences

Store a user preference only when it is:

- stable across sessions;
- relevant to future engineering work;
- not already represented in repository instructions;
- safe to retain.

Repository instructions such as `AGENTS.md` and repository skills remain
authoritative over remembered preferences.

Do not duplicate an instruction already clearly encoded in repository policy
unless there is additional useful historical context.

## Secrets and Sensitive Data

Never store:

- passwords;
- API keys;
- access tokens;
- cookies;
- private keys;
- credentials;
- recovery codes;
- authentication material;
- sensitive personal data.

Never pass suspected secret content to `memory_store`, including synthetic test
secrets intended to resemble real credentials.

If the user explicitly requests storage of prohibited sensitive information:

1. do not call the write tool;
2. explain that persistent engineering memory must not contain such material.

## Destructive and Bulk Operations

Routine recall, store, update, and ordinary superseding do not require user approval.

Require explicit user approval before:

- deleting memories;
- bulk cleanup;
- mass metadata changes;
- destructive conflict resolution;
- bulk consolidation that rewrites or removes existing memories;
- mass replacement or migration of stored knowledge.

Before destructive operations:

- identify the exact affected memories;
- prefer stable hashes or identifiers when available;
- require a verified backup before mass deletion or replacement.

Do not interpret permission to store or update one memory as permission for
unrelated cleanup.

## Normal Operating Behavior

During ordinary repository work, persistent memory should remain unobtrusive.

Expected behavior:

```text
task
  ↓
recall previous knowledge when materially useful
  ↓
perform investigation / implementation / verification
  ↓
identify expensive-to-rediscover durable findings
  ↓
search for equivalent active memories
  ↓
store, update, supersede, or do nothing
  ↓
complete the task
```

Do not turn routine memory management into a separate user workflow.

Do not report every recall or storage operation unless:

- it materially affects the answer;
- a recalled memory conflicts with authoritative information;
- the user asks about memory behavior;
- a memory operation fails in a way relevant to the task.

The desired outcome is that future sessions benefit from previous engineering
work without requiring the user to act as a memory curator.
