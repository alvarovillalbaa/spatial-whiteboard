# Spatial Whiteboard

A native visionOS whiteboard for drawing and diagrams in a spatial window.
Initial source implementation is complete. It has not been compiled or run on a simulator
or device; this is not an installed or distributed application.

## Workflow

Create or open a `.spatialboard` document through the native document browser.
Use Pen, Rectangle, Ellipse, Arrow or Text to add content. Use Select to move an
object, or choose it from the object list. The inspector edits its dimensions,
position, text and style without requiring a precise canvas gesture.

Undo/redo applies to committed board edits. Pan, zoom and fit controls change
the view. Native document saving is coordinated by the system. Native JSON
preserves editable objects and can reopen as this app's own-format JSON; SVG is
a standalone visual export. Other JSON formats, including Excalidraw/tldraw
documents, are not compatible.

The app opens empty, works without an account, and has no server dependency or
model call. It uses ordinary visionOS window input. It does not require ARKit
hand tracking or access to the room.

## Source and checks

Open `SpatialWhiteboard.xcodeproj` in Xcode 16 or newer with a visionOS SDK.
Choose the shared SpatialWhiteboard scheme and an appropriate simulator/device.
Physical device signing and distribution need an owner-selected Apple team;
none is configured. App icons and store assets are not prepared in this source.

The local environment action performs an unsigned generic simulator build; it
does not launch the app. It respects the workspace Storage Guard when present.
Only run native checks after meeting the workspace execution/approval gates:

```sh
./script/check_native.sh core-tests
./script/check_native.sh visionos-simulator
```

BoardCore is a Foundation-only Swift package. Its authored tests are in-memory;
UI, document-provider save/conflict handling, visionOS eye/pinch input and
accessibility need actual platform checks. Syntax parsing alone proves none of
those behaviors. The [native CI proposal](docs/proposals/native-checks.md) stays
inactive until explicit approval.

## Format and limits

Native documents permit up to 500 objects, 10000 points per stroke and 50000
points overall, with a 4 MiB (4,194,304-byte) encoded JSON limit. Unsupported fields/versions,
duplicate JSON keys/IDs, invalid coordinates and oversized content reject the
whole board. A failed load throws through FileDocument; it does not silently
become an empty replacement. The system may materialize file contents before
the codec can enforce its size limit, so this is not a hard pre-read memory cap
for arbitrary external files. Undo/redo retains at most 20 prior states.

See [product scope](docs/specs/product.md), [core contract](docs/specs/core-contract.md),
[architecture](docs/architecture.md), and the [source receipt](docs/results/2026/10-27/initial-source.md).
