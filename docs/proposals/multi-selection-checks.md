# Multi-selection native checks, pending approval

29 October 2026. **Prepared source only; none of these checks has run.**
This is a separate scope from the older pending native/icon proposal.
The [source receipt](../results/2026/10-29/multi-selection.md) and
[inventory](../results/2026/10-29/multi-selection-inventory.json) identify the
authored source and exact case names.

## Proposed execution

After explicit approval under the supplied AGENTS.md sections 7 and 14, install
the [inactive workflow](../examples/multi-selection-checks.workflow.yml)
temporarily in this public repository. Dispatch it against the exact published
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

Local native execution remains blocked: the latest preflight reported
29.3 GiB free against 38.0 GiB required, and the selected developer directory is
Command Line Tools. No local build, tests or simulator action bypasses that
boundary. Even a successful proposed job leaves actual save/reopen/conflicts,
visionOS input, visual/accessibility acceptance and device/distribution open.
