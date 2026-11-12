# Native visionOS simulator launch and frame inspection

The standing all-project approval authorizes one separate public macos-15 arm64
job, capped at20minutes, with contents-read permission. Publish this scope and
`script/check_simulator_launch.py` before activating the owned QA branch. Pin
checkout to the exact source commit and preserve all app/core/project/resource
bytes from main688106a9. Do not replay the closed85checks.

The T1 scope builds the unchanged unsigned visionOS Simulator app with the
installed Xcode16.4 SDK, chooses an already-installed available visionOS2
runtime and creates one randomly named, initially absent Apple Vision Pro
simulator. No runtime, SDK, dependency, account or signing/team installation is
authorized. Runner admission requires12GiB free; local Storage Guard failed at
0.2GiB free/38GiB required, so no local build or simulator is used.

Boot only the new exact device, install the exact app, launch its real bundle,
verify the reported PID belongs to that installed binary in three observations
and capture one native simulator PNG. An emitted PNG is **unreviewed**, not UI
acceptance. Recover the original PNG, inspect its actual content, and report
whether it shows the app/document browser or an environment/error screen.
Preserve every failed command, stream and screenshot. A successful launch is
separate from a rendered-editor or editing/persistence claim.

The controller owns a900second work budget and bounded child timeouts; reserve
cleanup within the20minute job. It records every child exit and complete bounded
stdout/stderr, exact runtime/device metadata, source blobs/modes, app binary and
PNG digests. Streams are at most1MiB each and PNG4MiB. JSON/gzip-base64 originals
and PNG bytes are printed with unambiguous markers in the original job log;
bounded text/PNG copies may also be retained as a two-day artifact. Hard runner
termination can prevent cleanup and must remain an unproved outcome.

Terminate/uninstall only this app on its owned simulator, shut down and delete
only that exact device after name/runtime/preabsence checks, verify its ID and
device directory are absent, recheck every tracked input, reap owned child
groups and remove only the new build/cache/package/tmp root. Never use global
simulator shutdown/delete, remove runtimes or touch other devices. Preserve
unknown creation outcomes and failed cleanup; do not infer host-wide absence.

After terminal evidence, disable the temporary workflow and retire its exact
QA ref. No active workflow belongs on main. No source behavior change, app
release, store submission, paid service, provider/model call or real document
is part of this invocation.

[Apple XCUIAutomation](https://developer.apple.com/documentation/xcuiautomation)
does not support apps built with the visionOS SDK. Apple's
[simulator interaction guide](https://developer.apple.com/documentation/xcode/interacting-with-your-visionos-app-in-device-hub)
describes pointer/keyboard gestures; its
[capture guide](https://developer.apple.com/documentation/xcode/capturing-screenshots-and-videos-from-devices)
describes native captures. This job does not substitute app-less editor calls
or an iOS compatibility target for visionOS interaction. Drawing, selection,
undo, file export/save/reopen/conflicts, accessibility, physical eye/pinch input
and distribution remain explicit acceptance work after this launch boundary.

## Changed continuation: target only the owned device after boot

[Attempt1](../results/2026/11-12/simulator-launch-attempt-1.md) compiled and
created/booted its exact device, then the all-device inventory query timed out.
Its repeated inventory guard prevented native teardown; device deletion remains
unproved. Preserve that failed receipt and its empty/incomplete timed-out streams.

One changed continuation uses the same2.5 runtime and unchanged app. Pin the
created device's native name/runtime/data path and directory identity before
boot. After boot, target only its exact UUID; do not require a global inventory
call before install or cleanup. Bootstatus completion alone remains separate
from readiness. Actual install, reported app PID/liveness and reviewed capture
are still required. Cleanup uses native shutdown/delete on that pinned UUID,
verifies its directory is absent and preserves every preexisting device
directory's original presence. No timeout increase, service reset, global
shutdown/delete, runtime switch, weakening of the app assertions or second
simultaneous job is authorized. The earlier unproved cleanup remains unproved.

The [changed continuation also failed](../results/2026/11-12/simulator-launch-attempt-2.md)
at runtime inventory before any device creation. Both terminal originals are
retained, workflow415336739 is disabled and both QA refs are retired. This
packet is stopped without a launch verdict. Resume native execution only after
an evidence-supported environment/tool change or a separately prepared
diagnostic that can resolve the observed availability boundary; source status
alone does not authorize an unchanged repeat or timeout increase.
