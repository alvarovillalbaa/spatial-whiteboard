"""T1: actual unchanged visionOS app, one owned simulator, no user documents."""
import base64
import gzip
import hashlib
import json
import os
from pathlib import Path
import platform
import plistlib
import re
import selectors
import shutil
import signal
import stat
import subprocess
import tempfile
import time
import traceback
import uuid

SOURCE = os.environ["SPATIAL_SOURCE_COMMIT"]
assert re.fullmatch(r"[0-9a-f]{40}", SOURCE)
assert platform.system() == "Darwin" and platform.machine() == "arm64"
assert os.environ["GITHUB_REPOSITORY"] == "alvarovillalbaa/spatial-whiteboard"
assert os.environ["GITHUB_REF"] == "refs/heads/qa/spatial-launch-20261112"
assert os.environ["SPATIAL_PUBLIC_REPOSITORY"] == "true"
repo = Path.cwd().resolve()
parent = Path(os.environ["RUNNER_TEMP"]).resolve()
root = Path(tempfile.mkdtemp(prefix="spatial-launch-", dir=parent))
root_identity = root.stat()
evidence = parent / ("spatial-launch-evidence-" + os.environ["GITHUB_RUN_ID"])
assert not evidence.exists()
evidence.mkdir(mode=0o700)
for name in ("tmp", "cache", "build", "packages"):
    (root / name).mkdir(mode=0o700)
env = {key: os.environ[key] for key in ("PATH", "HOME", "LANG") if key in os.environ}
env.update(DEVELOPER_DIR="/Applications/Xcode_16.4.app/Contents/Developer", CI="true",
           TMPDIR=str(root / "tmp") + "/", CLANG_MODULE_CACHE_PATH=str(root / "cache"),
           SWIFTPM_MODULECACHE_OVERRIDE=str(root / "cache/swiftpm"))
bundle_id = "com.alvarovillalbaa.SpatialWhiteboard"
device_name = "SpatialWhiteboard-CI-" + os.environ["GITHUB_RUN_ID"] + "-" + uuid.uuid4().hex[:10]
device = None
installed = launched = False
children = []
report = {"schemaVersion": "spatial-simulator-launch-v1", "source": SOURCE,
          "status": "failed", "commands": [], "stages": {}, "cleanup": {}, "errors": [],
          "caseTier": "T1", "coreEditorTestsReplayed": False, "userDocuments": False,
          "uiInputAutomated": False, "physicalDevice": False}
started = time.monotonic()
cleanup_phase = False


def digest(value):
    return hashlib.sha256(value).hexdigest()


def persist():
    (evidence / "receipt.json").write_text(json.dumps(report, indent=2) + "\n")


def run(name, args, seconds=30, allowed=(0,)):
    assert re.fullmatch(r"[a-z0-9-]+", name)
    budget = 900 - (time.monotonic() - started)
    assert cleanup_phase or budget > 0
    timeout = seconds if cleanup_phase else min(seconds, budget)
    child = subprocess.Popen(args, cwd=repo, env=env, stdin=subprocess.DEVNULL,
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True)
    children.append(child)
    streams = {"stdout": bytearray(), "stderr": bytearray()}
    selector = selectors.DefaultSelector()
    for key in streams:
        pipe = getattr(child, key)
        os.set_blocking(pipe.fileno(), False)
        selector.register(pipe, selectors.EVENT_READ, key)
    deadline, stopped = time.monotonic() + timeout, None
    try:
        while selector.get_map():
            if time.monotonic() > deadline or any(len(value) > 1048576 for value in streams.values()):
                stopped = "timeout_or_stream_bound"
                try: os.killpg(child.pid, signal.SIGKILL)
                except ProcessLookupError: pass
                break
            for event, _ in selector.select(0.1):
                value = os.read(event.fd, 65536)
                if value: streams[event.data].extend(value)
                else: selector.unregister(event.fileobj)
        child.wait(timeout=5)
    finally:
        if child.poll() is None:
            try: os.killpg(child.pid, signal.SIGKILL)
            except ProcessLookupError: pass
            child.wait(timeout=5)
        selector.close()
        child.stdout.close(); child.stderr.close()
    try: os.killpg(child.pid, 0)
    except ProcessLookupError: group_absent = True
    else: group_absent = False
    row = {"name": name, "args": args, "exitCode": child.returncode,
           "stopReason": stopped, "groupAbsent": group_absent, "streams": {}}
    for key, value in streams.items():
        kept = bytes(value[:1048576])
        filename = name + "." + key + ".txt"
        (evidence / filename).write_bytes(kept)
        row["streams"][key] = {"file": filename, "bytes": len(kept), "sha256": digest(kept),
                               "complete": stopped is None and len(value) <= 1048576,
                               "gzipBase64": base64.b64encode(gzip.compress(kept, mtime=0)).decode()}
    report["commands"].append(row)
    persist()
    assert child.returncode in allowed and stopped is None and group_absent, name + " failed"
    return bytes(streams["stdout"])


