---
name: create-repo-snapshot
description: Create a verified ZIP repository review package from explicit unconditional include roots, optionally supplemented by Git-changed include roots, using the skill's bundled cross-platform scripts. Do not use for general backups or release packaging.
---

# Create Repository Snapshot

Resolve the bundled script relative to the directory containing this
`SKILL.md`. Invoke it while the current working directory remains inside the
target Git worktree; do not change the working directory to the skill folder.

Use the bundled script for the current shell:

- In Bash, run `bash <skill-root>/scripts/create-repo-snapshot.sh`.
- In PowerShell, run
  `pwsh -NoProfile -File <skill-root>/scripts/create-repo-snapshot.ps1`.

Require the user to supply these operational values:

- one `--output <zip-path>`;
- at least one `--include <path>`.

The user may optionally supply one or more `--include-changed <path>` values.
Require exactly one `--base-ref <git-ref>` when any `--include-changed` value
is supplied; otherwise do not require or infer a base ref.

Identify every missing argument and stop when any required value is absent. Do
not infer values from examples, prior runs, branch names, or repository layout.
Preserve every repeated `--include` and `--include-changed` as a separate
option. Before invoking the script, remove trailing `/` or `\` characters from
each `--include` and `--include-changed` value; preserve the rest of every
supplied value unchanged. This prevents the PowerShell script from treating a
directory root such as `docs/` as `docs//` during candidate matching and
incorrectly reporting an empty selection. Forward `--dry-run` only when
requested.

Use the invocation shape matching the user's selection mode; the placeholders
are not defaults:

```text
<platform-command> \
  --output <zip-path> \
  --include <path> \
  [--include <path> ...] \
  [--dry-run]

<platform-command> \
  --output <zip-path> \
  --include <path> \
  [--include <path> ...] \
  --base-ref <git-ref> \
  --include-changed <path> \
  [--include-changed <path> ...] \
  [--dry-run]
```

Run the selected script rather than reproducing its Git selection or archive
logic. Check its exit status. On success, report the destination archive path
and selected-file count from the script summary. When changed includes were
supplied, also report the merge-base SHA. For a dry run, report that no archive
was created and include the computed selection summary. On failure, report the
script diagnostic without claiming an archive was created.
