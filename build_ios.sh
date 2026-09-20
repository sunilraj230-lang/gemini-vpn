#!/usr/bin/env bash
# ==============================================================================
# GeminiVPN: 1-Click Xcode Project Generator & Build Script for macOS
# ==============================================================================

set -e

echo "🚀 Checking development environment..."

# 1. Check for Xcode Command Line Tools
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Error: Xcode Command Line Tools not found. Install via: xcode-select --install"
    exit 1
fi

# 2. Check / Install XcodeGen
if ! command -v xcodegen &> /dev/null; then
    echo "📦 XcodeGen not found. Installing via Homebrew..."
    if command -v brew &> /dev/null; then
        brew install xcodegen
    else
        echo "❌ Error: Homebrew not found. Install Homebrew or XcodeGen manually."
        exit 1
    fi
fi

# 3. Generate Xcode Project
echo "🔨 Generating GeminiVPN.xcodeproj using XcodeGen..."
xcodegen generate

echo "✅ Successfully generated GeminiVPN.xcodeproj!"

# 4. Prompt to open in Xcode
echo "📱 Opening project in Xcode..."
open GeminiVPN.xcodeproj

echo "================================================================="
echo "🎉 App is 100% Ready!"
echo "Next steps in Xcode:"
echo "1. Select your Apple Developer Team in Signing & Capabilities."
echo "2. Connect your iPhone."
echo "3. Press Run (Cmd + R)."
echo "================================================================="
