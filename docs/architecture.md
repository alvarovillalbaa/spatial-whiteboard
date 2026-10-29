# Native board architecture

The app uses SwiftUI's existing `FileDocument` and `DocumentGroup` APIs with a
visionOS 2 deployment target. Each file owns a BoardCore value. FileDocument
reads through the strict codec and throws on failure, and writes only validated
encoded boards through the system's coordinated document pipeline. There is no
separate hidden autosave file or hosted backend. The system may materialize an
external file before the codec's 4 MiB logical limit can reject it.

The editor keeps transient selection, tool, viewport and gesture previews
outside the saved board. Each committed edit validates against the current
revision and assigns the resulting board to the document binding. That binding
registers native undo automatically; the app uses the document's UndoManager
with a 20-level limit. Core history is not a competing app undo stack. Native
undo restores the saved revision along with content, so a separate transient
generation cancels stale drafts/forms on every document change. External/native
changes are not replayed as new edits.

Selection is now a transient set of existing IDs, presented in board order.
Batch move/duplicate/delete/front/back actions use one BoardHistory validation
and one document binding assignment. The native position sheet freezes its
cohort, bounds and document stamp; commands also verify current membership.
Canvas drafts capture originals, IDs, viewport and stamp, latch the drag
threshold and share the core translation helper. Rendering substitutes moving
previews in their original z-order rather than lifting them above unrelated
objects. Read-only mode permits selection while preventing content commits.

Strokes and arrows use normalized points within positive frames; moving or
resizing changes the frame. Screen and world transforms are shared by input,
rendering and hit testing. The board plane has bounded world coordinates;
pan/zoom exposes more of that plane without promising unlimited memory.

Canvas draws the visual surface. Native buttons, an object list and inspector
provide individual accessible controls because Canvas primitives do not supply
their own accessibility or interactions. Standard window gestures require no
hand-tracking authorization. Precise native input and accessibility remain
runtime acceptance checks, not conclusions from source review.

Primary platform references inspected during implementation:

- [DocumentGroup](https://developer.apple.com/documentation/swiftui/documentgroup)
  and [visionOS scene presentation](https://developer.apple.com/documentation/visionos/presenting-windows-and-spaces)
  support a native document scene. This source does not use the newer visionOS 27
  `Document` protocol.
- [The document binding](https://developer.apple.com/documentation/swiftui/filedocumentconfiguration/document)
  registers automatic undo on assignment; app controls call the same manager.
- [Canvas](https://developer.apple.com/documentation/swiftui/canvas) describes the
  immediate-mode drawing surface; editor controls remain ordinary SwiftUI views.
- [Build settings](https://developer.apple.com/documentation/xcode/build-settings-reference)
  and [Swift platform definitions](https://github.com/swiftlang/swift/blob/main/lib/Basic/Platform.cpp)
  identify the visionOS family and device/simulator platform names.

The privacy manifest describes this source's lack of tracking, collected data
or direct required-reason API calls. It is not a completed App Store privacy
review. Distribution assets, signing ownership and native acceptance evidence
remain separate work.
