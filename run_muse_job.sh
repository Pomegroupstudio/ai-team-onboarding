#!/usr/bin/env bash
# ==============================================================================
# run_muse_job.sh — Execute Hello World & Growth Tasks with Meta Muse CLI
# ==============================================================================

set -euo pipefail

MUSE_BIN="${HOME}/.local/bin/muse"

echo "========================================================"
echo "  🚀 Meta Muse CLI Runner: Hello World & Growth Task"
echo "========================================================"

# 1. Verify CLI installation
if ! command -v "$MUSE_BIN" >/dev/null 2>&1; then
  echo "❌ Error: Muse CLI is not found at $MUSE_BIN."
  echo "Please run: curl -fsSL https://dev.meta.ai/install.sh | bash"
  exit 1
fi

MUSE_VERSION="$("$MUSE_BIN" --version)"
echo "✅ Found: $MUSE_VERSION"
echo ""

# 2. Check Authentication State
echo "🔍 Checking authentication..."
AUTH_CONFIG="${HOME}/.config/muse/auth.json"
HAS_AUTH=false

if [[ -n "${META_API_KEY:-}" ]] || [[ -f "$AUTH_CONFIG" ]]; then
  HAS_AUTH=true
fi

# 3. Formulate the Hello World Task Prompt
TASK_PROMPT="Analyze the repository and outline a viral user-acquisition strategy and interactive feature for serene-davinci to attract developers and focus enthusiasts."

if [ "$HAS_AUTH" = true ]; then
  echo "⚡ Authenticated! Executing headless job via Meta Model API (Muse Spark)..."
  echo "Prompt: $TASK_PROMPT"
  echo "--------------------------------------------------------"
  "$MUSE_BIN" exec --yolo "$TASK_PROMPT"
  echo "--------------------------------------------------------"
  echo "✅ Job completed successfully by Muse!"
else
  echo "ℹ️  Device authentication is currently pending or API key not set."
  echo "Running verification dry-run using the built-in deterministic provider..."
  echo "--------------------------------------------------------"
  "$MUSE_BIN" exec --provider echo "$TASK_PROMPT"
  echo "--------------------------------------------------------"
  echo ""
  echo "💡 To connect to the live Meta Muse Spark cloud:"
  echo "   1. Complete browser login by opening:"
  echo "      https://auth.meta.com/oauth/device/?code=BFFT-WMFM"
  echo "   2. Or set: export META_API_KEY='your-meta-api-key'"
  echo "   3. Then re-run: ./run_muse_job.sh"
fi

echo "========================================================"
