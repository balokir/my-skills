---
name: persistent-work-context
description: Resume and synchronize cross-session repository workstreams from authoritative plans and compact engineering-memory work-context records. Use at the start of a repository run, when the user asks to resume or continue a known or ambiguous workstream, after a material active-plan checkpoint, or when a workstream completes, is abandoned, or is replaced. Do not use for unrelated standalone tasks, routine messages, or merely because engineering-memory is available.
---

# Persistent Work Context

Restore only the workstream the user intends to continue. Keep repository
artifacts authoritative and persistent memory compact, optional, and
recoverable.

## Apply Authority In This Order

1. Follow the current user instruction.
2. Follow repository requirements, specifications, and accepted design.
3. Follow tracked plans and any authoritative continuation artifacts or state
   explicitly defined by the owning workflow.
4. Verify versioned configuration, source, tests, and current Git/worktree state.
5. Use persistent work context only as navigation and compact resume state.
6. Use other persistent engineering memory only as supporting knowledge.

Repair a confirmed stale memory record. Never let memory override a repository
artifact or conceal a tracker/repository conflict.

## Resolve Project Identity

Before the first engineering-memory call, follow any applicable
persistent-memory guidance. Resolve the stable `project:*` tag for the current
project and refer to it below as `<project-scope>`. Define `<project-key>` as the
value after the `project:` prefix. For example, `project:example-service` has
project key `example-service`.

Use the same project scope and project key for recall, record identifiers,
revisions, recovery, and lifecycle changes. Do not infer either value from
memory search results.

## Select Work Context

Classify the first relevant request before querying work-context records:

- For explicit resume/continue plus a known workstream, query only that workstream.
- For a clear workstream with continuation semantics, query only that workstream.
- For ambiguous continuation such as "continue current work", list only active
  project work contexts and resolve the intended workstream from repository
  evidence.
- For a standalone new or unrelated task, do not query work-context records.
- When the user explicitly requests previous context but engineering-memory is
  unavailable, state the limitation and reconstruct only from repository
  sources.

Do not scan `.temp` at startup. Do not recall work context repeatedly on every message.

Normalize a new workstream identifier to stable lowercase kebab-case. Reuse the
exact existing identifier for every later query or revision; do not create
spelling aliases.

## Recall And Resume

For an exact workstream lookup, require all of:

```text
<project-scope>
kind:work-context
workstream:<normalized-name>
record-id:work-context:<project-key>:<normalized-name>
status:active
```

Use `tag_match: all`, exclude superseded results during normal recall, and
expect zero or one active result. For ambiguous continuation, list with
`<project-scope>`, `kind:work-context`, and `status:active`, also using
`tag_match: all`.

After recall:

1. Follow the authoritative entry-point pointers.
2. Read the tracked plan.
3. Inspect current Git/worktree state and relevant repository evidence.
4. Read any additional authoritative continuation artifact only when the owning
   workflow explicitly defines one.
5. Reconcile any disagreement before continuing.
6. Recall other durable knowledge only when it materially reduces investigation.

If zero or multiple active results exist for a known workstream, use Recovery
before claiming restoration.

## Use The Work-Context Record Contract

Store work context as `memory_type: planning` with these tags:

```text
<project-scope>
kind:work-context
workstream:<normalized-name>
record-id:work-context:<project-key>:<normalized-name>
context-revision:<positive-integer>
status:active | status:staged | status:completed | status:abandoned | status:superseded
```

Use exactly one lifecycle-status tag. Active content must remain compact:

```text
Workstream: <name>
Current phase: <one compact statement>
Authoritative entry points:
- <tracked planning index or owning document>
- <current tracked plan>
Ready work:
- <only material ready work>
Blocked work:
- <only material blocked work>
Nearest useful next actions:
1. <action>
Important prerequisites:
- <prerequisite>
Concrete blockers:
- <blocker or "none">
Last meaningful checkpoint:
- <summary and authoritative entry-point pointer>
```

Do not store complete checklists, raw logs, stack traces, full Git status,
ordinary branch/HEAD state, every commit or test, transient reasoning, or copied
requirements/design documents.

Store completed implementation history separately as `memory_type: milestone`
with `kind:implementation-history`, `workstream:<normalized-name>`,
`outcome:completed`, and `status:active`. A history record is durable knowledge,
not closed work context.

## Create Initial Active Context

When an exact active query returns no record:

1. Query all revisions with the fixed project, kind, workstream, and record-id
   tags and no lifecycle filter.
2. Reconcile an unresolved staged revision through Recovery before creating
   another revision.
3. Build compact content from the applicable authoritative plan, tracker, and
   continuation artifacts defined by the owning workflow and current repository
   state.
4. If an existing non-active revision has exactly the verified current content,
   promote that record rather than attempting an exact-hash duplicate store.
5. Otherwise store the next unused positive revision as `status:staged`.
6. Re-read and verify its complete content and tags.
7. Replace only `status:staged` with `status:active`, preserving every other tag.
8. Verify exactly one active revision with the expected pointers and no
   unresolved staged revision.

