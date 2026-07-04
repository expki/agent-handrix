#!/usr/bin/env bash
#
# Launcher for the wgsl-analyzer WGSL/WESL language server.
#
# Claude Code spawns this as the LSP `command`. The language server speaks LSP
# over stdio, so stdout MUST carry only the protocol stream — every diagnostic
# message here goes to stderr, and we `exec` the real binary so its stdio is
# wired straight through.
#
# Resolution order for the server binary:
#   1. $WGSL_ANALYZER_PATH              (explicit override, if executable)
#   2. cached prebuilt binary           (previously downloaded, this version)
#   3. bundled submodule release build  (analyzer/target/release, if built)
#   4. `wgsl-analyzer` on $PATH
#   5. download the matching prebuilt binary from the upstream release
#
# Tier 5 means users don't need Rust/cargo: on first run the launcher fetches
# the platform binary that upstream already publishes, mirroring wgsl-analyzer's
# own editor bootstrap. `scripts/build-server.sh` stays as an offline fallback.
#
set -euo pipefail

# Upstream release the vendored submodule is pinned to. Keep in sync with the
# submodule commit (currently tag 2026-04-26).
WA_VERSION="2026-04-26"
WA_REPO="wgsl-analyzer/wgsl-analyzer"

# CLAUDE_PLUGIN_ROOT is set by Claude Code; fall back to this script's parent
# directory so the launcher also works when run directly.
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-"$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"}"
BUILT="${PLUGIN_ROOT}/analyzer/target/release/wgsl-analyzer"

# Downloaded binaries persist here across plugin updates when Claude Code sets
# CLAUDE_PLUGIN_DATA; otherwise fall back to the XDG cache.
CACHE_DIR="${CLAUDE_PLUGIN_DATA:-${XDG_CACHE_HOME:-$HOME/.cache}/wgsl-analyzer-lsp}"

log() { printf 'wgsl-analyzer-lsp: %s\n' "$*" >&2; }

# Map the host to the upstream release target triple. Echoes the triple, or an
# empty string for platforms upstream does not publish (e.g. Intel macOS).
detect_target() {
  local os arch
  os="$(uname -s)"; arch="$(uname -m)"
  case "${os}" in
    Linux)
      case "${arch}" in
        x86_64|amd64)
          if (ldd --version 2>&1 | grep -qi musl) || [ -f /etc/alpine-release ]; then
            printf 'x86_64-unknown-linux-musl'
          else
            printf 'x86_64-unknown-linux-gnu'
          fi ;;
        aarch64|arm64) printf 'aarch64-unknown-linux-gnu' ;;
        armv7l|armv7)  printf 'arm-unknown-linux-gnueabihf' ;;
      esac ;;
    Darwin)
      case "${arch}" in
        arm64|aarch64) printf 'aarch64-apple-darwin' ;;
      esac ;;
  esac
}

cached_binary() { printf '%s/wgsl-analyzer-%s-%s' "${CACHE_DIR}" "${WA_VERSION}" "$1"; }

# Fetch + decompress the prebuilt binary into the cache. Echoes its path on
# success (stdout); all progress goes to stderr.
download_binary() {
  local target dest url gz
  target="$(detect_target)"
  if [ -z "${target}" ]; then
    log "no prebuilt binary for $(uname -s)/$(uname -m) — build it with scripts/build-server.sh or set \$WGSL_ANALYZER_PATH."
    return 1
  fi
  dest="$(cached_binary "${target}")"
  url="https://github.com/${WA_REPO}/releases/download/${WA_VERSION}/wgsl-analyzer-${target}.gz"
  gz="${dest}.download.gz"
  mkdir -p "${CACHE_DIR}"
  log "fetching wgsl-analyzer ${WA_VERSION} (${target}) from upstream release..."
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "${url}" -o "${gz}" || { rm -f "${gz}"; log "download failed: ${url}"; return 1; }
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "${gz}" "${url}" || { rm -f "${gz}"; log "download failed: ${url}"; return 1; }
  else
    log "need curl or wget to download the server binary."
    return 1
  fi
  gunzip -f "${gz}" || { rm -f "${gz}" "${dest}.download"; log "failed to decompress ${gz}"; return 1; }
  chmod +x "${dest}.download"
  mv -f "${dest}.download" "${dest}"
  printf '%s' "${dest}"
}

resolve_server() {
  local target cached bin
  if [ -n "${WGSL_ANALYZER_PATH:-}" ] && [ -x "${WGSL_ANALYZER_PATH}" ]; then
    printf '%s' "${WGSL_ANALYZER_PATH}"; return 0
  fi
  target="$(detect_target)"
  if [ -n "${target}" ]; then
    cached="$(cached_binary "${target}")"
    if [ -x "${cached}" ]; then printf '%s' "${cached}"; return 0; fi
  fi
  if [ -x "${BUILT}" ]; then printf '%s' "${BUILT}"; return 0; fi
  if command -v wgsl-analyzer >/dev/null 2>&1; then command -v wgsl-analyzer; return 0; fi
  if bin="$(download_binary)"; then printf '%s' "${bin}"; return 0; fi
  return 1
}

if ! SERVER="$(resolve_server)"; then
  {
    echo "wgsl-analyzer: could not obtain the language server binary."
    echo "Any of the following fixes it:"
    echo "  - ensure network access so the prebuilt binary can be downloaded, or"
    echo "  - build it locally:  \"${PLUGIN_ROOT}/scripts/build-server.sh\", or"
    echo "  - point \$WGSL_ANALYZER_PATH at an existing wgsl-analyzer binary."
  } >&2
  exit 127
fi

exec "${SERVER}" "$@"
