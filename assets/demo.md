<p align="center">
  <img src="icon.png" width="84" height="84" alt="MacDown SE" />
</p>

# <p align="center">MacDown SE</p>

<p align="center">
  <b>The Apple Silicon continuation of the classic native Markdown editor for macOS.</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Architecture-Apple%20Silicon%20(arm64)-0071e3?style=flat-square" alt="Apple Silicon" />
  <img src="https://img.shields.io/badge/Intelligence-Model%20Context%20Protocol-8a2be2?style=flat-square" alt="MCP" />
  <img src="https://img.shields.io/badge/Privacy-Zero%20Telemetry-10b981?style=flat-square" alt="Zero Telemetry" />
  <img src="https://img.shields.io/badge/License-MIT-blue?style=flat-square" alt="MIT License" />
</p>

---

> **Design Philosophy**: Fast, lightweight, and private. MacDown SE pairs ==instant native AppKit rendering== with deep AI interoperability. We dropped ~~legacy Intel fat binaries~~ to focus entirely on Apple Silicon efficiency and responsiveness.

---

### Core System Profile

| Subsystem | Architecture | Status | Performance Profile |
| :--- | :--- | :---: | :--- |
| ⚡ **Core UI** | Native AppKit Cocoa | `Active` | Sub-second cold launch, 0.0% idle CPU |
|  **Binary** | Apple Silicon (`arm64`) | `Verified` | Tailored exclusively for M1 through M5 |
| 🧠 **Intelligence** | Model Context Protocol | `Ready` | stdio MCP server for direct AI tool use |
| 🔒 **Privacy** | Sovereign Local Engine | `Enforced` | Zero analytics, zero cloud network calls |
| 📝 **Parser** | GFM + Hoedown Engine | `Modern` | Synchronized live dual-pane preview |

---

### Model Context Protocol (MCP) Integration

MacDown SE embeds a native Model Context Protocol server. Any AI agent, local model, or harness can inspect and edit the active buffer in real time:

```python
# Connect any local AI harness directly to MacDown SE via MCP
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

params = StdioServerParameters(command="macdown-se", args=["--mcp"])

async def inspect_active_document():
    async with stdio_client(params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            doc = await session.call_tool("macdown_get_active_document", {})
            print(f"Inspecting: {doc.title} ({len(doc.content)} bytes)")

asyncio.run(inspect_active_document())
```

---

### Engineering & Compliance Checklist

- [x] Native 64-bit Apple Silicon (`arm64`) execution
- [x] Hardened Runtime with Apple Notary Service ticket stapled
- [x] Model Context Protocol server bridged to AppKit document layer
- [x] Restorable split-pane divider layout and state preservation
- [x] Mathematical equation typesetting via MathJax

---

### Mathematical Typesetting

$$e^{i\pi} + 1 = 0 \qquad\text{and}\qquad \mathcal{L}_{\text{loss}} = -\sum_{i=1}^{N} y_i \log(\hat{y}_i)$$

*Maintained by Eldris Inc. Released under the terms of the MIT License.*