If store or promotion fails, leave the new record non-active, record the blocker
in the authoritative tracker, and continue repository work without claiming
persistent context was established.

## Replace Active Context Safely

Use staged replacement because the MCP surface does not guarantee in-place
content replacement:

1. Query all fixed-record-id revisions and the active subset; retain full tags
   and content hashes.
2. Run Recovery if a staged revision or other than one active revision exists.
   If no active revision remains, use initial creation.
3. Construct replacement content only after the applicable authoritative
   repository or workflow state is updated.
4. Do nothing when continuation state is materially unchanged.
5. Store an incremented revision with the same fixed tags and `status:staged`.
   Use a stable workstream `conversation_id` only when semantic deduplication
   would otherwise reject a materially changed revision; exact duplicate content
   remains a no-op.
6. Re-read and verify the staged record.
7. Replace the old record's complete tag set, preserving every non-status tag
   and changing only `status:active` to `status:superseded`.
8. Promote the staged record by replacing only `status:staged` with `status:active`.
9. Verify exactly one active revision with the expected revision and pointers,
   and no unresolved staged revision.

If old-record demotion fails, demote the staged record to `status:superseded`,
verify the old record remains the only active revision, record the failure, and
stop the update. If promotion fails, restore the old record to `status:active`,
leave the replacement non-active, record the failure, and do not claim
checkpoint completion.

Do not intentionally update one workstream concurrently from multiple sessions.
The MCP contract has no atomic compare-and-swap; every write must end with
exact-one-active verification.

## Recover Inconsistent Lifecycle State

When zero or multiple active records or an unresolved staged revision is found:

1. Read the authoritative plan, tracker, and continuation artifacts defined by
   the owning workflow and current repository state.
2. Query every revision for the fixed record-id, including staged and other
   non-active records.
3. Do not choose a winner from memory alone.
4. Select a revision that matches repository truth. If multiple revisions match
   equally, use the highest valid `context-revision` after verifying its complete
   content and tags.
5. Mark every other active or staged revision `status:superseded` without
   deleting it, then promote the verified winner when necessary.
6. If no revision is usable, mark stale staged revisions `status:superseded`
   and use initial creation.
7. Verify exactly one active record and no unresolved staged revision.
8. Reconcile any continuation-impacting repair against the owning workflow's
   authoritative repository state; persistent work context remains
   non-authoritative.

## Synchronize Only Material Checkpoints

For execution of an implementation-authority plan, the applicable plan-execution
workflow owns checkpoint/resume timing and ordering. This skill owns how
persistent work context is stored and replaced once that workflow requires an
update; it MUST NOT independently alter the plan-execution timing/order contract.

For implementation-authority plan execution, the tracked canonical plan and
current repository or worktree state are the authoritative continuation sources.
Persistent work context remains optional and non-authoritative and is updated
only after those sources are current and when Plan Execution requires a material
update. This skill MUST NOT introduce or require another continuation artifact
or pointer.

For other workflows, update persistent work context only after the applicable
authoritative tracker or workflow-defined handoff changes and only when at least
one changes:

- active plan or workflow-defined handoff destination;
- current implementation phase;
- material ready or blocked plan set;
- major prerequisite or concrete blocker;
- next meaningful action;
- workstream completion, abandonment, or replacement state.

Do not create a revision for one file change, one test, one small checklist item,
or ordinary HEAD movement.

For those other workflows, at a material plan checkpoint, use this order:

```text
complete step
-> verify
-> update authoritative tracker
-> commit when applicable
-> update workflow-defined handoff when the owning workflow requires one
-> update persistent work context
```

For those other workflows, before a long or expensive operation, ensure the
required authoritative tracker or continuation artifact is current, including a
workflow-defined handoff when one exists, then update optional work context when
the result is needed for safe resumption.

## Close Or Advance Work Context

For execution of an implementation-authority plan, Plan Execution owns when
persistent work context is closed or advanced; this skill owns the lifecycle
mutation and verification mechanics once that transition is required.

For other workflows, after repository artifacts are finalized, consider durable
findings and optional implementation history before changing work-context
lifecycle.

- When the same workstream has a concrete successor phase, use safe replacement
  to advance its active context.
- When no successor should remain active, replace the active lifecycle tag with
  exactly one of `status:completed`, `status:abandoned`, or `status:superseded`,
  preserving every other tag.
- Verify zero active records for a closed workstream, or exactly one verified
  active successor when advanced.
- Never delete work-context history.

## Continue Without Engineering Memory

Treat engineering-memory as optional. If it is unavailable:

- continue ordinary repository work from authoritative files and current Git or
  worktree state;
- do not install, configure, start, repair, or repeatedly reconnect the server;
- do not claim that work context was restored or synchronized;
- report the limitation only when the user explicitly requested previous context
  or the absence materially affects the result.
