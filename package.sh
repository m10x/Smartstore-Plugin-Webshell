#!/usr/bin/env bash
#
# Builds the uploadable plugin package Smartstore.Module.M10x.Webshell.1.0.0.zip,
#
# Since Smartstore only accepts packages from a compiled Release build
# (the ZIP must contain e.g. manifest.json), this runs the official
# packager (Smartstore.Packager.Cli) against a Smartstore source checkout.
#
# Usage:
#   ./package.sh /path/to/Smartstore [--output directory]
#
set -euo pipefail

# Smartstore.ModuleBuilder still targets .NET 9 while only the .NET 10
# runtime is installed: allow build tools to roll forward to the newer major.
export DOTNET_ROLL_FORWARD=LatestMajor

MODULE="M10x.Webshell"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 /path/to/Smartstore [--output directory]" >&2
  exit 2
fi

SMARTSTORE_DIR="$1"
OUTPUT_DIR="$(pwd)"
if [[ "${2:-}" == "--output" ]]; then
  if [[ $# -lt 3 ]]; then
    echo "Missing value for --output" >&2
    exit 2
  fi
  OUTPUT_DIR="$3"
fi

# The packager requires absolute paths.
SMARTSTORE_DIR="$(cd "$SMARTSTORE_DIR" && pwd)"
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"

# Resolve dotnet: prefer PATH, otherwise probe common install locations.
DOTNET="$(command -v dotnet || true)"
if [[ -z "$DOTNET" ]]; then
  for candidate in "$HOME/.dotnet/dotnet" "/usr/share/dotnet/dotnet" "/usr/lib/dotnet/dotnet" /snap/bin/dotnet* /snap/dotnet-sdk-*/current/usr/bin/dotnet; do
    if [[ -x "$candidate" ]]; then
      DOTNET="$candidate"
      echo "Using dotnet at: $DOTNET (not on PATH)" >&2
      break
    fi
  done
fi
if [[ -z "$DOTNET" ]]; then
  echo "dotnet SDK not found. Install the .NET SDK (Smartstore 6.4 needs .NET 10)" >&2
  echo "and make sure 'dotnet' is on your PATH, e.g.: export PATH=\"\$HOME/.dotnet:\$PATH\"" >&2
  exit 1
fi
if ! "$DOTNET" --list-sdks 2>/dev/null | grep -q "^10\."; then
  echo "Warning: no .NET 10 SDK detected ('dotnet --list-sdks'). Smartstore 6.4 requires .NET 10." >&2
fi
if [[ ! -f "$SMARTSTORE_DIR/src/Smartstore.Web/Smartstore.Web.csproj" ]]; then
  echo "Not a Smartstore checkout: $SMARTSTORE_DIR/src/Smartstore.Web/Smartstore.Web.csproj missing." >&2
  exit 1
fi
if [[ ! -f "$SMARTSTORE_DIR/tools/Smartstore.Packager.Cli/Smartstore.Packager.Cli.csproj" ]]; then
  echo "Packager CLI not found: $SMARTSTORE_DIR/tools/Smartstore.Packager.Cli missing." >&2
  exit 1
fi

# 1. place the module in the checkout
mkdir -p "$SMARTSTORE_DIR/src/Smartstore.Modules/$MODULE"
if command -v rsync >/dev/null 2>&1; then
  rsync -a --delete --exclude 'bin/' --exclude 'obj/' "$(dirname "$0")/src/$MODULE/" "$SMARTSTORE_DIR/src/Smartstore.Modules/$MODULE/"
else
  rm -rf "$SMARTSTORE_DIR/src/Smartstore.Modules/$MODULE"
  mkdir -p "$SMARTSTORE_DIR/src/Smartstore.Modules/$MODULE"
  cp -r "$(dirname "$0")/src/$MODULE/." "$SMARTSTORE_DIR/src/Smartstore.Modules/$MODULE/"
  rm -rf "$SMARTSTORE_DIR/src/Smartstore.Modules/$MODULE/bin" "$SMARTSTORE_DIR/src/Smartstore.Modules/$MODULE/obj"
fi

# 2. build in Release mode (output: src/Smartstore.Web/Modules/M10x.Webshell)
# SmartstoreLightningCssRid: the snap SDK reports a distro-specific host RID
# (ubuntu.22.04-x64) which the LightningCSS native package does not know.
"$DOTNET" build "$SMARTSTORE_DIR/src/Smartstore.Modules/$MODULE/$MODULE.csproj" -c Release \
  -p:SmartstoreLightningCssRid=linux-x64

# 3. package with the official packager
mkdir -p "$OUTPUT_DIR"
"$DOTNET" run --project "$SMARTSTORE_DIR/tools/Smartstore.Packager.Cli" -c Release -- \
  pack --root "$SMARTSTORE_DIR/src/Smartstore.Web" --output "$OUTPUT_DIR" --extension "$MODULE"
