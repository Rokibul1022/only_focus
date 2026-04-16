#!/bin/bash

# Fix for CocoaPods dependency conflicts
# Run this script to resolve Firebase + Google ML Kit conflicts

echo "🔧 Fixing iOS dependencies..."

# Step 1: Clean everything
echo "1️⃣ Cleaning Flutter..."
cd /Users/rokibulislam/Desktop/only_Focus/only_focus
flutter clean

# Step 2: Update dependencies
echo "2️⃣ Getting Flutter dependencies..."
flutter pub get

# Step 3: Clean iOS pods
echo "3️⃣ Cleaning iOS pods..."
cd ios
rm -rf Pods
rm -rf Podfile.lock
rm -rf .symlinks

# Step 4: Update pod repo
echo "4️⃣ Updating CocoaPods repo..."
pod repo update

# Step 5: Install pods
echo "5️⃣ Installing pods..."
pod install

echo "✅ Done! Now run: flutter run"
