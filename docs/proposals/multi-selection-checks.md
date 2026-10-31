# Multi-selection native checks

Revised 31 October 2026. The owner's current blanket approval and instruction
to keep going authorize this prepared packet and its temporary CI. Historical
29 October pending/unrun receipts describe the earlier checkpoint.
The [first attempt and diagnostic](../results/2026/10-31/multi-selection-checks-attempt1.md)
record a failed unsigned build, sixteen verified editor cases and missing core
xUnit output. The [repaired inventory](../results/2026/10-31/multi-selection-repaired-inventory.json)
seals the corrected source and the same exact 85 case names; it does not replace
the historical 29 October inventory.

## Proposed execution

Install the [inactive workflow](../examples/multi-selection-checks.workflow.yml)
temporarily in this public repository under that approval. Run it against the exact published
40-character source commit, using one standard public macos-15 job capped at
20 minutes, contents-read permission and no retained checkout credentials.
No larger/paid runner is proposed.

The job first compares the complete tracked source file set, sizes and SHA-256
hashes against the inventory. Dated docs/results/ receipts are excluded from
that source inventory to avoid self-reference; runtime, tests, scripts, project
metadata, proposal and inactive workflow are included. It records the commit,
OS, Swift/Xcode versions and installed SDKs. A missing visionOS Simulator SDK
fails visibly; no SDK installation or developer-directory change is included.

| Scope | Cases | Execution |
| --- | ---: | --- |
| Existing BoardCore regressions | 53 | Existing SwiftPM test target |
| New atomic batch editing | 16 | Same target, authored in-memory boards |
| Actual editor-state/gesture snapshots | 16 | App-less macOS fixture compiling actual selected app files |
| **Total** | **85** | Exact unique names checked against inventory |

The editor fixture exercises selection, stale forms, batch commands, external
changes, transient history generations, captured gesture state and read-only
commit guards. It compiles the actual EditorState, EditorTool, CanvasGesture,
Viewport and BoardPresentation source. Its manually captured drafts cannot
prove physical gesture delivery, SwiftUI rendering, native UndoManager
integration, document saving or visionOS accessibility.

The repaired core command uses `swift test --parallel --num-workers 1` with the
same target and cases. [SwiftPM 6.1.2's XCTest reporter](https://github.com/swiftlang/swift-package-manager/blob/swift-6.1.2-RELEASE/Sources/Commands/SwiftTestCommand.swift#L284)
generates xUnit output through that runner; one worker keeps execution serial.
The renderer repair explicitly types `CGSize`'s maximum proposal as `CGFloat`,
resolving the actual visionOS compilation error without changing its value.

The same job builds the existing app target unsigned:

~~~sh
xcodebuild -project SpatialWhiteboard.xcodeproj -scheme SpatialWhiteboard \
  -configuration Debug -sdk xrsimulator \
  -destination 'generic/platform=visionOS Simulator' \
  -derivedDataPath "$SPATIAL_CHECK_DIR/derived" CODE_SIGNING_ALLOWED=NO build
~~~

No simulator boot, app window, UI automation, document provider, real user file,
eye/hand input, tracking permission, signing identity/team, store submission,
dependency installation/change, provider/model call, account or paid enrollment
is included. The app's existing icon catalog is part of the unsigned target.

## Results and cleanup

The workflow checks shell/property-list/project metadata and whitespace, runs
69 core cases with xUnit output, runs the sixteen editor cases with structured
JSON, then builds the target. All stages must succeed. It rechecks source
hashes, exact names and zero failure/error/skip counts before reporting success.
It preserves failures; an unrun or skipped stage cannot be called a pass.
After all checks pass, the verified JSON report is also printed to stdout,
capped at 16 KiB. On failure, a separate optional diagnostic prints at most
16 KiB of build errors/tail, so retrieving a ZIP is not required to see the
compiler error. These are explicit controller changes from the first attempt;
checkout also uses the same `SOURCE_COMMIT` as the HEAD guard. The unsigned
build, case assertions, source guards and cleanup remain required.

Only explicit text logs, XML, JSON and an artifact manifest are uploaded, with
seven-day retention. Each is capped at 1 MiB; an oversized file is truncated,
its original size recorded and the job fails. Build products are not uploaded.
An always-run step removes only the job-owned SwiftPM/build directories after
checking their temporary root and device/inode identity. The editor helper
likewise cleans its own marked temporary compilation directory.

After a terminal result, record the actual source/toolchain, case names,
exit statuses, artifact digests and limits in owning dated results. Remove the
temporary active workflow, including after failures. A bounded source repair
may rerun these same approved cases with updated source hashes and a preserved
failure receipt; additional cases, runner scope or execution need new approval.
Hard runner termination can prevent cleanup or artifact upload and must remain
an explicit incomplete result.

Local native execution remains blocked by the workspace Storage Guard; the
selected developer directory is Command Line Tools. No local build, tests or simulator action bypasses that
boundary. Even a successful proposed job leaves actual save/reopen/conflicts,
visionOS input, visual/accessibility acceptance and device/distribution open.
