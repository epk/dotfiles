# Automation

## Workflows

`check.yml` runs on pushes to all branches. It is the only workflow.

Renovate, the hosted Mend app, opens the update PRs. Its configuration is `.github/renovate.json`.

- It updates `flake.lock` each Monday.
- It updates the GitHub Actions pins 7 days after each release. A major version needs a manual merge.
- It updates `packages/antigravity-release.json` to the latest Antigravity release and its checksum.

Renovate pushes as an app, so its pushes start CI. Its PRs merge automatically after the required checks pass.
Renovate rebases a PR that falls behind `main`. The Dependency Dashboard issue lists pending updates.

## Required checks

A PR merges only after these checks pass:

- `linux`: evaluates all outputs and builds the `x86_64-linux` checks.
- `darwin`: builds the `aarch64-darwin` checks.

The checks include `server`, `macos-personal` and `macos-work`.

## Binary cache

CI uploads the output of each check that it builds to the public Cachix cache `epk`. Cachix does not store paths that cache.nixos.org holds.
`lib/cachix.nix` holds the cache address and public key.
The repository secret `CACHIX_AUTH_TOKEN` grants write access.
`nix-fast-build --skip-cached` builds only the checks that neither cache holds. An unchanged check costs no build and no download.
The server and the Macs use the cache as an extra substituter. Nix accepts a path from it only with the signature of the cache key.
The work Mac adds it in `~/.config/nix/nix.conf`, because Shopify's `/etc/nix/nix.conf.d/shopify.conf` makes the user trusted.
The personal Mac adds it in `/etc/nix/nix.custom.conf` through the Determinate nix-darwin module.
Only pushes to this repository run CI with the token. You and Renovate can push.
The free plan holds 5 GiB. At the limit, Cachix removes the least recently used paths.

## Deployment

Branch protection on `main` is strict. A PR merges only when it is up to date with `main` and its required checks pass.
So `main` holds only trees that CI tested.
After the checks pass on `main`, the `deploy` job sends the server closure to the Cachix Deploy agent of the server.
The agent is in the workspace `epk`. `secrets/cachix/agent.age` holds its token.
The `deploy` GitHub environment holds `CACHIX_ACTIVATE_TOKEN`. Only protected branches can use it, and `main` is the only one.
The agent downloads the closure, activates it and then must reach Cachix within 10 seconds. If it cannot, it rolls back.
The job waits for the result. A failed or rolled-back deployment makes the `main` run fail.

The server does not evaluate or build its configuration. Deployment does not update inputs, collect system generations, reboot or format disks.
The boot loader selects the new kernel at the next reboot.
The host preserves the running Tailscale service during activation.
GitHub receives no administrator SSH key or host private key.
See the deployment history at `https://app.cachix.org/deploy/workspace/epk`. On the host, use `systemctl status cachix-agent`.

To roll back, run this command on the host. Then open a revert PR.

```sh
sudo nixos-rebuild switch --rollback
```

If CI fails, the PR does not merge and the host does not change.
If Cachix is not available, the host keeps its configuration. To apply `main` by hand, run `sudo nixos-rebuild switch --flake github:epk/dotfiles#server`.

## Tailscale enrollment

The host logs in to Tailscale only when it has no login. The upstream `tailscaled-autoconnect` service runs `tailscale up` in that case.
A connected host does not log in again. Keep `/var/lib/tailscale` across rebuilds. Host device expiry is disabled.

`secrets/tailscale/server.age` holds a Tailscale OAuth client secret, followed by `?ephemeral=false&preauthorized=true`.
The client has only the `auth_keys` scope and the tag `tag:exit-node`. The secret does not expire.
Agenix decrypts it to `/run/agenix/tailscale-auth` with root-only access.
`services.tailscale.authKeyFile` contains only `file:` and that path, so the secret does not appear in process arguments.
CI checks that the upstream service still reads the key this way.

To replace the secret, do these steps:

1. Create a new OAuth client in the Tailscale admin console with the same scope and tag.
2. Run `rm secrets/tailscale/server.age`.
3. Run `AGENIX_RULES=secrets/agenix-rules.nix nix run .#agenix -- -e tailscale/server.age` and enter the new secret.
4. Merge the change. After the host applies it, revoke the old client.

If the host private key or the recovery private key is exposed, revoke the client at once.

## New machines and guests

Each new machine requires a separate private key and public key.
Store its private key recovery copy in the operations vault.
Provision that private key through the trusted installer or VM provisioning process.
Do not give a guest the host or recovery private key.
Add a `tailscale/<name>.age` rule with the machine and recovery public keys to `secrets/agenix-rules.nix`.
Create the file with the agenix command above and an OAuth client secret for the tags of the machine.
Declare the file with `age.secrets` and set `services.tailscale.authKeyFile` as `modules/nixos/server-automation.nix` does.
Declare its hostname and public options with `services.tailscale.extraUpFlags`.
Preserve its private key and Tailscale state on persistent storage.
The public repository alone cannot authenticate unknown hardware. Private key provisioning remains part of installation.

## Nix inputs and user configuration

The main package input is `nixpkgs-unstable`. `flake.lock` pins its exact revision.
Renovate opens a lock update PR each week. Required CI checks control the merge.
Channels are disabled. The Nix registry selects the pinned main nixpkgs input.
Dependency flakes can have separate package inputs.
`system.stateVersion` controls compatibility defaults. It does not select package updates.
The host uses `linuxPackages_latest` from the pinned package set.

The administrator accounts on the host and the workshop guest use zsh and the shared Home Manager configuration.
`modules/nixos/home.nix` applies it. NixOS declares the accounts, SSH access and system packages.

## Public values and secrets

The flake evaluates without `--impure`. Machine names, usernames, email addresses, public keys and disk IDs are plain Nix values.
CI builds the same server closure that it deploys.
Agenix holds the Tailscale secret and the Cachix agent token. See [credentials](credentials.md).

Sources: [Renovate Nix manager](https://docs.renovatebot.com/modules/manager/nix/), [Renovate automerge](https://docs.renovatebot.com/key-concepts/automerge/), [Tailscale OAuth clients](https://tailscale.com/docs/features/oauth-clients), [enrollment keys](https://tailscale.com/docs/features/access-control/auth-keys).
