#!/usr/bin/env python3
"""Signed debug Quest 3 APK. Does not install, deploy, or validate a headset."""
import argparse, hashlib, json, re, subprocess, sys, zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PRESET = "Quest 3"
ENGINE = "4.7.2"
TEMPLATE_VERSION = "4.7.2.stable"
ANSI_RE = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")
ERROR_RE = re.compile(r"(?m)SCRIPT ERROR:|Parse Error:|^ERROR:")
VERSION_RE = re.compile(r"^4\.7\.2(?:[.\s]|$)")
USER_FLAGS = ("--require-vr", "--extended", "--playtest-catalog")
FORBIDDEN = {"--desktop", "--smoke", "--low-poly", "--xr-mode=off", "--xr-mode off", "--xr_mode_regular"}
REQUIRED_LIBS = ("libopenxr_loader.so", "libgodot_android.so")

def as_text(value):
    if value is None:
        return ""
    if isinstance(value, bytes):
        return value.decode("utf-8", "replace")
    return value

def sha256_file(path):
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()

def git(*args, timeout):
    proc = subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True, errors="replace", timeout=timeout)
    if proc.returncode != 0:
        raise RuntimeError(as_text(proc.stderr).strip() or "git failed")
    return as_text(proc.stdout).strip()

def printable_args(args):
    if not args:
        return False
    for arg in args:
        if not arg or any(ord(char) < 32 for char in arg):
            return False
    return True

def decode_framed(data):
    if len(data) < 4:
        return None
    count = int.from_bytes(data[:4], "little")
    if count < 1 or count > 64:
        return None
    offset = 4
    args = []
    for _ in range(count):
        if offset + 4 > len(data):
            return None
        size = int.from_bytes(data[offset:offset + 4], "little")
        offset += 4
        if size < 1 or size > 4096 or offset + size > len(data):
            return None
        raw = data[offset:offset + size]
        offset += size
        try:
            args.append(raw.decode("utf-8"))
        except UnicodeDecodeError:
            return None
    if offset != len(data) or not printable_args(args):
        return None
    return args

def decode_cl(data):
    # Godot 4.7.2 Android assets/_cl_ is little-endian argc, then length-prefixed plain UTF-8.
    return decode_framed(data)

def remap_target(text, expected):
    match = re.search(r'(?m)^path="([^"]*)"\s*$', text)
    if not match or match.group(1) != expected:
        return None
    return expected

def script_entries(archive):
    found = {}
    for info in archive.infolist():
        name = info.filename.replace("\\", "/")
        if name.startswith("assets/scripts/") and not info.is_dir():
            found[name] = info.file_size
    return found

def audit_apk(apk):
    scripts = sorted(path.relative_to(ROOT).as_posix() for path in (ROOT / "scripts").rglob("*.gd") if path.is_file())
    if not scripts:
        raise RuntimeError("no scripts/*.gd files to audit")
    missing_scripts = []
    flags = None
    native = []
    with zipfile.ZipFile(apk) as archive:
        entries = script_entries(archive)
        for rel in scripts:
            compiled = rel[:-3] + ".gdc"
            plain = f"assets/{rel}"
            remap = f"assets/{rel}.remap"
            gdc = f"assets/{compiled}"
            if entries.get(plain, 0) > 0:
                continue
            if remap not in entries:
                missing_scripts.append(rel)
                continue
            try:
                text = archive.read(remap).decode("utf-8")
            except UnicodeDecodeError:
                missing_scripts.append(rel)
                continue
            if remap_target(text, f"res://{compiled}") and entries.get(gdc, 0) > 0:
                continue
            missing_scripts.append(rel)
        names = [info.filename.replace("\\", "/") for info in archive.infolist()]
        sizes = {info.filename.replace("\\", "/"): info.file_size for info in archive.infolist()}
        for name in names:
            if name.startswith("lib/") and name.endswith(".so"):
                native.append(name)
        cl_name = next((name for name in names if name == "assets/_cl_"), None)
        if cl_name is None:
            raise RuntimeError("APK is missing assets/_cl_")
        flags = decode_cl(archive.read(cl_name))
        if not flags:
            raise RuntimeError("could not decode assets/_cl_")
    abis = {name.split("/")[1] for name in native if name.count("/") >= 2}
    if abis != {"arm64-v8a"}:
        raise RuntimeError(f"APK native ABIs are {sorted(abis)}, required arm64-v8a only")
    by_name = {}
    for name in native:
        by_name.setdefault(Path(name).name, []).append(name)
    missing_libs = [name for name in REQUIRED_LIBS if name not in by_name or any(sizes.get(path, 0) <= 0 for path in by_name[name])]
    if missing_libs:
        raise RuntimeError("APK is missing native libs: " + ", ".join(missing_libs))
    stray = [name for name in native if not name.startswith("lib/arm64-v8a/")]
    if stray:
        raise RuntimeError("APK has native libs outside lib/arm64-v8a")
    if "--" not in flags:
        raise RuntimeError("APK launch flags have no -- before user flags")
    user_flags = flags[flags.index("--") + 1:]
    missing_flags = [flag for flag in USER_FLAGS if flag not in user_flags]
    if "--xr_mode_openxr" not in flags:
        missing_flags.append("--xr_mode_openxr")
    rejected = [flag for flag in flags if flag in FORBIDDEN]
    for index, flag in enumerate(flags):
        if flag == "--xr-mode" and index + 1 < len(flags) and flags[index + 1] == "off":
            rejected.append("--xr-mode off")
    if missing_flags or rejected:
        raise RuntimeError(f"APK launch flags missing {missing_flags} rejected {rejected}")
    if missing_scripts:
        sample = ", ".join(missing_scripts[:8])
        raise RuntimeError(f"APK is missing {len(missing_scripts)} script entries, including {sample}")
    return {"abi": "arm64-v8a", "loader": "libopenxr_loader.so", "flags": flags, "script_count": len(scripts)}

