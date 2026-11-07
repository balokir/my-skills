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
$skillsSource = (Get-Location).Path
$skillsHome = Join-Path $env:USERPROFILE ".agents\skills"

New-Item -ItemType Directory -Force -Path $skillsHome | Out-Null

Get-ChildItem -LiteralPath $skillsSource -Directory |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName "SKILL.md") } |
    ForEach-Object {
        $linkPath = Join-Path $skillsHome $_.Name
        if (Test-Path -LiteralPath $linkPath) {
            throw "Skill destination already exists: $linkPath"
        }

        New-Item -ItemType SymbolicLink -Path $linkPath -Target $_.FullName |
            Out-Null
    }
```

Directory symlinks keep Git operations in this repository independent from
Codex's own state in `~/.codex`. A checkout or pull may replace files inside a
skill directory without breaking the link to that directory.

Start a new Codex session after adding or removing skills, or after changing
activation metadata in a `SKILL.md` front matter block.

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
