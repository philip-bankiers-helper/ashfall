#!/usr/bin/env python3
"""Install the Godot 4.7.2 Android source template and OpenXR vendors addon from local archives.

Does not download files, edit export presets, or replace an existing tree that is not the verified install.
"""
import argparse, hashlib, stat, sys, zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TEMPLATE_VERSION = "4.7.2.stable"
VENDOR_SHA256 = "6a838dbdf4115549e4511ebee0da9a5dcc8f9f6258d4cc2f2ee57a907a3e2911"
VENDOR_PREFIX = "asset/addons/godotopenxrvendors"
ANDROID_DIR = ROOT / "android"
TEMPLATE_DIR = ANDROID_DIR / "build"
VERSION_FILE = ANDROID_DIR / ".build_version"
GDIGNORE = ANDROID_DIR / ".gdignore"
ADDON_DIR = ROOT / "addons" / "godotopenxrvendors"

def sha256_file(path):
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()

def fail(message):
    sys.exit(message)

def safe_parts(name):
    text = name.replace("\\", "/")
    if "\x00" in text or text.startswith("/") or (len(text) >= 2 and text[1] == ":"):
        fail(f"refusing archive path: {name}")
    parts = []
    for part in text.split("/"):
        if part in ("", "."):
            continue
        if part == "..":
            fail(f"refusing archive path: {name}")
        parts.append(part)
    return parts

def is_symlink(info):
    return ((info.external_attr >> 16) & 0o170000) == stat.S_IFLNK

def iter_files(archive):
    for info in archive.infolist():
        if is_symlink(info):
            fail(f"refusing symlink in archive: {info.filename}")
        parts = safe_parts(info.filename)
        if info.is_dir() or not parts:
            continue
        yield info, parts

def entry_sha256(archive, info):
    digest = hashlib.sha256()
    with archive.open(info, "r") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()

def tree_hashes(dest):
    if dest.is_symlink():
        fail(f"refusing existing symlink: {dest}")
    if not dest.exists():
        return {}
    if not dest.is_dir():
        fail(f"{dest} exists and is not a directory")
    found = {}
    for path in sorted(dest.rglob("*")):
        if path.is_symlink():
            fail(f"refusing existing symlink: {path}")
        if path.is_file():
            found[path.relative_to(dest).as_posix()] = sha256_file(path)
    return found

def inside(dest, rel_parts):
    root = dest.resolve()
    target = root.joinpath(*rel_parts)
    if target != root and root not in target.parents:
        fail(f"refusing to write outside {dest}: {'/'.join(rel_parts)}")
    return target

def extract(archive, items, dest):
    dest.mkdir(parents=True, exist_ok=True)
    for info, rel_parts, _digest in items:
        target = inside(dest, rel_parts)
        target.parent.mkdir(parents=True, exist_ok=True)
        with archive.open(info, "r") as src, target.open("wb") as out:
            for chunk in iter(lambda: src.read(1024 * 1024), b""):
                out.write(chunk)
        mode = (info.external_attr >> 16) & 0o777
        if mode:
            target.chmod(mode)

