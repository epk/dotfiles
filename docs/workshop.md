# Workshop guest

The workshop guest is a persistent Firecracker guest managed by `microvm.nix`.
It runs Paseo and stock Chromium. It also contains Codex CLI, Claude Code, Gemini CLI and Antigravity CLI.
The Shared Browser plugin gives connected clients the same browser session and explicit human control.

## Access

Use the existing administrator SSH key. Do not forward the SSH agent.

```sh
ssh -J <host-user>@<host-address> operator@<guest-address>
```

Forward Paseo through both SSH connections:

```sh
ssh -N -J <host-user>@<host-address> -L 6767:127.0.0.1:6767 operator@<guest-address>
```

Open `http://127.0.0.1:6767` in your browser.
The Paseo desktop client can also use an SSH connection.
For phone access, use an SSH client that supplies local port forwarding.
The Paseo mobile app does not supply this SSH connection.

Paseo listens only on guest loopback. Its external relay is disabled.
The guest has no Tailscale client. From outside the local network, connect through host Tailscale.

## Accounts and credentials

`operator` administers the guest. `agent` runs Paseo, Codex and Chromium without administrator privileges.
Paseo clients can control programs with the `agent` user's file and network access.
Do not supply host private keys, recovery private keys, operations vault access or personal browser profiles.

Complete Codex authentication as `agent`:

```sh
sudo -u agent -H codex login --device-auth
```

Codex authentication requires approval from the account holder. The repository declares no account credential.
Use `sudo -u agent -H claude auth login` to authenticate Claude Code.
The Antigravity CLI command is `agy`.
Use `sudo --preserve-env=SSH_CONNECTION,SSH_CLIENT,SSH_TTY -u agent -H agy` to authenticate Antigravity CLI over SSH.
Gemini CLI stays installed for API-key access. Its Paseo provider is disabled.
The configuration enables the Antigravity provider in Paseo.
Paseo starts `agy` with full access, so every tool call runs without a permission prompt.
The integration cannot use Paseo MCP tools, including Shared Browser takeover tools.
The normal CLI permission flow remains available when you run `agy` directly.
Browser profiles and Codex authentication persist under `/home/agent`.
Use separate website accounts with restricted permissions where possible.
Browser control can use a saved login without knowing its password.
Shell access can expose session files available to the same user.

New guest SSH host keys are generated inside the guest.
The current guest needs no agenix private key or application secret.
Do not copy the host Tailscale state or private keys to guests.

## Browser control

Open Shared Browser in Paseo for the selected workspace.
Take human control before manual browser actions. Release control when the agent can continue.
The browser tools cannot take control while a human holds it.
This control lease does not restrict arbitrary shell access.

Each workspace keeps a separate persistent Chromium profile.
Archiving a workspace closes its browser but keeps its profile.
Delete unused profiles when their saved sessions are no longer needed.
The plugin does not support uploads, downloads, clipboard synchronization, extensions, media permissions or passkeys.
It provides browser streaming, not a full VNC desktop.

## Packages and isolation

The flake pins Paseo. The guest uses Node.js 24 for its daemon and plugin.
The repository pins Google's versioned Antigravity download URL and archive checksum.
Weekly update PRs refresh `packages/antigravity-release.json`. CI must pass before deployment.
`packages/shared-browser.nix` pins the plugin archive and its npm dependency hash.
Nix builds the supervisor and MCP bundles. Startup does not install packages or download Chromium.
The guest uses the source-built `agent-browser` package and the stock Nix Chromium package.
The plugin uses a private Xvfb display. No GPU is passed through.
Chromium keeps its sandbox. No `--no-sandbox` flag is configured.

The VMM has a dedicated host user, restricted filesystem view, device permissions and empty Linux capabilities.
Firecracker supplies its default seccomp filters.
The guest cannot initiate connections to the host, private networks, tailnet addresses or other guests.
It can use public IPv4 addresses through the `uplink` interface. Guest IPv6 traffic is blocked.
These guest rules apply only to `workshop-tap`. Host SSH and Tailscale rules remain unchanged.

## Capacity and durability

The guest has two vCPUs and 4 GiB RAM. Its VMM has a 5 GiB memory limit.
CPU use is limited to two cores, with a lower scheduling weight than host services.
These values are limits, not performance measurements.

The read-only EROFS image contains the guest system closure.
Firecracker does not support the configured virtio-fs store export.
Sparse raw ext4 disks provide 8 GiB for `/var` and 32 GiB for `/home`.
The host stores both disks in `/storage/nvme/vms/workshop`, a private Btrfs subvolume.
Host CoW, Zstd compression and checksums remain enabled.
Buffered I/O permits host compression. Firecracker `Writeback` supports guest flush requests.
The pinned Firecracker release does not support guest discard. Host SSD TRIM remains enabled.

No guest backup destination is configured.
Before storing irreplaceable data, configure an encrypted backup on another machine.
Stop application writes before copying writable guest disks.
Firecracker validates only the host kernel versions in its [kernel policy](https://github.com/firecracker-microvm/firecracker/blob/main/docs/kernel-policy.md).
The host runs `linuxPackages_latest`, which can be a different version.

## Host module

Import `modules/nixos/workshop.nix` on the host. Set `services.workshop.enable` to `true`.
The module defines the guest, private disks, resource limits and guest network rules.
Set `administratorKeys` from private host metadata. Set `uplink` and `storageDirectory` when the defaults do not apply.
The module uses the pinned Antigravity release from the repository.
The guest definition is `modules/nixos/guests/workshop.nix`.
A deployment that changes the guest system or restarts the host firewall restarts the workshop VM.
Keep actual connection commands in the private inventory.

Sources: [Paseo security](https://paseo.sh/docs/security),
[connectivity](https://paseo.sh/docs/connectivity),
[Shared Browser](https://paseo.sh/plugins/omercnet/shared-browser),
[Firecracker block I/O](https://github.com/firecracker-microvm/firecracker/blob/main/docs/block.md).
Provider sources: [Claude authentication](https://code.claude.com/docs/en/authentication),
[Gemini authentication](https://geminicli.com/docs/get-started/authentication/),
[Antigravity authentication](https://antigravity.google/docs/cli/install/),
[Paseo providers](https://paseo.sh/docs/supported-providers),
[Gemini CLI transition to Antigravity CLI](https://developers.googleblog.com/an-important-update-transitioning-gemini-cli-to-antigravity-cli/).
