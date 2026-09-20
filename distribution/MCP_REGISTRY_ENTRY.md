# Model Context Protocol (MCP) Server Registry Entry

Target Repositories:
* `modelcontextprotocol/servers`
* `punkpeye/awesome-mcp-servers`

## Entry Snippet

```markdown
* [macdown-se](https://github.com/eldris-io/macdown-se) - Native macOS Markdown editor with built-in MCP server for real-time document inspection, buffer insertion, and cursor manipulation (`macdown-se --mcp`).
```

## MCP Configuration Example (`claude_desktop_config.json`)

```json
{
  "mcpServers": {
    "macdown": {
      "command": "/Applications/MacDown SE.app/Contents/SharedSupport/bin/macdown-se",
      "args": ["--mcp"]
    }
  }
}
```