def sim(name, *args, seconds=30, allowed=(0,)):
    return run(name, ["/usr/bin/xcrun", "simctl", *args], seconds, allowed)


def devices(name):
    value = json.loads(sim(name, "list", "devices", "--json"))
    return {row["udid"]: {**row, "runtime": runtime} for runtime, rows in value["devices"].items() for row in rows}


def owned(name):
    rows = devices(name)
    assert device not in preexisting and rows[device]["name"] == device_name
    assert rows[device]["runtime"] == runtime["identifier"]
    return rows[device]


def guard(label):
    assert run(label + "-head", ["git", "rev-parse", "HEAD"]).decode().strip() == SOURCE
    assert run(label + "-status", ["git", "status", "--porcelain=v1", "--untracked-files=all", "--ignored"]) == b""
    vector = []
    for value in run(label + "-tree", ["git", "ls-tree", "-rz", "--long", "HEAD"]).split(b"\0"):
        if not value: continue
        metadata, raw_name = value.split(b"\t", 1)
        mode, kind, blob, length = metadata.decode().split()
        path = Path(raw_name.decode())
        assert not path.is_absolute() and ".." not in path.parts and kind == "blob" and mode in ("100644", "100755")
        item = repo / path
        assert item.is_file() and not item.is_symlink() and int(length) <= 4 * 1024 * 1024
        data = item.read_bytes()
        assert len(data) == int(length) and hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest() == blob
        assert ("100755" if item.stat().st_mode & 0o111 else "100644") == mode
        vector.append({"path": str(path), "mode": mode, "bytes": len(data), "blob": blob, "sha256": digest(data)})
    return vector


try:
    report["sourceFiles"] = baseline = guard("before")
    report["hostFreeBytes"] = shutil.disk_usage(parent).free
    assert report["hostFreeBytes"] >= 12 * 1024 ** 3, "runner storage admission failed"
    report["xcode"] = run("xcode", ["/usr/bin/xcodebuild", "-version"]).decode()
    report["sdk"] = run("sdk", ["/usr/bin/xcrun", "--sdk", "xrsimulator", "--show-sdk-version"]).decode().strip()
    assert report["sdk"].startswith("2.")
    runtimes = json.loads(sim("runtimes", "list", "runtimes", "--json"))["runtimes"]
    available = [row for row in runtimes if row.get("isAvailable") is True and row.get("version", "").startswith("2.") and "xrOS" in row["identifier"]]
    assert available, "installed visionOS2 runtime unavailable; no runtime download authorized"
    runtime = max(available, key=lambda row: tuple(map(int, row["version"].split("."))))
    types = json.loads(sim("device-types", "list", "devicetypes", "--json"))["devicetypes"]
    device_type = next(row for row in types if row["identifier"] == "com.apple.CoreSimulator.SimDeviceType.Apple-Vision-Pro")
    report["runtime"] = runtime
    preexisting = devices("devices-before")
    assert all(row["name"] != device_name for row in preexisting.values())
    report["preexistingDeviceIds"] = sorted(preexisting)
    report["ownedDeviceName"] = device_name
    run("build", ["/usr/bin/xcodebuild", "-project", "SpatialWhiteboard.xcodeproj", "-scheme", "SpatialWhiteboard",
                  "-configuration", "Debug", "-sdk", "xrsimulator", "-destination", "generic/platform=visionOS Simulator",
                  "-derivedDataPath", str(root / "build"), "-clonedSourcePackagesDirPath", str(root / "packages"),
                  "CODE_SIGNING_ALLOWED=NO", "build"], 300)
    app = root / "build/Build/Products/Debug-xrsimulator/SpatialWhiteboard.app"
    info = plistlib.loads((app / "Info.plist").read_bytes())
    assert info["CFBundleIdentifier"] == bundle_id and info["CFBundleExecutable"] == "SpatialWhiteboard"
    report["stages"]["build"] = {"status": "passed", "binarySha256": digest((app / "SpatialWhiteboard").read_bytes())}
    created = sim("create", "create", device_name, device_type["identifier"], runtime["identifier"]).decode().strip()
    device = str(uuid.UUID(created)).upper()
    report["ownedDeviceId"] = device
    owned("device-created")
    sim("boot", "boot", device)
    sim("boot-status", "bootstatus", device, "-b", seconds=180)
    assert owned("device-booted")["state"] == "Booted"
    sim("install", "install", device, str(app), seconds=60)
    installed = True
    app_container = sim("app-container", "get_app_container", device, bundle_id, "app").decode().strip()
    assert device in app_container and app_container.endswith("SpatialWhiteboard.app")
    launched_text = sim("launch", "launch", device, bundle_id).decode().strip()
    match = re.fullmatch(re.escape(bundle_id) + r": (\d+)", launched_text)
    assert match, "native launch did not report application PID"
    app_pid = int(match.group(1))
    launched = True
    report["stages"]["launch"] = {"status": "passed", "pid": app_pid, "container": app_container}
    samples = []
    for index in range(3):
        command = run("live-" + str(index), ["/bin/ps", "-p", str(app_pid), "-o", "command="]).decode().strip()
        assert command.startswith(app_container + "/SpatialWhiteboard")
        samples.append({"afterSeconds": time.monotonic() - started, "pid": app_pid, "command": command})
        if index < 2: time.sleep(5)
    report["stages"]["liveness"] = {"status": "passed", "samples": samples}
    sim("screenshot-help", "io", device, "screenshot", "--help", allowed=(0, 1))
    png = evidence / "launch.png"
    sim("screenshot", "io", device, "screenshot", "--type=png", str(png), seconds=60)
    image = png.read_bytes()
    assert 24 <= len(image) <= 4 * 1024 * 1024 and image[:8] == b"\x89PNG\r\n\x1a\n"
    width, height = int.from_bytes(image[16:20], "big"), int.from_bytes(image[20:24], "big")
    assert 320 <= width <= 8192 and 240 <= height <= 8192
    report["stages"]["capture"] = {"status": "captured_unreviewed", "bytes": len(image), "sha256": digest(image), "width": width, "height": height}
    print("SPATIAL_LAUNCH_PNG_BEGIN", flush=True)
    encoded = base64.b64encode(image).decode()
    for offset in range(0, len(encoded), 4096): print(encoded[offset:offset + 4096], flush=True)
    print("SPATIAL_LAUNCH_PNG_END", flush=True)
