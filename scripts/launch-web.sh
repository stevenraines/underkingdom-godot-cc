#!/bin/bash
# Export and launch Godot game in Chrome for testing with Claude browser plugin.
#
# Usage: ./scripts/launch-web.sh
#
# This script:
# 1. Re-exports the web build (debug mode)
# 2. Starts a local server with proper CORS/COEP headers
# 3. Opens Chrome to the game
# 4. Waits for you to press Enter, then stops the server

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
EXPORT_DIR="$PROJECT_DIR/export"
GODOT="/Applications/Godot.app/Contents/MacOS/Godot"

# Check if Godot exists
if [ ! -f "$GODOT" ]; then
    echo "Error: Godot not found at $GODOT"
    exit 1
fi

# Re-export the project (debug mode for testing)
echo "Exporting web build..."
"$GODOT" --headless --path "$PROJECT_DIR" --export-debug "Web" "$EXPORT_DIR/Underkingdom.html"

# Start server in background
echo "Starting server..."
cd "$EXPORT_DIR"
python3 serve.py &
SERVER_PID=$!

# Give server time to start
sleep 1

# Open in Chrome
echo "Opening Chrome..."
open -a "Google Chrome" "http://localhost:8000/Underkingdom.html"

echo ""
echo "Game running at http://localhost:8000/Underkingdom.html"
echo "Press Enter to stop server..."
read

# Cleanup
kill $SERVER_PID 2>/dev/null || true
echo "Server stopped."
