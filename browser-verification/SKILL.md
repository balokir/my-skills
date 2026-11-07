---
name: browser-verification
description: >
  Use when Codex opens application pages, verifies UI behavior, checks visual
  layout regressions, captures browser screenshots, inspects browser element
  bounds, or uses Playwright/browser tools.
---

# Browser Verification

## Core Rules

- Use the browser's current/default viewport when opening a page unless the
  user requests a specific size or the task requires reproducing a layout at
  known dimensions.
- Do not set a viewport preemptively for ordinary functional checks.
- If a specific viewport is needed, state why before setting it.
- When reporting visual verification with a set viewport, include CSS viewport,
  DPR/scaling, physical screenshot size, and the screenshot file name.
- Store generated Playwright/browser screenshots under `.playwright-mcp/`, not
  in the project root.
- Treat attached screenshot dimensions as image dimensions, not as the user's
  real display resolution. Query the operating system separately when real
  display metrics matter.
- For HTTPS localhost certificate warnings, proceed only for local development
  URLs requested by the user.
- If login is required and credentials were provided in the conversation or
  repository workflow, log in first and then navigate back to the requested
  page.

## Browser Tool Selection

- Prefer a connected Playwright MCP server for page navigation, DOM inspection,
  element bounds, and screenshots.
- When Playwright MCP availability is unknown, check for tools using the exact
  `mcp__playwright__` prefix before reporting that browser automation is
  unavailable.
- Use Computer Use when Playwright MCP is unavailable or when the task requires
  native browser UI rather than page content.
- Failure of one browser driver does not establish that browser verification is
  unavailable. Try the next applicable connected driver before reporting an
  environment limitation.

## Server Rule

- Start repository servers through IntelliJ IDEA run configurations only, so
  the user can see run status and stop the process from the IDE.
- Do not start repository servers manually with `java -jar` from the shell
  unless the user explicitly requests manual startup.
- If an IDEA-launched server must be stopped and no MCP stop action exists,
  stop only the matching server PID and report it.

## Visual Checks

For layout or screenshot tasks:

1. Open the requested URL using the current/default browser size unless
   instructed otherwise.
2. If redirected to login, authenticate and return to the requested URL.
3. Inspect the relevant element bounds with browser evaluation when the issue
   involves clipping, overlap, off-screen content, or scrollability.
4. Capture a screenshot under `.playwright-mcp/` when it helps verify the result.
5. Report concise evidence: URL, viewport metrics if changed, relevant element
   bounds or computed styles, and screenshot path.

## Viewport And Display Metrics

- Browser CSS viewport can differ from physical screenshot size because of
  `devicePixelRatio` and system scaling.
- Real Windows display metrics can be checked with `System.Windows.Forms.Screen.AllScreens`.
- Screenshot bitmap dimensions can be checked separately from display metrics;
  do not conflate them.
