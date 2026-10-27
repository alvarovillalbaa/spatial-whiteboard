#!/usr/bin/env bash
set -euo pipefail

SPATIAL_MODE="${1:-visionos-simulator}"
case "$SPATIAL_MODE" in
  visionos-simulator|core-tests) ;;
  --help) echo "usage: $0 [visionos-simulator|core-tests] (checks/build only; never launches an app)"; exit 0 ;;
  *) echo "usage: $0 [visionos-simulator|core-tests]" >&2; exit 2 ;;
esac
SPATIAL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SPATIAL_ROOT"
if [[ -f "$HOME/.codex/storage-policy.md" ]]; then
  SPATIAL_GUARD="$HOME/Library/Application Support/LocalStorageGuard/storage_guard.py"
  [[ -f "$SPATIAL_GUARD" ]] || { echo "The workspace Storage Guard is unavailable." >&2; exit 1; }
  SPATIAL_NEED=8
  [[ "$SPATIAL_MODE" == core-tests ]] && SPATIAL_NEED=4
  python3 "$SPATIAL_GUARD" preflight --need-gib "$SPATIAL_NEED"
fi
case "$SPATIAL_MODE" in
  core-tests) swift test ;;
  visionos-simulator)
    xcodebuild -project SpatialWhiteboard.xcodeproj -scheme SpatialWhiteboard \
      -configuration Debug -sdk xrsimulator \
      -destination 'generic/platform=visionOS Simulator' \
      -derivedDataPath "$SPATIAL_ROOT/DerivedData" \
      CODE_SIGNING_ALLOWED=NO build
    ;;
esac
