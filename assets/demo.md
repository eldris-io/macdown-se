# MacDown SE

The Apple Silicon continuation of the classic native Markdown editor for macOS.

**Pure Native AppKit** • **Apple Silicon Native (arm64)** • **Zero Telemetry** • **Model Context Protocol (MCP)**

---

## Instant Synchronized Preview

MacDown SE combines a lightweight Cocoa editor with an instantaneous HTML preview pane. Type on the left, see rendered output on the right, with smooth synchronized scrolling.

> "Simplicity is about subtracting the obvious and adding the meaningful."  
> John Maeda, *The Laws of Simplicity*

### Core Architectural Profile

| Capability | Implementation | Operating Profile |
| :--- | :--- | :--- |
| **User Interface** | Pure AppKit Cocoa | Sub-second launch, zero Electron bloat |
| **Architecture** | Apple Silicon (`arm64`) | Optimized for M1 through modern M-series chips |
| **Intelligence** | Model Context Protocol | Built-in stdio MCP server for local AI workflows |
| **Privacy** | Sovereign & Local | Zero telemetry, zero analytics, zero network tracking |
| **Licensing** | Open Source | MIT License, maintained by Eldris Inc. |

---

## Model Context Protocol (MCP) Integration

MacDown SE includes an integrated MCP server via its command-line tool. Any AI harness, agent, or client supporting the MCP standard can inspect and edit the active buffer in real time:

```python
import asyncio
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

server_params = StdioServerParameters(
    command="macdown-se",
    args=["--mcp"]
)

async def inspect_editor():
    async with stdio_client(server_params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            doc = await session.call_tool("macdown_get_active_document", {})
            print(f"Loaded: {doc.title} ({len(doc.content)} bytes)")

asyncio.run(inspect_editor())
```

---

## Engineering Checklist

- [x] Native Apple Silicon 64-bit (`arm64`) execution
- [x] Model Context Protocol stdio server with AppKit IPC bridge
- [x] Relaxed CommonMark and GFM list syntax parsing
- [x] Dynamic split view restoration and pane state management
- [x] Hardened Runtime and Apple Notary Service Gatekeeper compliance

---

## Mathematical Typesetting

Full support for TeX and LaTeX mathematical equations via MathJax:

$$f(x) = \frac{1}{\sigma \sqrt{2\pi}} \exp\left( -\frac{1}{2}\left(\frac{x - \mu}{\sigma}\right)^{\!2}\,\right)$$

*MacDown SE is maintained by Eldris Inc. and published under the MIT License.*
