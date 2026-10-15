# dotfiles

This repository defines two macOS hosts and one NixOS host.

| Host | Platform | Use |
| --- | --- | --- |
| `macos-personal` | macOS / Apple Silicon | Personal workstation |
| `macos-work` | macOS / Apple Silicon | Workstation with Shopify tools |
| `server` | NixOS / x86_64 | Host storage and Nix VM support |

## Apply the configuration

For the first setup of a Mac, copy the agenix private key of the Mac from 1Password. Then run this command:

```sh
./setup.sh
```

After the first setup, use `reload!`.

On the installed NixOS host, use this command:

```sh
sudo env DOTFILES_PRIVATE_CONFIG=/run/agenix/private-metadata nixos-rebuild switch --impure --flake /etc/nixos#server
```

See the [workstation instructions](docs/workstations.md) and [server instructions](docs/server.md).
See [workshop access](docs/workshop.md) for the persistent Paseo guest.
Keep access details and deployment status in the private inventory.

## Directories

- `hosts/`: machine definitions.
- `modules/darwin`, `modules/home`: shared workstation configuration.
- `modules/nixos`: host and guest configuration.
- `profiles/`: work and personal configuration.
- `lib/`: the private metadata loader and the neutral example values.
- `secrets/`: public keys, agenix rules and encrypted files.
- `packages/`: packages for the workshop guest.
- `automation/`: scripts for the scheduled workflows.
- `checks/`: the flake checks that CI runs.

On macOS, use Home Manager for CLI tools. Use Homebrew for GUI applications.
The minimal NixOS host does not use Home Manager.
Keep employer settings in the work profile. Apply Home Manager through nix-darwin.

## CI

CI evaluates all outputs and runs the flake checks: format, lint, policy and encrypted-file recipients.
CI uses the neutral values in `lib/example-metadata.json`. It does not decrypt the private metadata.
Linux builds `server` as `nixos-upgrade` builds it. A VM test starts the workshop guest services.
On macOS, CI runs `setup.sh`, `reload!` and the deployed `reload!` for each Mac with a throwaway key.
CI does not activate hosts or test physical boot.
Run the same evaluation and checks on a Mac with `nix flake check --all-systems --no-build` and `nix flake check`.
Weekly flake updates open a PR. CI must pass before automatic merge.
The server applies `main` each hour. Strict branch protection keeps only tested trees on `main`. See [server automation](docs/automation.md).

Use [ASD-STE100](https://www.asd-ste100.org/STE_faq.html) for repository text. See the [writing rules](docs/writing.md).
