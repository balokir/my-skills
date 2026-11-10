# Personal Codex Skills

This repository is the versioned source of truth for personal Codex skills.
The skills are kept outside Codex state directories and exposed to Codex through
directory symbolic links under `~/.agents/skills`.

## Included Skills

- [`browser-verification`](browser-verification/SKILL.md) — verifies application
  behavior and visual layout with browser automation.
- [`create-repo-snapshot`](create-repo-snapshot/SKILL.md) — creates a verified
  ZIP package for repository review.
- [`idea-mcp-preferred`](idea-mcp-preferred/SKILL.md) — defines safe, preferred
  use of IntelliJ IDEA MCP operations.
- [`persistent-memory-policy`](persistent-memory-policy/SKILL.md) — governs
  optional persistent engineering memory without making it a repository
  dependency.
- [`persistent-work-context`](persistent-work-context/SKILL.md) — restores and
  synchronizes cross-session work from authoritative plans and compact memory
  records.

Each skill is self-contained. Its `SKILL.md` front matter defines when Codex
should activate it.

## Installation On Windows

Windows Developer Mode must be enabled, or the shell must have permission to
create symbolic links. Run the following from the repository root in
PowerShell:

```powershell
node setup.mjs install
```

The setup script discovers repository directories containing `SKILL.md` and
links them under `~/.agents/skills`. It refuses to overwrite unexpected paths
and leaves unrelated installed skills untouched. Other available actions are:

```powershell
node setup.mjs status
node setup.mjs uninstall
```

Directory symlinks keep Git operations in this repository independent from
Codex's own state in `~/.codex`. A checkout or pull may replace files inside a
skill directory without breaking the link to that directory.

Codex detects skill changes automatically. If a change does not appear, start
a new Codex session.

## Updating Skills

Edit and commit files in this repository. Do not edit copies under
`~/.agents/skills`; those paths should remain symbolic links to these
directories.

Repository-specific `AGENTS.md` files should describe the required capability
in general terms. This lets Codex activate an installed personal skill when it
is available without making the repository depend on that skill by name or
path.

## Validation

Markdown files are checked with
[`rumdl`](https://github.com/rvben/rumdl):

```powershell
rumdl check README.md
rumdl check browser-verification/SKILL.md
```

Run the second command for each changed skill. If a skill includes scripts or
other assets, also run the focused verification documented by that skill.
