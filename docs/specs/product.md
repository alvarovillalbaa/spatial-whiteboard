# Product scope

The [source brief](https://app.notion.com/p/311a1ee8bd06805caa21c5306dd315ac)
lists “(glassOS) whiteboard”. On 27 October 2026, Alvaro clarified visionOS and
a new whiteboard where users can do things like “TL;DW and Excalidraw”. The exact
“TL;DW” reference is unresolved; freeform drawing and diagramming are the clear
shared intent. This is a separate native app, working name Spatial Whiteboard.

The initial implementation uses a native visionOS 2 window with local editable
board documents. Users can draw strokes, rectangles, ellipses, arrows and text;
select, move, resize, duplicate, reorder and delete objects; undo/redo; navigate
the canvas; and export a board. A native object list and inspector provide
alternatives to precise gestures. Boards start empty; no fake generated content.

Multi-selection now lets users select several objects using an explicit mode,
native object-list controls and Select All/Clear. Selected members move with one
shared offset, and duplicate/delete/front/back actions apply atomically to the
whole selection. The aggregate inspector includes a native position form;
single-object text, size and style editing stays available. Each batch action
is one committed board edit and one native document assignment. Selection is
transient, without persistent grouping or any file-format addition. This is
source implementation; its dedicated native execution proposal is unrun.

This first version is a 2D board in a spatial window. Room anchoring, immersive
3D objects, multiplayer, third-party Excalidraw/tldraw document compatibility,
AI generation and video summarization are separate scope, not implemented
features. No server or Vercel/Supabase deployment is needed. Native compilation,
device input and distribution require their own evidence.
