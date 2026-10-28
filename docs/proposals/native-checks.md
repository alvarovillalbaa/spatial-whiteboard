# Focused native checks, inactive proposal

The source can be reviewed independently of native execution. Storage Guard
reported 20.1 GiB free against 38.0 GiB required for the estimated native build;
the selected local developer directory is Command Line Tools. No local build,
test, simulator boot or application launch has been performed.

The workflow example beside this file is deliberately outside
`.github/workflows`. AGENTS.md section 14 requires explicit approval before
installing or running it. Source publication is already within the owning
all-project task; it does not imply CI approval.

The [runner image inventory](https://github.com/actions/runner-images/blob/macos-15-arm64/20260907.0337/images/macos/macos-15-arm64-Readme.md)
for image `20260907.0337.1` lists Xcode 16.4 as default and the visionOS 2.5
Simulator SDK. This supports the proposed runner choice; it does not establish
which image a future dispatch receives or prove the app builds.

## Exact proposed execution

- One standard public `macos-15` runner, capped at 20 minutes, contents-read
  permission, no checkout credentials retained.
- Record the exact commit, OS, Swift/Xcode versions, available SDKs and the
  visionOS Simulator SDK path. Missing SDKs fail visibly; no SDK download or
  developer-directory change is included.
- Check helper shell syntax, property lists, project metadata and whitespace.
- Run authored, in-memory BoardCore SwiftPM tests, then build the generic
  visionOS Simulator target unsigned with `CODE_SIGNING_ALLOWED=NO`.
- No simulator boot, UI automation, app launch, document-provider access,
  real user files, eye/hand input, Apple team, signing, store submission,
  dependency installation, model call or billing change. No artifacts/cache.

After approval, install the exact example temporarily, publish and dispatch
once, inspect terminal results, persist the receipt, and remove the active
workflow even if a check fails. Compilation can expose issues needing source
fixes; any changed scope must remain within this proposal or be approved anew.

These checks establish only the results actually observed. Even a successful
build and core tests would leave document save/reopen/conflicts, visionOS input,
visual rendering, accessibility and device/distribution behavior unverified.

## Later source assets

The [28 October icon source](../results/2026/10-28/app-icon.md) adds a layered
visionOS asset catalog to the same target. The proposed unsigned target build
will include that catalog if the pending check is approved against current
source. Core/app code, native helper and inactive workflow steps are unchanged;
no new job or dispatch has been authorized or executed by this asset addition.