def main():
    parser = argparse.ArgumentParser(description="Install local Godot Android template and OpenXR vendors addon")
    parser.add_argument("--templates", required=True, help="Directory containing android_source.zip and version.txt")
    parser.add_argument("--vendor-zip", required=True, help="Official Godot OpenXR Vendors zip (local file)")
    args = parser.parse_args()
    templates = Path(args.templates).expanduser().resolve()
    vendor_zip = Path(args.vendor_zip).expanduser().resolve()
    version_path = templates / "version.txt"
    source_zip = templates / "android_source.zip"
    if not version_path.is_file() or not source_zip.is_file():
        fail("Pass --templates pointing at a directory with android_source.zip and version.txt")
    if not vendor_zip.is_file():
        fail("Pass --vendor-zip pointing at the local official vendors archive")
    try:
        version = version_path.read_text(encoding="utf-8").strip()
    except OSError as exc:
        fail(f"could not read template version: {exc}")
    if version != TEMPLATE_VERSION:
        fail(f"template version is {version!r}, required {TEMPLATE_VERSION}")
    try:
        vendor_hash = sha256_file(vendor_zip)
    except OSError as exc:
        fail(f"could not read vendor zip: {exc}")
    if vendor_hash != VENDOR_SHA256:
        fail(f"vendor zip sha256 is {vendor_hash}, required {VENDOR_SHA256}")

    try:
        android_archive = zipfile.ZipFile(source_zip)
        vendor_archive = zipfile.ZipFile(vendor_zip)
    except (OSError, zipfile.BadZipFile) as exc:
        fail(f"could not read archive: {exc}")
    try:
        android_rows = []
        for info, parts in iter_files(android_archive):
            android_rows.append((info, parts, entry_sha256(android_archive, info)))
        tops = {parts[0] for _info, parts, _digest in android_rows}
        strip = len(tops) == 1 and not any(parts == ["gradlew"] for _info, parts, _digest in android_rows)
        android_items = []
        android_expected = {}
        for info, parts, digest in android_rows:
            rel_parts = parts[1:] if strip else parts
            if not rel_parts:
                continue
            rel = "/".join(rel_parts)
            if rel in android_expected:
                fail(f"duplicate archive path: {rel}")
            android_expected[rel] = digest
            android_items.append((info, rel_parts, digest))
        if "gradlew" not in android_expected:
            fail("android_source.zip has no gradlew")

        prefix = safe_parts(VENDOR_PREFIX)
        vendor_items = []
        vendor_expected = {}
        for info, parts in iter_files(vendor_archive):
            if parts[:len(prefix)] != prefix:
                continue
            rel_parts = parts[len(prefix):]
            if not rel_parts:
                fail(f"invalid vendors path: {info.filename}")
            rel = "/".join(rel_parts)
            if rel in vendor_expected:
                fail(f"duplicate vendors path: {rel}")
            digest = entry_sha256(vendor_archive, info)
            vendor_expected[rel] = digest
            vendor_items.append((info, rel_parts, digest))
        if not vendor_expected:
            fail(f"vendor zip has no {VENDOR_PREFIX}/ files")

        template_files = tree_hashes(TEMPLATE_DIR)
        addon_files = tree_hashes(ADDON_DIR)
        version_text = VERSION_FILE.read_text(encoding="utf-8").strip() if VERSION_FILE.is_file() else ""
        template_exact = bool(template_files) and template_files == android_expected and version_text == TEMPLATE_VERSION
        addon_exact = bool(addon_files) and addon_files == vendor_expected
        if template_files and not template_exact:
            fail("refusing to overwrite existing Android template; it is not the verified 4.7.2.stable install")
        if VERSION_FILE.exists() and version_text != TEMPLATE_VERSION:
            fail("refusing to overwrite android/.build_version; it is not 4.7.2.stable")
        if addon_files and not addon_exact:
            fail("refusing to overwrite existing OpenXR vendors addon; it is not the verified archive")

        if not template_exact:
            ANDROID_DIR.mkdir(parents=True, exist_ok=True)
            extract(android_archive, android_items, TEMPLATE_DIR)
            if tree_hashes(TEMPLATE_DIR) != android_expected:
                fail("Android template did not match android_source.zip after extract")
            VERSION_FILE.write_text(TEMPLATE_VERSION + "\n", encoding="utf-8")
            GDIGNORE.write_text("", encoding="utf-8")
        elif not GDIGNORE.exists():
            GDIGNORE.write_text("", encoding="utf-8")
        gradlew = TEMPLATE_DIR / "gradlew"
        if not gradlew.is_file():
            fail("Android template is missing gradlew")
        gradlew.chmod(gradlew.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)

        if not addon_exact:
            extract(vendor_archive, vendor_items, ADDON_DIR)
            if tree_hashes(ADDON_DIR) != vendor_expected:
                fail("OpenXR vendors addon did not match the archive after extract")
    finally:
        android_archive.close()
        vendor_archive.close()
    print(f"Quest Android template {TEMPLATE_VERSION} and OpenXR vendors addon are installed")

if __name__ == "__main__":
    try:
        main()
    except OSError as exc:
        sys.exit(f"filesystem error: {exc}")
