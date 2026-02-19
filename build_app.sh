#!/bin/bash
set -e
cd "$(dirname "$0")"

echo "→ Building release binary..."
swift build -c release

echo "→ Assembling GuitarApp.app bundle..."
rm -rf GuitarApp.app
mkdir -p GuitarApp.app/Contents/MacOS
mkdir -p GuitarApp.app/Contents/Resources

cp .build/release/GuitarApp GuitarApp.app/Contents/MacOS/GuitarApp
cp -r .build/release/GuitarApp_GuitarApp.bundle GuitarApp.app/Contents/Resources/

cat > GuitarApp.app/Contents/Info.plist << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>GuitarApp</string>
    <key>CFBundleName</key>
    <string>GuitarApp</string>
    <key>CFBundleExecutable</key>
    <string>GuitarApp</string>
    <key>CFBundleIdentifier</key>
    <string>com.guitarapp.app</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo "→ Done! Launch with:"
echo "   open GuitarApp.app"
echo "   # or double-click GuitarApp.app in Finder"