def main():
    parser = argparse.ArgumentParser(description="Export the full ASHFALL Quest 3 debug APK")
    parser.add_argument("--godot", required=True)
    parser.add_argument("--output", required=True, help="Fresh external directory for the APK and receipt")
    parser.add_argument("--timeout", type=int, default=3600)
    args = parser.parse_args()
    if args.timeout <= 0:
        sys.exit("Pass a positive --timeout in seconds")
    godot = Path(args.godot).expanduser().resolve()
    out = Path(args.output).expanduser().resolve()
    apk = out / "ASHFALL-Quest-Preview.apk"
    receipt_path = out / "quest-build-result.json"
    logs = out / "logs"
    state = {"ok": False, "headset_verified": False, "device_validation": "pending",
             "engine_required": ENGINE, "preset": PRESET, "commands": [], "apk": str(apk)}
    if not godot.is_file():
        sys.exit("Pass --godot pointing at a Godot 4.7.2 binary")
    if ROOT == out or ROOT in out.parents:
        sys.exit("Pass --output as a directory outside the project")
    if out.exists() and not out.is_dir():
        sys.exit("Output path exists and is not a directory")
    if out.exists() and any(out.iterdir()):
        sys.exit("Output directory must be fresh and empty")
    try:
        out.mkdir(parents=True, exist_ok=True)
        logs.mkdir(parents=True, exist_ok=True)
    except OSError as exc:
        sys.exit(f"could not create output directory: {exc}")

    def finish(code, reason=""):
        if reason:
            state["failure"] = reason
        try:
            receipt_path.write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
        except OSError as exc:
            print(f"could not write failure receipt: {exc}", file=sys.stderr)
        print(json.dumps(state, indent=2))
        sys.exit(code)

    def run(name, argv, marker=None):
        state["commands"].append(argv)
        log_path = logs / f"{name}.log"
        try:
            proc = subprocess.run(argv, cwd=ROOT, capture_output=True, text=True, errors="replace", timeout=args.timeout)
        except subprocess.TimeoutExpired as exc:
            text = as_text(exc.stdout) + as_text(exc.stderr) + "\nTIMEOUT\n"
            try:
                log_path.write_text(text, encoding="utf-8")
            except OSError as write_exc:
                finish(1, f"could not write {name} log: {write_exc}")
            finish(1, f"{name} timed out after {args.timeout}s")
        except OSError as exc:
            finish(1, f"{name} failed to start: {exc}")
        text = as_text(proc.stdout) + ("\n" if proc.stderr else "") + as_text(proc.stderr)
        try:
            log_path.write_text(text, encoding="utf-8")
        except OSError as exc:
            finish(1, f"could not write {name} log: {exc}")
        plain = ANSI_RE.sub("", text)
        if proc.returncode != 0:
            finish(proc.returncode or 1, f"{name} exited {proc.returncode}")
        if ERROR_RE.search(plain):
            finish(1, f"{name} reported script, parse, or ERROR output")
        if marker and marker not in plain:
            finish(1, f"{name} missing completion marker {marker}")
        return plain

    try:
        addon = ROOT / "addons" / "godotopenxrvendors" / "plugin.gdextension"
        template = ROOT / "android" / "build" / "gradlew"
        version_file = ROOT / "android" / ".build_version"
        if not addon.is_file():
            finish(1, "OpenXR vendors addon is not installed (addons/godotopenxrvendors/plugin.gdextension)")
        if not template.is_file() or not version_file.is_file():
            finish(1, "Android source template is not installed (android/build)")
        if version_file.read_text(encoding="utf-8").strip() != TEMPLATE_VERSION:
            finish(1, f"android/.build_version is not {TEMPLATE_VERSION}")
        state["source_commit"] = git("rev-parse", "HEAD", timeout=args.timeout)
        state["dirty"] = git("status", "--porcelain", timeout=args.timeout) != ""
        version = run("version", [str(godot), "--version"])
        state["engine_version"] = version.strip().splitlines()[-1].strip() if version.strip() else ""
        if not VERSION_RE.match(state["engine_version"]):
            finish(1, f"engine is {state['engine_version']!r}, required {ENGINE}")
        base = [str(godot), "--headless", "--xr-mode", "off", "--audio-driver", "Dummy", "--path", str(ROOT)]
        run("import", base + ["--editor", "--import"])
        run("public-checks", base + ["--script", "res://tools/test_public.gd"], "PUBLIC_CHECKS_OK")
        run("export-debug", base + ["--export-debug", PRESET, str(apk)])
        if not apk.is_file() or apk.stat().st_size <= 0:
            finish(1, "export did not produce an APK")
        report = audit_apk(apk)
        state.update(ok=True, sha256=sha256_file(apk), bytes=apk.stat().st_size,
                     completion_marker="apk-present", low_poly=False,
                     user_args=list(USER_FLAGS), **report)
        finish(0)
    except SystemExit:
        raise
    except (OSError, subprocess.TimeoutExpired, RuntimeError, zipfile.BadZipFile) as exc:
        finish(1, str(exc) or exc.__class__.__name__)

if __name__ == "__main__":
    main()
