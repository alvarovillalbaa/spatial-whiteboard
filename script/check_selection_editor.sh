#!/usr/bin/env bash
set -euo pipefail

# This source is an inactive, approval-gated native check; never a local storage bypass.
[[ "${CI:-}" == true && "${GITHUB_ACTIONS:-}" == true && "${RUNNER_OS:-}" == macOS ]] || {
  echo "Editor checks require the explicitly approved macOS GitHub CI job." >&2
  exit 2
}
[[ "$(uname -s)" == Darwin && -n "${RUNNER_TEMP:-}" && -d "$RUNNER_TEMP" && ! -L "$RUNNER_TEMP" ]] || {
  echo "A native macOS runner and its regular temporary directory are required." >&2
  exit 2
}

SPATIAL_EDITOR_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SPATIAL_EDITOR_BASE="$(cd "$RUNNER_TEMP" && pwd -P)"
[[ "$SPATIAL_EDITOR_BASE" == "$RUNNER_TEMP" ]] || {
  echo "RUNNER_TEMP must identify its canonical directory." >&2
  exit 2
}
SPATIAL_EDITOR_ARCH="$(uname -m)"
case "$SPATIAL_EDITOR_ARCH" in arm64|x86_64) ;; *) echo "Unsupported native runner architecture." >&2; exit 2 ;; esac
SPATIAL_EDITOR_OS="$(sw_vers -productVersion)"
SPATIAL_EDITOR_MAJOR="${SPATIAL_EDITOR_OS%%.*}"
[[ "$SPATIAL_EDITOR_MAJOR" =~ ^[0-9]+$ && "$SPATIAL_EDITOR_MAJOR" -ge 15 ]] || {
  echo "The app-less fixture requires macOS 15 or newer." >&2
  exit 2
}
SPATIAL_EDITOR_SDK="$(xcrun --sdk macosx --show-sdk-path)"
[[ -d "$SPATIAL_EDITOR_SDK" ]] || { echo "The installed macOS SDK is unavailable." >&2; exit 2; }
SPATIAL_EDITOR_TARGET="$SPATIAL_EDITOR_ARCH-apple-macosx15.0"
SPATIAL_EDITOR_TMP="$(mktemp -d "$SPATIAL_EDITOR_BASE/spatial-editor-checks.XXXXXX")"
SPATIAL_EDITOR_IDENTITY="$(stat -f '%d:%i' "$SPATIAL_EDITOR_TMP")"

spatial_editor_cleanup() {
  local spatial_editor_status=$?
  trap - EXIT HUP INT TERM
  if [[ -e "$SPATIAL_EDITOR_TMP" ]]; then
    if [[ -d "$SPATIAL_EDITOR_TMP" && ! -L "$SPATIAL_EDITOR_TMP" \
          && "${SPATIAL_EDITOR_TMP%/*}" == "$SPATIAL_EDITOR_BASE" \
          && "${SPATIAL_EDITOR_TMP##*/}" == spatial-editor-checks.* \
          && "$(stat -f '%d:%i' "$SPATIAL_EDITOR_TMP")" == "$SPATIAL_EDITOR_IDENTITY" ]]; then
      rm -rf -- "$SPATIAL_EDITOR_TMP"
    else
      echo "Editor-check temporary ownership changed; cleanup was refused." >&2
      spatial_editor_status=1
    fi
  fi
  exit "$spatial_editor_status"
}
trap spatial_editor_cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

cd "$SPATIAL_EDITOR_ROOT"
SPATIAL_EDITOR_SOURCES=(
  App/SpatialWhiteboard/Editor/EditorState.swift
  App/SpatialWhiteboard/Editor/EditorTool.swift
  App/SpatialWhiteboard/Editor/CanvasGesture.swift
  App/SpatialWhiteboard/Editor/Viewport.swift
  App/SpatialWhiteboard/Support/BoardPresentation.swift
)
printf 'Editor checks: macOS %s, native %s, Swift language 5, installed SDK %s\n' \
  "$SPATIAL_EDITOR_OS" "$SPATIAL_EDITOR_ARCH" "$SPATIAL_EDITOR_SDK" >&2
xcrun --sdk macosx swiftc --version >&2
xcrun --sdk macosx swiftc -swift-version 5 -sdk "$SPATIAL_EDITOR_SDK" \
  -target "$SPATIAL_EDITOR_TARGET" -parse-as-library -module-name BoardCore \
  -module-cache-path "$SPATIAL_EDITOR_TMP/module-cache" \
  -emit-module -emit-module-path "$SPATIAL_EDITOR_TMP/BoardCore.swiftmodule" \
  -emit-library -static Sources/BoardCore/*.swift -o "$SPATIAL_EDITOR_TMP/libBoardCore.a"
xcrun --sdk macosx swiftc -swift-version 5 -sdk "$SPATIAL_EDITOR_SDK" \
  -target "$SPATIAL_EDITOR_TARGET" -parse-as-library \
  -module-cache-path "$SPATIAL_EDITOR_TMP/module-cache" \
  -I "$SPATIAL_EDITOR_TMP" -L "$SPATIAL_EDITOR_TMP" -lBoardCore -framework SwiftUI \
  "${SPATIAL_EDITOR_SOURCES[@]}" Tests/EditorChecks/MultiSelectionChecks.swift \
  -o "$SPATIAL_EDITOR_TMP/editor-checks"
"$SPATIAL_EDITOR_TMP/editor-checks"
