# Changed launch continuation: runtime inventory unavailable

[Run43132709133](https://github.com/alvarovillalbaa/spatial-whiteboard/actions/runs/43132709133),
job130900479579, failed at source
`b2e5deea8f2b429655d0ec1c8841afdb56250339`, QA activation
`bc5a28e9276fbe010c64964106f2700278003a18`.

The changed controller pinned an owned device identity before boot and avoided
post-boot all-device inventory. The app/core/project/resources remained exact
to the first attempt. This invocation failed before reaching that change:
`simctl list runtimes --json` timed out at30seconds without stdout/stderr,
and exited−9 after the controller stopped its process group. Xcode and SDK2.5
queries had succeeded. The CoreSimulator cause remains unknown.

No build, device creation, boot, app install/launch or screenshot occurred.
The controller completed in32.46seconds. All tracked input bytes/modes remained
unchanged, all owned child groups were absent, and owned scratch was removed.
There was no new simulator to tear down. The first attempt's device teardown
remains unproved; this successful scratch cleanup does not replace it.

The [original receipt](simulator-launch-attempt-2.json) and
[full original log](simulator-launch-attempt-2.log) preserve18lossless streams,
including the two correctly marked incomplete streams from the timed-out
command. All retained bytes were independently decompressed and rehashed.
Artifact13905557860 was reported as20602bytes, ZIP SHA256
d6bd380ff42a03ad134749ff039a8e22b238a5c2d5e6487a30c20275a59a0f00.
No locally recovered original ZIP is claimed.

The temporary workflow415336739 is disabled and both exact QA refs have been
deleted after terminal results. No automatic third invocation, timeout increase,
global simulator reset or unchanged runtime probe is scheduled. Native
continuation needs an evidence-supported tool/environment change or a separate
diagnostic that can resolve the observed CoreSimulator availability boundary.
The changed UUID-only protocol itself remains unqualified.
