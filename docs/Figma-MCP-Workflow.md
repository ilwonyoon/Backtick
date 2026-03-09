# Figma MCP Workflow

## Status

This workspace is already connected to the Figma MCP server through Codex.

Verified on March 8, 2026:

- Codex Figma MCP server is registered in `~/.codex/config.toml`
- `rmcp_client = true` is enabled
- `FIGMA_OAUTH_TOKEN` is present in the environment
- `whoami` succeeds against Figma MCP

Authenticated user at verification time:

- `ilwonyoon@gmail.com`

## What Works Now

From this Codex session, we can:

- read Figma design context from file or node links
- inspect screenshots, metadata, variables, and assets from Figma
- map Figma components to code with Code Connect
- create simple diagrams in FigJam
- generate editable Figma designs from web pages or HTML
- add generated design output into a new or existing Figma file

## Important Limitation For Prompt Cue

Prompt Cue is a native macOS app built with SwiftUI and AppKit.

The current Figma design-generation path is strongest for:

- web pages
- HTML
- existing Figma files and nodes

There is not a one-click path from a live native macOS window to a fully editable Figma screen through this toolchain.

## Best Workflows For This Repo

### Figma To Code

Use this when the design source is already in Figma.

1. Copy a Figma frame or node link.
2. Give the link to Codex.
3. Codex reads the node through Figma MCP and implements it in Prompt Cue.

### Code To Figma For Web Or HTML

Use this when there is a local or deployed web representation.

1. Provide the local URL or HTML.
2. Codex uses Figma design generation to capture it.
3. Output goes to a new or existing Figma file.

### Code To Figma For Prompt Cue Native Screens

Use this when the source is the native macOS UI in this repo.

Fastest practical options:

1. Build a lightweight HTML mirror for a specific screen, then send that HTML to Figma.
2. Use screenshots as reference and reconstruct only the screens worth iterating in Figma.
3. Keep Figma as the source of truth for the next iteration, then round-trip back into code with node links.

Option 1 is usually the fastest automation-friendly path if the target is a small set of Prompt Cue surfaces such as:

- capture panel
- review stack
- settings slices

## Recommended Next Step

For this project, the most efficient path is:

1. Pick the exact Prompt Cue screens you want in Figma.
2. Create a small HTML mirror only for those screens if you want editable Figma output from code.
3. Keep future iteration round-tripping between:
   - Figma node link -> Codex -> native app
   - native app change -> targeted Figma recreation when needed

## References

- OpenAI announcement: `https://openai.com/index/figma-partnership/`
- Figma MCP intro: `file://figma/docs/intro.md`
- Figma MCP local server installation: `file://figma/docs/local-server-installation.md`
- Figma MCP plans and permissions: `file://figma/docs/plans-access-and-permissions.md`
