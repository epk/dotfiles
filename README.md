# dotfiles

This repository defines two macOS hosts and one NixOS host.

| Host | Platform | Use |
| --- | --- | --- |
| `macos-personal` | macOS / Apple Silicon | Personal workstation |
| `macos-work` | macOS / Apple Silicon | Workstation with Shopify tools |
| `server` | NixOS / x86_64 | Host storage and Nix VM support |

## Apply the configuration

For the first setup of a Mac, run this command with the role `personal` or `work`:

```sh
./setup.sh work
```

After the first setup, use `reload!`.

On the installed NixOS host, use this command:

```sh
sudo nixos-rebuild switch --flake /etc/nixos#server
```

See the [workstation instructions](docs/workstations.md) and [server instructions](docs/server.md).
See [workshop access](docs/workshop.md) for the persistent Paseo guest.
Keep access details and deployment status in the private inventory.

## Directories

- `hosts/`: machine definitions.
- `modules/darwin`: shared Mac configuration.
- `modules/home`: the shell, Git and CLI tools for every host. `dev.nix` adds the language toolchains for the Macs and the workshop guest. `darwin.nix` adds the GUI and macOS parts.
- `modules/nixos`: host and guest configuration.
- `profiles/`: work and personal configuration.
- `secrets/`: public keys, agenix rules and encrypted files.
- `packages/`: packages for the workshop guest.
- `checks/`: the flake checks that CI runs.

On macOS, use Home Manager for CLI tools. Use Homebrew for GUI applications.
The server and the workshop guest use Home Manager for the administrator shell (`modules/nixos/home.nix`).
Keep employer settings in the work profile. Apply Home Manager through nix-darwin.

## CI

CI runs the flake checks on Linux and on macOS. The checks are the host outputs, the workshop guest VM test, format, lint, policy and encrypted-file recipients.
CI builds the same outputs that the hosts apply. It does not decrypt secrets.
It builds only the checks that no cache holds. See [server automation](docs/automation.md#binary-cache).
CI does not activate hosts or test physical boot.
On a Mac, `nix flake check` runs the macOS checks. `nix flake check --all-systems --no-build` evaluates all outputs.
Renovate opens update PRs for the flake inputs, the GitHub Actions and the Antigravity release. CI must pass before automatic merge.
The server applies `main` each hour. Strict branch protection keeps only tested trees on `main`. See [server automation](docs/automation.md).

Use [ASD-STE100](https://www.asd-ste100.org/STE_faq.html) for repository text. See the [writing rules](docs/writing.md).
