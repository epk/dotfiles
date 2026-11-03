"""Update managed Amp tools and preserve other user settings."""

import json
import os
import pathlib
import sys
import tempfile

source = json.loads(pathlib.Path(sys.argv[1]).read_text())
target = pathlib.Path.home() / ".config/amp/settings.json"
if source["enabled"] or target.exists():
    settings = json.loads(target.read_text()) if target.exists() else {}
    servers = settings.get("amp.mcpServers", {})
    for name in ("browser", "cua", "pomerado"):
        servers.pop(name, None)
    servers.update(source["servers"] if source["enabled"] else {})
    settings["amp.mcpServers"] = servers
    target.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    with tempfile.NamedTemporaryFile(
        mode="w", dir=target.parent, delete=False
    ) as output:
        json.dump(settings, output, indent=2)
        output.write("\n")
    os.replace(output.name, target)
