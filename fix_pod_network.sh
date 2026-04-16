#!/bin/bash

# Fix for CocoaPods network errors when downloading dependencies
# This increases git buffer size and retries the installation

echo "🔧 Fixing git network settings for CocoaPods..."

# Increase git buffer size to handle large downloads
git config --global http.postBuffer 524288000
git config --global http.maxRequestBuffer 100M
git config --global core.compression 0

# Increase git timeout
git config --global http.lowSpeedLimit 0
git config --global http.lowSpeedTime 999999

echo "✅ Git settings updated"
echo ""
echo "📦 Retrying pod install..."
echo ""

cd /Users/rokibulislam/Desktop/only_Focus/only_focus/ios

# Clean and retry
rm -rf Pods Podfile.lock
pod install --repo-update

echo ""
echo "✅ Done!"
