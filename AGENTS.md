# Spatial Whiteboard

- Native visionOS whiteboard. Read docs/specs/product.md and docs/specs/core-contract.md before changing behavior.
- BoardCore owns validated value models, geometry, editing/history and the bounded native JSON codec. App owns SwiftUI input/rendering, accessibility and system document integration.
- A draft gesture must not enter undo history or persistence until committed. Hit testing and rendering must share the same board coordinates.
- Reject invalid or oversized documents as a whole. Never silently filter objects, accept duplicate IDs/JSON keys or overwrite unread documents.
- Use native controls for actions and a selectable object list; Canvas alone does not expose individual objects to accessibility.
- No accounts, remote services, telemetry, ARKit/hand tracking, paid dependency or model call is required. Standard window gestures do not authorize adding a tracking permission.
- Source publication is authorized by the owning all-project task. Native builds/tests respect Storage Guard; CI, simulator/device execution and distribution need their relevant workspace approval gates.
- Manual edits use apply_patch. Run git diff --check and narrow syntax/static checks. Parsing does not prove type checking, runtime interactions, persistence or platform behavior.
