#!/usr/bin/env bash
#
# Build the wgsl-analyzer language server from the bundled submodule.
# Run this once after cloning (and again after bumping the submodule).
#
set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-"$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"}"
ANALYZER="${PLUGIN_ROOT}/analyzer"

if [ ! -f "${ANALYZER}/Cargo.toml" ]; then
  echo "wgsl-analyzer submodule not found at ${ANALYZER}." >&2
  echo "Initialize it first:  git submodule update --init --recursive" >&2
  exit 1
fi

if ! command -v cargo >/dev/null 2>&1; then
  echo "cargo not found. Install the Rust toolchain: https://rustup.rs" >&2
  exit 1
fi

echo "Building wgsl-analyzer (release) from ${ANALYZER} ..." >&2
echo "Note: the submodule requires Rust >= 1.96 (edition 2024). If the build" >&2
echo "fails on manifest parsing, run: rustup update stable" >&2

cd "${ANALYZER}"
cargo build --release -p wgsl-analyzer

BINARY="${ANALYZER}/target/release/wgsl-analyzer"
echo "" >&2
echo "Built: ${BINARY}" >&2
"${BINARY}" --version >&2 || true
