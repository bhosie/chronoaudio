#!/bin/bash
set -e
cd "$(dirname "$0")"

# Quit any running instance gracefully
osascript -e 'quit app "ChronoAudio"' 2>/dev/null || true
sleep 0.5

# Rebuild and repackage
./build_app.sh

# Launch
open ChronoAudio.app
