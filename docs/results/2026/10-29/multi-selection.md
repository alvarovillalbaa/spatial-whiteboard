# Multi-selection and atomic editing source

29 October 2026. **Implemented and statically reviewed; native checks unrun.**
The starting source was `471e9a91140718def9976f8bb3883d5c03316968`.
The owning all-project request authorizes personal GitHub source publication.
This increment does not complete the app or the portfolio goal.

Select multiple objects through native controls, the object list or canvas
taps. Drag a selected member to move the cohort, or use the inspector's native
position form. Duplicate, delete, front and back actions apply atomically.
Each committed batch produces one document assignment for native undo.
Membership and drafts remain transient; no persistent groups or format changes
were introduced. The TL;DW reference remains unresolved; this increment covers
the clear drawing/diagramming brief only.

BoardCore adds five bounded batch commands and a shared translation helper.
Commands reject unknown/repeated IDs, stale revisions and invalid candidates
without partial edits. Duplicate mappings and front/back partitions retain board
order. Offsets are finite vectors; destination frames retain the existing
coordinate, object, point and encoded-byte limits.

The ten edited app files cover editor state/tool/gesture, editor sheet routing,
canvas/rendering, toolbar/list/inspector and the native position form. Forms
capture exact membership and document stamps. Drafts latch a four-screen-point
drag threshold and cancel on document, selection, mode, viewport, tool or
editability changes. Read-only selection cannot commit content. Review caught
and corrected a preview ordering issue: moving previews now replace originals
at their existing z-order rather than appearing above unrelated objects.

Prepared checks comprise 53 unchanged core regressions, sixteen new batch cases
and sixteen app-less cases using actual editor-state/gesture source: **85 total,
all unrun**. The [inventory](multi-selection-inventory.json) records every unique
case name and the complete source file set with byte counts and SHA-256s.
The [proposal](../../../proposals/multi-selection-checks.md) and inactive workflow
describe one temporary public macOS job and an unsigned visionOS target build.
No active workflow has been installed or dispatched for this scope.

Static verification passed: Swift 6.3.3 parsed all 29 app/core/test Swift files
without diagnostics; both shell helpers passed bash syntax checking; two
property lists and Xcode project metadata passed plutil; the inactive workflow
parsed with the installed Ruby Psych, and its nine shell blocks and three
embedded Python blocks passed syntax-only checks. Git whitespace checks passed.
No installation was needed; Python's optional YAML module was absent, so the
system YAML parser was used. These checks perform no type checking or execution.

Models, validation, codec, SVG encoding, document integration, package/project
settings, privacy manifest, icon assets, original test files and old pending
native proposal/helper were preserved. No dependency, account, backend,
permission, entitlement, signing or paid-service change occurred.

The latest local Storage Guard preflight reported 29.3 GiB available against
38.0 GiB required; Command Line Tools is selected. No native tests/build,
simulator boot, app launch, user document access or tracking input ran.
Type/API compatibility, native UndoManager, save/reopen/conflicts, actual input,
rendering/accessibility and device/distribution remain unverified. Source
parsing and authored fixtures cannot establish those outcomes.

Source and the complete proposed check scope were published at
[`31fa91e61ff562e18dcdb2bbba7f5b8c1dcc7a99`](https://github.com/alvarovillalbaa/spatial-whiteboard/commit/31fa91e61ff562e18dcdb2bbba7f5b8c1dcc7a99).
Connected GitHub readback matched all 68 leaf paths, modes, types and blob SHAs
against the local tree, without truncation; the checkout was clean and the
commit had zero Actions runs. The [publication receipt](multi-selection-publication.json)
preserves those identities and static proof limits. One approval request links
the exact published 85-case/build proposal. It remains pending; no active
workflow was installed. This evidence-only follow-up changes no sealed source.