except BaseException as error:
    report["errors"].append(type(error).__name__ + ": " + str(error))
    report["traceback"] = traceback.format_exc()
finally:
    cleanup_phase = True
    if device is None:
        # A failed create still keeps its original output; never guess a resource ID.
        create_rows = [row for row in report["commands"] if row["name"] == "create"]
        if create_rows:
            value = (evidence / "create.stdout.txt").read_text().strip()
            try: device = str(uuid.UUID(value)).upper()
            except ValueError: report["errors"].append("device creation outcome unknown")
    if device is not None:
        try:
            row = owned("cleanup-device-identity")
            device_path = Path(row["dataPath"]).parent
            assert device_path.name == device and device_path.parent.name == "Devices"
            if row["state"] == "Booted":
                if launched: sim("terminate", "terminate", device, bundle_id, allowed=(0, 3))
                if installed: sim("uninstall", "uninstall", device, bundle_id)
                sim("shutdown", "shutdown", device, seconds=60)
            assert owned("device-stopped")["state"] == "Shutdown"
            sim("delete", "delete", device, seconds=60)
            after_devices = devices("devices-after")
            assert device not in after_devices and set(preexisting) <= set(after_devices)
            report["cleanup"]["ownedDeviceAbsent"] = True
            report["cleanup"]["preexistingDeviceIdsRetained"] = True
            deadline = time.monotonic() + 30
            while device_path.exists() and time.monotonic() < deadline: time.sleep(0.5)
            assert not device_path.exists(), "owned simulator directory remains"
            report["cleanup"]["ownedDeviceDirectoryAbsent"] = True
            if launched:
                remaining = run("app-pid-after", ["/bin/ps", "-p", str(app_pid), "-o", "command="], allowed=(0, 1)).decode().strip()
                assert not remaining, "application PID still exists after owned device deletion"
                report["cleanup"]["appPidAbsent"] = True
        except BaseException as error:
            report["errors"].append("simulator cleanup: " + str(error))
    else: report["cleanup"]["noDeviceCreated"] = not any(row["name"] == "create" for row in report["commands"])
    try:
        for child in children:
            assert child.poll() is not None
            try: os.killpg(child.pid, 0)
            except ProcessLookupError: pass
            else: raise RuntimeError("owned child process group remains")
        report["cleanup"]["ownedChildGroupsAbsent"] = True
        if "baseline" in globals():
            assert guard("after") == baseline
            report["cleanup"]["sourceUnchanged"] = True
        current = root.lstat()
        assert root.parent == parent and not root.is_symlink() and stat.S_ISDIR(current.st_mode)
        assert (current.st_dev, current.st_ino, current.st_uid) == (root_identity.st_dev, root_identity.st_ino, os.getuid())
        shutil.rmtree(root)
        report["cleanup"]["ownedRootAbsent"] = not root.exists()
    except BaseException as error:
        report["errors"].append("source/process/root cleanup: " + str(error))
report["status"] = "captured_pending_visual_review" if not report["errors"] and all(report["cleanup"].values()) and report["stages"].get("capture") else "failed"
report["seconds"] = time.monotonic() - started
persist()
print("SPATIAL_LAUNCH_RESULT=" + json.dumps(report, separators=(",", ":")), flush=True)
raise SystemExit(0 if report["status"] == "captured_pending_visual_review" else 1)
