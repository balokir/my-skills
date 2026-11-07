---
name: idea-mcp-preferred
description: >
  Use whenever a task will call or discover IntelliJ IDEA MCP tools. Prefer IDEA MCP for supported repository
  operations after bootstrapping, load this guidance completely through the workspace shell before the first IDEA MCP
  operation, and never use mcp__idea__read_file or mcp__idea__execute_terminal_command.
---

# IDEA MCP Preferred

## Rule

Do not invoke `mcp__idea__execute_terminal_command`. Use the workspace shell for
every shell command. Do not invoke `mcp__idea__read_file`. This method is
disabled! Read file contents with bounded shell commands and page large files
when complete coverage is required.

Before using this workspace shell for project work, check whether an IDEA MCP
tool can do the same job with acceptable fidelity. Prefer IDEA MCP when it
preserves the requested behavior and does not hide required output.

Use shell commands when IDEA MCP has no equivalent, when repository guidance
requires an exact command, or when the task needs process/OS behavior outside
IDEA's project model.

## Preferred Replacements

- List or run IDE configurations: use `mcp__idea__get_run_configurations` and
  `mcp__idea__execute_run_configuration`.
- Find runnable code locations: use `mcp__idea__get_run_configurations` with
  `filePath`, then run with `filePath` and `line`.
- Search project text: use `mcp__idea__search_text` or
  `mcp__idea__search_regex`, with the narrowest supported directory, file, and
  result-count bounds.
- Inspect declarations or API semantics: use `mcp__idea__get_symbol_info`.
- Check a file for IDE errors or warnings: use
  `mcp__idea__get_file_problems`.
- Compile or validate IDE build state: use `mcp__idea__build_project`.
- Inspect project structure: use `mcp__idea__get_project_modules` and
  `mcp__idea__get_project_dependencies`.
- Open a file for the user in the IDE: use `mcp__idea__open_file_in_editor`.

## Shell Fallbacks

Use this workspace shell for:

- Stopping long-running servers by PID; current IDEA MCP tools do not expose a
  stop-run-configuration action.
- HTTP probes, port/process inspection, filesystem metadata, Git commands,
  archive operations, and other OS-level checks.
- Gradle wrapper commands required by repository skills, CI-equivalent test
  runs, or report/log inspection not exposed through IDEA MCP.
- Multi-file patching, file creation, or edits where `apply_patch` is clearer
  and safer than targeted replacement.
- Reading file contents with bounded or paged output;
  `mcp__idea__read_file` is prohibited as described above.

## Run Configuration Notes

For long-running server configurations, start with `waitForExit=false`, keep the
returned `fullOutputPath`, and inspect that log for startup or failure markers.
Record the Java PID separately when follow-up probes or shutdown are likely.

To stop a server started through IDEA MCP:

```powershell
Stop-Process -Id <pid> -ErrorAction Stop
```

## Reporting

When falling back to shell after this skill applies, briefly state why IDEA MCP
was not suitable, unless the reason is obvious from the command category above.
