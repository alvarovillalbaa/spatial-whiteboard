# First native launch attempt: inventory timeout, no app launch

[Run43131475054](https://github.com/alvarovillalbaa/spatial-whiteboard/actions/runs/43131475054),
job130896386654, failed at source
`4c17afdc86e04a7b9f474a84a4ed72000da5905f`, QA activation
`2ccb6829e9c7a7fd215cc92182595c6027885e44`.

The unchanged app compiled successfully with the installed visionOS2.5 SDK.
The runner found available xrOS2.5/build22O473 and created exact owned device
754F1732-50A0-47FF-B674-D59824E4E13B. Native boot returned0; bootstatus returned0
with “Device already booted, nothing to do.” This does not establish app readiness.

The following `simctl list devices --json` exceeded its30second bound without
stdout/stderr. The command exited−9 after the controller's timeout. The same
global inventory call used by cleanup also timed out, so this invocation did
not reach native shutdown/delete. **Owned simulator cleanup is unproved.**
The underlying CoreSimulator service cause is unknown; this is an observed
inventory timeout, not a diagnosed app regression or proven runtime bug.

No app install, app launch, screenshot or native editing occurred. The app's
existing85core/editor cases were not replayed. The compiled binary SHA256 was
16296cc4e84aaa219421156fc987162737a6949092dca217b63744eaaf439d43.
All76tracked source modes/blobs were unchanged; owned command groups and the
new build/cache/tmp root were removed. Those results do not erase the missing
simulator teardown, prove runner disposal or establish visual acceptance.

The [original receipt](simulator-launch-attempt-1.json) and
[full original job log](simulator-launch-attempt-1.log) preserve command exits,
lossless streams, incomplete-stream flags, source vectors and runtime/device
metadata. Artifact13904634705 was reported as85338bytes, ZIP SHA256
b58b9ba443ad24daf718c4b057f1ad1fbc93054818b5c3de37126cbec6075782.
That server metadata is not a claim of a locally recovered original ZIP.

The [changed controller scope](../../../proposals/simulator-launch.md) pins
the native device identity before boot and uses only its exact UUID afterward.
It retains the same runtime, app, deadlines and launch/capture assertions.
No outcome from this failed attempt becomes a passing continuation verdict.
