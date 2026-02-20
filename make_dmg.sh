#!/bin/bash
# make_dmg.sh — Builds the release .app bundle and packages it into a .dmg
# Usage: ./make_dmg.sh
set -e
cd "$(dirname "$0")"

VERSION="1.0.0"
DMG_NAME="ChronoAudio-${VERSION}.dmg"
VOL_NAME="Chrono Audio"
STAGING_DIR="dmg_staging"

# 1. Build the .app bundle
echo "→ Building .app bundle..."
./build_app.sh

# 2. Create a clean staging directory
echo "→ Staging..."
rm -rf "$STAGING_DIR"
mkdir "$STAGING_DIR"
cp -r ChronoAudio.app "$STAGING_DIR/"
# Symlink to /Applications for drag-install UX
ln -s /Applications "$STAGING_DIR/Applications"

# 3. Pack into a read-write DMG, then convert to compressed read-only
echo "→ Creating DMG..."
rm -f "$DMG_NAME"

hdiutil create \
    -volname "$VOL_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$DMG_NAME"

# 4. Clean up staging
rm -rf "$STAGING_DIR"

echo ""
echo "✓ Created: $DMG_NAME"
echo ""
echo "To distribute: share $DMG_NAME"
echo "First-launch: right-click ChronoAudio.app → Open (Gatekeeper bypass)"
