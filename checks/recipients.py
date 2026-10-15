"""Check that each encrypted file has the recipients in its agenix rule."""

import base64
import hashlib
import json
import sys
from pathlib import Path

secrets = Path(sys.argv[1])
rules = json.loads(sys.argv[2])


def tag(public_key):
    # age names an ssh-ed25519 recipient by 4 bytes of SHA-256 of the wire key.
    wire = base64.b64decode(public_key.split()[1])
    return base64.b64encode(hashlib.sha256(wire).digest()[:4]).decode().rstrip("=")


files = sorted(str(path.relative_to(secrets)) for path in secrets.rglob("*.age"))
if unruled := sorted(set(files) - set(rules)):
    sys.exit(f"These encrypted files have no rule: {unruled}.")
# A new rule has no file until the first rotation or edit creates it.
for name in files:
    rule = rules[name]
    header = (secrets / name).read_bytes().split(b"\n---", 1)[0].decode().splitlines()
    if header[0] != "age-encryption.org/v1":
        sys.exit(f"{name} is not an age file.")
    found = sorted(
        line.split()[2] for line in header if line.startswith("-> ssh-ed25519 ")
    )
    if found != sorted(tag(key) for key in rule["publicKeys"]):
        sys.exit(f"{name} does not have the recipients in its rule. Run agenix -r.")
