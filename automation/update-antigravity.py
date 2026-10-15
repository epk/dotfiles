"""Update the pinned official Antigravity release metadata."""

import json
import re
import urllib.request
from pathlib import Path

MANIFEST = (
    "https://antigravity-cli-auto-updater-974169037036.us-central1.run.app"
    "/manifests/linux_amd64.json"
)

with urllib.request.urlopen(MANIFEST, timeout=30) as response:
    release = json.load(response)

version = release["version"]
url = release["url"]
checksum = release["sha512"]
if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version):
    raise ValueError("Invalid release version")
if not re.fullmatch(
    r"https://storage\.googleapis\.com/antigravity-public/antigravity-cli/"
    + re.escape(version)
    + r"-[0-9]+/linux-x64/cli_linux_x64\.tar\.gz",
    url,
):
    raise ValueError("Invalid official Linux release URL")
if not re.fullmatch(r"[0-9a-f]{128}", checksum):
    raise ValueError("Invalid SHA512 checksum")

Path("packages/antigravity-release.json").write_text(
    json.dumps({"version": version, "url": url, "sha512": checksum}, indent=2) + "\n"
)
