#!/bin/bash
# Burner — macOS Menu Bar Agent Launcher
# Cleanly restarts backend & frontend and recompiles any updated Swift/Python code automatically.

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_DIR="$PROJECT_ROOT/server"
APP_PATH="/Users/sagarsahu/Library/Developer/Xcode/DerivedData/Burner-addkgpqgfzdupggnkqnkmfdmstoq/Build/Products/Debug/Burner.app"

echo "===================================================="
echo "🔥 Starting Burner — AI Quota Menu Bar Agent"
echo "===================================================="

# 1. Clean up any existing instances (so you never need to run pkill manually!)
echo "🧹 Cleaning up existing processes..."
lsof -ti:8000 | xargs kill -9 2>/dev/null || true
pkill -f "Burner.app/Contents/MacOS/Burner" 2>/dev/null || true
sleep 0.5

# Load .env variables if present
if [ -f "$PROJECT_ROOT/.env" ]; then
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
fi

# 2. Ensure Python Virtual Environment exists
if [ ! -d "$SERVER_DIR/venv" ]; then
    echo "📦 Creating Python virtual environment..."
    python3 -m venv "$SERVER_DIR/venv"
    "$SERVER_DIR/venv/bin/pip" install -r "$SERVER_DIR/requirements.txt"
fi

# 3. Start the FastAPI local agent engine
echo "🧠 Starting local agent backend on http://127.0.0.1:8000..."
cd "$PROJECT_ROOT"
PYTHONPATH="$PROJECT_ROOT" "$SERVER_DIR/venv/bin/python3" -m uvicorn server.main:app --port 8000 --log-level warning &
SERVER_PID=$!

# Wait for server to become healthy
echo "⏳ Waiting for agent backend to initialize..."
for i in {1..15}; do
    if curl -s http://127.0.0.1:8000/health > /dev/null; then
        echo "✅ Agent backend is healthy!"
        break
    fi
    sleep 0.4
done

# 4. Fast incremental build of Swift Menu Bar App (picks up all Swift changes automatically)
echo "🔨 Compiling latest Swift changes..."
xcodebuild -project "$PROJECT_ROOT/BurnerApp/Burner.xcodeproj" -scheme Burner build -destination 'platform=macOS' -quiet 2>/dev/null || xcodebuild -project "$PROJECT_ROOT/BurnerApp/Burner.xcodeproj" -scheme Burner build -quiet

# 5. Launch the Native macOS Menu Bar App
echo "🚀 Launching Burner Menu Bar App..."
open "$APP_PATH"

echo ""
echo "🔥 Burner is now running in your macOS menu bar!"
echo "• Look for the flame (🔥) icon near your clock/battery."
echo "• Click the icon to view your 5 connected AI quotas & agent recommendations."
echo "• Backend PID: $SERVER_PID"
echo "===================================================="
