# Automation

## Workflows

- `check.yml` runs on pushes to all branches and on dispatch.
- `rotate-tailscale.yml` runs each week, on dispatch and on pushes to `main` that change its files.
- `update-flake-lock.yml` runs each week and on dispatch.

Its files are `automation/tailscale-targets.json`, `automation/rotate-tailscale.py`, `automation/open-bot-pr.sh` and `.github/workflows/rotate-tailscale.yml`.

## Required checks

A PR merges only after these checks pass:

- `eval + format`
- `build server`
- `build macos-personal`
- `build macos-work`

## Deployment

`check.yml` evaluates all outputs, builds `server` and runs the flake checks.
Its Mac jobs run `setup.sh` and `reload!`.
The host uses NixOS `system.autoUpgrade` to fetch `github:epk/dotfiles#server` each hour.
Branch protection on `main` is strict. A PR merges only when it is up to date with `main` and its required checks pass.
So `main` holds only trees that CI tested.
NixOS rebuilds and applies that configuration. It uses the committed `flake.lock`.
Automatic deployment does not update inputs, collect system generations, reboot or format disks.
The boot loader selects the new kernel at the next reboot.
The host preserves the running Tailscale service during activation.
GitHub receives no administrator SSH key or host private key.

Automatic deployment does not use the checkout at `/etc/nixos`.
Keep that checkout for manual inspection. Its revision can differ from the applied configuration.
Use `systemctl status nixos-upgrade.service` to inspect deployment.
Use `systemctl list-timers nixos-upgrade.timer` to inspect the schedule.

The host applies a merged weekly update within about one hour.
To roll back, run this command on the host:

```sh
sudo nixos-rebuild switch --rollback
```

Then open a revert PR. The next hourly run applies `main` again until the revert merges.

The update workflows push and merge with a GitHub App token. Pushes with `GITHUB_TOKEN` do not start CI, and GitHub does not count dispatched runs as PR checks.
The check workflow does not use pull_request events, which require approval for bot-created PRs.
`automation/open-bot-pr.sh` fails the bot job when a required check fails, or after 30 minutes without a merge.

The app has read and write access to contents and pull requests on this repository only. It has no webhook.
The repository variable `BOT_CLIENT_ID` holds its client ID. The secret `BOT_PRIVATE_KEY` holds its private key.
To replace the key, generate a new key in the app settings, update the secret and delete the old key.
If CI fails or a PR cannot merge, the workflow stops without deployment.
The repository must remain public. Private repositories require a separate read credential.

## Tailscale enrollment

The weekly rotation workflow uses GitHub OIDC to request enrollment keys from Tailscale.
The trust rule permits only `rotate-tailscale.yml` on protected `main` in `epk/dotfiles`.
Keys are pre-approved and reusable.
Each rotation creates a new key. Earlier keys stay valid until they expire after 30 days.
The workflow encrypts each key for its machine public key and the recovery public key.
It opens a PR with the encrypted files under `secrets/tailscale`.
Required CI checks control the merge. The deployment process applies the merged files.
Resolve a failed rotation before the current enrollment key expires.
Do not put plaintext keys in Git, workflow output, artifacts or the Nix store.

Agenix decrypts the host enrollment key to `/run/agenix/tailscale-auth` with root-only access.
NixOS `services.tailscale.authKeyFile` selects that file.
A small service override passes the file path instead of the plaintext key to Tailscale.
It authenticates only when Tailscale reports `NeedsLogin`.
A connected host does not authenticate again when the enrollment key changes.
Keep `/var/lib/tailscale` across rebuilds. Current host device expiry is disabled.
Enrollment key expiry does not remove an enrolled device.
Do not force reauthentication or delete device state during deployment.

GitHub variables contain `TS_CLIENT_ID` and `TS_AUDIENCE`. Neither value is a secret.
The trust rule grants enrollment key access for `tag:exit-node`. It grants no device or policy write access.
Its subject is `repo:epk/dotfiles:ref:refs/heads/main`.
Its `workflow_ref` is `epk/dotfiles/.github/workflows/rotate-tailscale.yml@refs/heads/main`.
Its audience is `https://tailscale.com/epk/dotfiles/enrollment`.
Keep decrypted keys outside application agent access.

## New machines and guests

Each new machine requires a separate private key and public key.
Store its private key recovery copy in the operations vault.
Provision that private key through the trusted installer or VM provisioning process.
Do not give a guest the host or recovery private key.
Add the machine name, tags and public keys to `automation/tailscale-targets.json`.
Add a `tailscale/<name>.age` rule with the same `publicKeys` to `secrets/agenix-rules.nix`. CI checks that they are equal.
Extend the Tailscale trust rule only when the new machine requires another tag.
Merge these changes. The rotation workflow then opens a PR that adds the encrypted file.
After that PR merges, declare the file with `age.secrets` and select its path with `services.tailscale.authKeyFile`.
Declare its hostname and public options with `services.tailscale.extraUpFlags`.
Preserve its private key and Tailscale state on persistent storage.
The public repository alone cannot authenticate unknown hardware. Private key provisioning remains part of installation.

## Nix inputs and user configuration

The main package input is `nixpkgs-unstable`. `flake.lock` pins its exact revision.
Weekly lock updates open a PR. Required CI checks control the merge.
Channels are disabled. The Nix registry selects the pinned main nixpkgs input.
Dependency flakes can have separate package inputs.
`system.stateVersion` controls compatibility defaults. It does not select package updates.
The host uses `linuxPackages_latest` from the pinned package set.

Home Manager is not required on this minimal host.
NixOS declares the administrator account, shell, SSH access and system packages.
Home Manager remains part of the Mac configurations.
Add it to a development guest when that guest needs shared shell, Git or editor settings.

## Private metadata

The public flake uses `lib/example-metadata.json` for CI builds. The server example cannot switch a live system.
Agenix decrypts the private metadata to a root-only runtime file.
The native upgrade service passes this path through `DOTFILES_PRIVATE_CONFIG` and enables impure evaluation.
The service evaluates new code with the metadata of the previous activation.
CI does not decrypt metadata or receive private keys.
Keep machine-specific values outside public documentation.
Do not push a closure built with the private metadata to a cache.

To add a metadata key, use two PRs:

1. In the first PR, add the key to `secrets/private/metadata.age` and `lib/example-metadata.json`. Do not read the key in code.
2. After the server applies the first PR, merge a second PR with the code that reads the key.

CI evaluates the new server code with the example metadata of the current `main`.
CI cannot check the private metadata.
See [credentials](credentials.md) to edit the encrypted file.
If the server metadata is stale, see [recover the private metadata](server.md#recover-the-private-metadata).

Sources: [GitHub bot PR approval](https://github.blog/changelog/2026-06-11-bot-created-pull-requests-can-run-workflows-if-approved/), [Tailscale OIDC](https://tailscale.com/docs/features/workload-identity-federation), [enrollment keys](https://tailscale.com/docs/features/access-control/auth-keys).
