#!/bin/bash
set -e
cd "$(dirname "$0")"

echo "→ Building release binary..."
swift build -c release

echo "→ Assembling ChronoAudio.app bundle..."
rm -rf ChronoAudio.app
mkdir -p ChronoAudio.app/Contents/MacOS
mkdir -p ChronoAudio.app/Contents/Resources

cp .build/release/ChronoAudio ChronoAudio.app/Contents/MacOS/ChronoAudio
cp -r .build/release/ChronoAudio_ChronoAudio.bundle ChronoAudio.app/Contents/Resources/

# App icon
if [ -f AppIcon.icns ]; then
    cp AppIcon.icns ChronoAudio.app/Contents/Resources/AppIcon.icns
fi

cat > ChronoAudio.app/Contents/Info.plist << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>Chrono Audio</string>
    <key>CFBundleName</key>
    <string>ChronoAudio</string>
    <key>CFBundleExecutable</key>
    <string>ChronoAudio</string>
    <key>CFBundleIdentifier</key>
    <string>com.chronoaudio.app</string>
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
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
</dict>
</plist>
PLIST

echo "→ Done! Launch with:"
echo "   open ChronoAudio.app"
echo "   # or double-click ChronoAudio.app in Finder"
