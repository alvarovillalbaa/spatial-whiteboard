# Initial native source receipt

27 October 2026. Status: source implementation published, native checks pending. This work does not complete
the owning all-project goal.

## Intent and isolation

The [parent page](https://app.notion.com/p/311a1ee8bd06805caa21c5306dd315ac)
contains “(glassOS) whiteboard”. Alvaro's clarification in the active conversation
specifies visionOS, a new whiteboard and “TL;DW and Excalidraw” as references.
The exact “TL;DW” reference remains unresolved. A workspace whiteboard search
also returned unrelated Clous documents; those were not adopted as this app's
brief. The parent fetch is truncated with three unknown blocks elsewhere, so
no complete all-project inventory is claimed.

The local destination did not exist and connected GitHub read returned 404 for
`alvarovillalbaa/spatial-whiteboard`. A separate `main` repo was initialized.
No existing app checkout was changed for this implementation.

## Verification boundary

Storage Guard preflight for an 8 GiB estimated build reported **20.1 GiB free /
38.0 GiB required**, exit 2. `xcode-select -p` reports Command Line Tools.
Native build/tests, simulator/device launch, document open/save, gestures,
accessibility, signing and store submission have not run. No dependencies,
remote backend, model calls, payments or new accounts are involved.

The [native-check proposal](../../../proposals/native-checks.md) and adjacent
workflow example remain inactive pending explicit approval. This is not a
distributed application.

## Source checks

All **28 Swift files** passed individual `swiftc -frontend -parse` checks, with
no type-checking or compilation claim. The seven Foundation core sources have
**53 authored XCTest cases** across four test/fixture files; those tests remain
unrun. Independent review covered core validation/codec/history/geometry/SVG,
all 16 app files, document/undo/input/export boundaries, metadata and proposal.

All 16 app files appear exactly once in the Xcode Sources phase; the local
BoardCore package, shared scheme target, privacy resource and Info.plist setting
agree. The scheme has no test targets: proposed core tests use SwiftPM. Property
list, shell, TOML and inactive YAML checks passed, including the workflow's four
shell blocks. All 44 owned text files passed newline/trailing-whitespace and
local-path checks; six local Markdown links resolve. `git diff --check` passed.
No active workflow is installed.

Frozen SHA256 fingerprints over sorted relative Swift paths, NUL, bytes, NUL:

- Core and tests: `ae1d5dc53fe0a6a1d413ea289bb98b763016057ce94f147980eb981f2965f4ca`.
- App: `06fc45d0583e19cbdd4414800aa8106a882f93c71f3e39236890d4e27b0df757`.

Review corrected native scene metadata, the final revised candidate's byte-cap
check, renderer API visibility, native undo generation, gesture cancellation
and export snapshot teardown. These are source-reviewed contracts, not observed
visionOS behavior.

## Publication

Source commit
[`9ed03dae153d73b8b4ffd75b3b1705d8210d1838`](https://github.com/alvarovillalbaa/spatial-whiteboard/tree/9ed03dae153d73b8b4ffd75b3b1705d8210d1838)
was pushed to the new public personal repository
`alvarovillalbaa/spatial-whiteboard`. Authenticated CLI identity was verified
before creation. Connected GitHub metadata confirms personal ownership, public
visibility and the `main` default branch. The API branch SHA matches local HEAD.

Immutable connected file readback matches local Git blobs for BoardEditor
(`8710e5a2bb1cb020e4b1257839ca67ae103bd78a`), BoardHistory
(`d7873cf9c2c05b6070416068107c0ee20a4a96f3`) and the native-check proposal
(`7c05114a1611fc0b53744ae31bb4ddd2ca0c2510`). This establishes source
publication; native platform behavior and distribution remain unverified.
