"""Create encrypted enrollment credentials. Never print plaintext credentials."""

import json
import os
import re
import subprocess
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


def request(url, payload=None, bearer=None, form=False, operation="Credential API"):
    headers = {"Accept": "application/json"}
    if bearer:
        headers["Authorization"] = "Bearer " + bearer
    data = None
    if payload is not None:
        data = (
            urllib.parse.urlencode(payload) if form else json.dumps(payload)
        ).encode()
        headers["Content-Type"] = (
            "application/x-www-form-urlencoded" if form else "application/json"
        )
    try:
        with urllib.request.urlopen(
            urllib.request.Request(url, data=data, headers=headers), timeout=60
        ) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        category = ""
        if operation == "Tailscale enrollment key":
            try:
                message = json.loads(error.read(8192)).get("message", "").lower()
                categories = {
                    "tag": "tags",
                    "expiry": "expiry",
                    "expire": "expiry",
                    "capabilit": "capabilities",
                    "scope": "scopes",
                    "preauthor": "device approval",
                    "reusab": "reusable keys",
                    "ephemer": "ephemeral devices",
                    "description": "description",
                    "keytype": "key type",
                }
                matched = sorted(
                    {value for key, value in categories.items() if key in message}
                )
                if matched:
                    category = " Check " + ", ".join(matched) + "."
            except Exception:
                pass
        raise SystemExit(
            f"{operation} request failed: HTTP {error.code}.{category}"
        ) from None
    except Exception:
        raise SystemExit(f"{operation} request failed.") from None


audience = os.environ["TS_AUDIENCE"]
oidc_url = os.environ["ACTIONS_ID_TOKEN_REQUEST_URL"]
oidc_url += "&audience=" + urllib.parse.quote(audience, safe="")
identity = request(
    oidc_url,
    bearer=os.environ["ACTIONS_ID_TOKEN_REQUEST_TOKEN"],
    operation="GitHub OIDC",
)["value"]
access = request(
    "https://api.tailscale.com/api/v2/oauth/token-exchange",
    {"client_id": os.environ["TS_CLIENT_ID"], "jwt": identity},
    form=True,
    operation="Tailscale token exchange",
)["access_token"]
targets = json.loads(Path("automation/tailscale-targets.json").read_text())
output = Path(os.environ["CREDENTIAL_OUTPUT"])
output.mkdir(parents=True, exist_ok=True)
for name, target in targets.items():
    if not re.fullmatch(r"[a-z][a-z0-9-]{0,62}", name):
        raise SystemExit("Invalid target name.")
    key = request(
        "https://api.tailscale.com/api/v2/tailnet/-/keys",
        {
            "description": re.sub(r"[^a-z0-9]", "", "dotfiles" + name)[:50],
            "expirySeconds": 30 * 24 * 60 * 60,
            "capabilities": {
                "devices": {
                    "create": {
                        "reusable": True,
                        "ephemeral": False,
                        "preauthorized": True,
                        "tags": target["tags"],
                    }
                }
            },
        },
        bearer=access,
        operation="Tailscale enrollment key",
    )
    arguments = ["age"]
    for public_key in target["publicKeys"]:
        arguments.extend(["-r", public_key])
    payload = key["key"].encode()
    destination = output / (name + ".age")
    with destination.open("wb") as encrypted:
        subprocess.run(arguments, input=payload, stdout=encrypted, check=True)
    print("Encrypted enrollment credential: " + name)
