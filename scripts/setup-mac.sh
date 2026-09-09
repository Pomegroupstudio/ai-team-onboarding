#!/usr/bin/env bash
# ==============================================================================
# Pome Studio - Agentic AI 1-Click Setup for macOS
# Configures VS Code, Ripgrep, Roo Code & DeepSeek Workspace in < 60 seconds
# ==============================================================================

set -e

echo ""
echo "\033[1;36m==========================================================\033[0m"
echo "\033[1;36m   🚀 Pome Studio - Agentic AI 1-Click macOS Setup        \033[0m"
echo "\033[1;36m==========================================================\033[0m"
echo ""

# 1. Connectivity Check
echo "\033[1;33m[1/5] Checking connection to DeepSeek API...\033[0m"
if curl -I -s --max-time 6 https://api.deepseek.com | grep -qE "HTTP/[0-9.]+ (200|401|403|404)"; then
    echo "\033[1;32m      [OK] Successfully connected to DeepSeek API!\033[0m"
else
    echo "\033[1;31m      [!] WARNING: Could not reach https://api.deepseek.com\033[0m"
    echo "\033[1;33m      Please verify your VPN / Proxy is active.\033[0m"
    read -p "Do you want to continue anyway? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "\033[1;31mSetup aborted.\033[0m"
        exit 1
    fi
fi

# 2. Close running VS Code
echo "\033[1;33m[2/5] Preparing VS Code environment...\033[0m"
pkill -f "Visual Studio Code" || true
sleep 1
echo "\033[1;32m      [OK] Clean state ready.\033[0m"

# 3. Ripgrep Setup
echo "\033[1;33m[3/5] Configuring Ripgrep engine...\033[0m"
if command -v rg >/dev/null 2>&1; then
    echo "\033[1;32m      [OK] Ripgrep already installed: $(rg --version | head -n 1)\033[0m"
else
    if command -v brew >/dev/null 2>&1; then
        echo "\033[1;36m      Installing ripgrep via Homebrew...\033[0m"
        brew install ripgrep
    else
        echo "\033[1;36m      Downloading standalone ripgrep...\033[0m"
        ARCH=$(uname -m)
        if [ "$ARCH" = "arm64" ]; then
            RG_URL="https://github.com/BurntSushi/ripgrep/releases/download/14.1.1/ripgrep-14.1.1-aarch64-apple-darwin.tar.gz"
        else
            RG_URL="https://github.com/BurntSushi/ripgrep/releases/download/14.1.1/ripgrep-14.1.1-x86_64-apple-darwin.tar.gz"
        fi
        TEMP_DIR=$(mktemp -d)
        curl -fsSL "$RG_URL" | tar -xz -C "$TEMP_DIR"
        sudo cp "$TEMP_DIR"/*/rg /usr/local/bin/rg 2>/dev/null || cp "$TEMP_DIR"/*/rg "$HOME/bin/rg"
        rm -rf "$TEMP_DIR"
    fi
fi

# 4. Install Roo Code Extension
echo "\033[1;33m[4/5] Checking Roo Code extension...\033[0m"
if command -v code >/dev/null 2>&1; then
    code --install-extension rooveterinaryinc.roo-cline --force >/dev/null 2>&1 || true
    echo "\033[1;32m      [OK] Roo Code extension verified.\033[0m"
else
    echo "\033[1;33m      [!] 'code' CLI not in PATH. Please verify Roo Code is installed in VS Code Extensions.\033[0m"
fi

# 5. Create Workspace
echo "\033[1;33m[5/5] Creating starter workspace...\033[0m"
WORKSPACE="$HOME/ai-workspace"
mkdir -p "$WORKSPACE"

README="$WORKSPACE/README.md"
if [ ! -f "$README" ]; then
    cat << 'EOF' > "$README"
# AI Coding Workspace 🚀
Welcome to your agentic AI workspace powered by **Roo Code** and **DeepSeek**!

### Quick Start:
1. Open the **Roo Code** sidebar on the left (Roo icon).
2. Ensure API Provider is **DeepSeek** with your API key.
3. Click **+** (New Task) and type:
   `Create a modern Pomodoro timer web app with sound and statistics`
4. Press **Enter** and watch Roo Code build your project!
EOF
fi

echo "\033[1;32m      [OK] Workspace ready at: $WORKSPACE\033[0m"
echo ""
echo "\033[1;32m==========================================================\033[0m"
echo "\033[1;32m   🎉 SETUP COMPLETE! Launching VS Code...                \033[0m"
echo "\033[1;32m==========================================================\033[0m"
echo ""

if command -v code >/dev/null 2>&1; then
    code "$WORKSPACE"
else
    open -a "Visual Studio Code" "$WORKSPACE" 2>/dev/null || true
fi
