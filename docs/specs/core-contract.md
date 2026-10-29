# BoardCore contract

The native app targets visionOS 2. BoardCore is Foundation-only, independently
usable from SwiftPM. This is a new local format, not Excalidraw/tldraw JSON.

## Values

- `BoardPoint(x: Double, y: Double)`; `BoardRect(x:y:width:height:)`.
- `BoardKind`: stroke, rectangle, ellipse, arrow, text.
- `BoardInk`: graphite, teal, blue, orange, rose; stable SVG hex colors.
- `BoardStyle(ink:fill:strokeWidth:fontSize:)`, default initializer available.
- `BoardItem(id:kind:frame:points:text:style:)`. Points are normalized within
  the positive frame, for strokes and arrows. Rectangle/ellipse/text have no
  points. Arrow has exactly two. Stroke has at least two. Only text has text.
- `Board(version:id:title:revision:items:)`, default empty “Untitled Board”.
  Public value initializers; all values Codable, Equatable, Sendable.

Coordinates/edges must be finite within -100000...100000. Frame dimensions
are 1...200000. Stroke width is 1...12, text size 12...96. Native documents are
at most 4 MiB (4,194,304 bytes) UTF-8, at most 500 objects, 10000 points per stroke, 50000 points
total, 1000 characters per text, 80 characters per title (also byte bounded).
Duplicate IDs, unsupported versions, fields, duplicate JSON keys, non-UTF-8 or
state violating any invariant reject the entire document. Revision is a
nonnegative Int with overflow guarded. JSON parsing must bound recursion.

## Editing

`BoardEdit`: add(item), replace(item), delete(id), duplicate(id,newID,offset),
bringToFront(id), sendToBack(id), rename(title).

Atomic multi-object cases are `move(ids:offset:)`, `deleteMany(ids)`,
`duplicateMany(ids:newIDs:offset:)`, `bringToFrontMany(ids)` and
`sendToBackMany(ids)`. Selected-ID arrays must be unique, bounded to 500 and
contain only existing IDs. Duplication requires one unique nonexisting new ID
per selected ID; explicit ID pairs define identity, while appended copies keep
the originals' board order. Front/back actions preserve the relative order of
both selected and unselected objects. Empty/already-applied valid commands are
no-ops; invalid IDs or nonfinite offsets still fail without changing history.

Offsets are finite vectors, not board positions: a valid full-plane move can
exceed 100000 units. All translated frames must still satisfy the existing
coordinate/edge limits. A batch uses one shared offset, never per-object
clamping, and full candidate validation includes object/point/encoded-byte caps.
One successful batch increments revision and adds one history entry.

`BoardHistory(board:)` throws on invalid initial state. Expose board, canUndo,
canRedo. `perform(edit, expectedRevision:)`, `undo(expectedRevision:)` and
`redo(expectedRevision:)` throw on invalid/stale commands. Edits are transactional
and revisions strictly increase including undo/redo; retain at most 20 previous
states across both stacks. No-op edits should not consume history/revision.
Selection/viewport/draft gestures are app state, not saved board mutations.

## Geometry and codec

- `BoardGeometry.shape(id:kind:from:to:style:text:)` makes a normalized item;
  preserve arrow direction when dragging backwards. For text use a frame of at
  least 160 by 80. For rectangle/ellipse/arrow use at least 1 by 1.
- `BoardGeometry.stroke(id:worldPoints:style:)` bounds/normalizes real points.
- `BoardGeometry.hitTest(item, at: point, tolerance: Double)` selects meaningful
  line/stroke proximity and shape/text bounds. Tolerance is finite/nonnegative.
- `BoardGeometry.bounds(of: items)` returns optional union.
- `BoardGeometry.translated(item, by: offset)` validates the original item,
  finite offset and translated item, changing only frame position. IDs, kinds,
  normalized points, text, size and style remain unchanged.
- `BoardCodec.encode(board)` / `decode(data)` enforce the full contract before
  returning. Native UTF-8 JSON, optional UTF-8 BOM, duplicate-key protection,
  strict allowed-key schema; no Foundation UTF-16/32 autodetection.
- `BoardSVG.encode(board)` exports validated standalone UTF-8 SVG, escapes text,
  includes all object types with fitting viewBox and matches native colors.

Native file coordination is owned by FileDocument/DocumentGroup. A failed
decode must throw; unread source bytes must never become an empty board save.
FileDocument assignments automatically register native undo. The app uses that
document UndoManager as its sole undo authority, with a 20-level limit; it does
not install a competing BoardHistory undo stack. BoardHistory remains a pure
transaction/history API and can validate a single app edit from a fresh board.
Native undo can restore a previous saved revision, so the app must additionally
fence drafts/forms with a transient document-change generation. External/native
document changes cancel stale drafts without assigning a new normalized board
or registering another edit.

The app additionally binds batch actions to the exact active selection. Gesture
drafts capture IDs, original items, viewport and document stamp. Selection/tool/
mode/viewport/editability/document changes revoke the draft. A latched
four-screen-point threshold distinguishes selection taps from group dragging;
returning a drag to its origin cannot toggle membership or consume history.
An empty-canvas drag moves nothing. Preview replacements retain board z-order.
The native Move Selection form freezes its ordered IDs/bounds/stamp and rejects
stale membership before the core transaction. These transient fields do not
enter Codable records, native JSON or SVG export.
