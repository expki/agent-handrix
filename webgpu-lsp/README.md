# webgpu-lsp

A Claude Code plugin that gives Claude a **WGSL / WESL language server** for WebGPU
shader development. It wires [`wgsl-analyzer`](https://github.com/wgsl-analyzer/wgsl-analyzer)
into Claude Code's `lspServers`, so Claude gets real code intelligence on shader files
instead of guessing.

It activates on `.wgsl` and `.wesl` files and gives Claude:

- **Diagnostics** — type errors, naga validation, unresolved names
- **Go-to-definition** and **find references**
- **Hover** — types and documentation
- **Rename** across a module
- **Completion** context

> WESL support in wgsl-analyzer is experimental upstream.

## Install

```bash
claude plugin marketplace add expki/agent-hendrix
claude plugin install webgpu-lsp@agent-hendrix
```

Restart Claude Code, then open a `.wgsl` or `.wesl` file. On first use the plugin
downloads the matching prebuilt `wgsl-analyzer` binary from the upstream release and
caches it — **no Rust toolchain required**.

## Notes

- **Supported platforms** — prebuilt binaries cover Linux (x86_64 gnu/musl, aarch64,
  armv7), macOS (Apple Silicon), and Windows (x86_64, aarch64). On Intel macOS or an
  offline machine, build from source instead (needs Rust ≥ 1.96):
  ```bash
  git clone --recursive https://github.com/expki/agent-hendrix.git
  ./agent-hendrix/webgpu-lsp/scripts/build-server.sh
  ```
- **Binary resolution** — the launcher tries, in order: `$WGSL_ANALYZER_PATH`, a
  cached/locally-built binary, `wgsl-analyzer` on `$PATH`, then a fresh download. Set
  `$WGSL_ANALYZER_PATH` to pin a specific binary (e.g. a `.exe` under WSL on Windows).
