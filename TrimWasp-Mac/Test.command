#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
TRIMWASP_TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TRIMWASP_TEST_DIR"' EXIT
xcrun swiftc -swift-version 5 Sources/MediaIndex.swift Sources/MediaDetails.swift Sources/PlaybackSettings.swift Sources/MarkerSelection.swift Sources/ThemeModel.swift Sources/TimelineLanes.swift Tests/main.swift -o "$TRIMWASP_TEST_DIR/MediaIndexTests"
"$TRIMWASP_TEST_DIR/MediaIndexTests"
