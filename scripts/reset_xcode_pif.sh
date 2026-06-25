#!/bin/zsh
set -euo pipefail

echo "Stopping stuck Xcode build services..."
killall Xcode xcodebuild XCBBuildService 2>/dev/null || true

echo "Clearing Xcode build caches that commonly cause PIF transfer session failures..."
rm -rf "$HOME/Library/Developer/Xcode/DerivedData/Runner-*"
rm -rf "$HOME/Library/Developer/Xcode/DerivedData/ModuleCache.noindex"
rm -rf "$HOME/Library/Developer/Xcode/DerivedData/SDKStatCaches.noindex"
rm -rf "$HOME/Library/Caches/org.swift.swiftpm"
rm -rf "$HOME/Library/Developer/Xcode/UserData/Previews"

mkdir -p "$HOME/Library/Developer/Xcode/DerivedData"

echo "Done. Reopen ios/Runner.xcworkspace and build normally."
echo "Avoid using Clean Build Folder first; try a normal build after this reset."
