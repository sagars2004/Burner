#!/bin/bash
# Burner — macOS Menu Bar Agent Launcher
# Starts the local Python reasoning engine and launches the native Swift Menu Bar app.

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_DIR="$PROJECT_ROOT/server"
APP_PATH="/Users/sagarsahu/Library/Developer/Xcode/DerivedData/Burner-addkgpqgfzdupggnkqnkmfdmstoq/Build/Products/Debug/Burner.app"

echo "===================================================="
echo "🔥 Starting Burner — AI Quota Menu Bar Agent"
echo "===================================================="

# 1. Ensure Python Virtual Environment exists
if [ ! -d "$SERVER_DIR/venv" ]; then
    echo "📦 Creating Python virtual environment..."
    python3 -m venv "$SERVER_DIR/venv"
    "$SERVER_DIR/venv/bin/pip" install -r "$SERVER_DIR/requirements.txt"
fi

# 2. Kill any stale backend on port 8000 or old Burner instances
echo "🧹 Checking for existing processes..."
lsof -ti:8000 | xargs kill -9 2>/dev/null || true
pkill -f "Burner.app/Contents/MacOS/Burner" 2>/dev/null || true

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
    sleep 0.5
done

# 4. Launch the Native macOS Menu Bar App
if [ -d "$APP_PATH" ]; then
    echo "🚀 Launching Burner Menu Bar App..."
    open "$APP_PATH"
else
    echo "🔨 Building BurnerApp..."
    xcodebuild -project "$PROJECT_ROOT/BurnerApp/Burner.xcodeproj" -scheme Burner build -quiet
    open "$APP_PATH"
fi

echo ""
echo "🔥 Burner is now running in your macOS menu bar!"
echo "• Look for the flame (🔥) icon near your clock/battery."
echo "• Click the icon to view your 5 connected AI quotas & agent recommendations."
echo "• Backend PID: $SERVER_PID (run 'pkill -f Burner' to stop)"
echo "===================================================="
