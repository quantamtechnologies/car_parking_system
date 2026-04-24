#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
FLUTTER_HOME="${FLUTTER_HOME:-$HOME/flutter}"

cd "$PROJECT_ROOT"

API_BASE_URL="${API_BASE_URL:-}"

if [ -z "$API_BASE_URL" ]; then
  echo "WARNING: API_BASE_URL is not set. The deployed app will show the missing API warning screen."
fi

if ! command -v flutter >/dev/null 2>&1; then
  if [ ! -x "$FLUTTER_HOME/bin/flutter" ]; then
    echo "Flutter CLI not found. Installing the stable SDK..."
    git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$FLUTTER_HOME"
  fi

  export PATH="$FLUTTER_HOME/bin:$PATH"
fi

flutter --version
flutter config --enable-web
flutter clean
flutter pub get
build_args=(build web --release --pwa-strategy=none)
if [ -n "$API_BASE_URL" ]; then
  build_args+=("--dart-define=API_BASE_URL=$API_BASE_URL")
fi
flutter "${build_args[@]}"
