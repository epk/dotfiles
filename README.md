# dotfiles

Declarative macOS and NixOS configurations.

## Apply the configuration

For the first Mac setup, select `personal` or `work`:

```sh
./setup.sh personal
```

After setup, use `reload!`. CI deploys `main` to the server through Cachix Deploy.

## Map of the repository

```
flake.nix                    Start here. It defines the three machines.
│
├─ macos-personal ─────────► hosts/macos-personal/default.nix
├─ macos-work ─────────────► hosts/macos-work/default.nix, home.nix
└─ server ─────────────────► hosts/server/*.nix
                                   │
                 Each host imports shared modules:
                                   ▼
modules/
├─ darwin/                   The Mac system: apps, Homebrew and macOS preferences
├─ home/                     Your user on every machine: shell, Git, CLI tools and toolchains
└─ nixos/                    The Linux server
   ├─ base.nix, server.nix, server-automation.nix, home.nix    the host
   ├─ workshop/              the coding VM: host.nix, guest.nix, tools.nix
   ├─ vpn/                   the WireGuard container: host.nix, guest.nix
   └─ microvm/               guest networks and disks, for workshop and vpn

packages/                    Apps that nixpkgs does not have, or has at an older version
├─ overlay.nix               Adds each app to pkgs, so that modules can use pkgs.<name>
└─ <app>/default.nix         The build of one app. release.json or package.json pins its version.

lib/                         Shared values: your name and key, cache URLs and network ranges
checks/                      Tests that CI runs: format, lint, policy and a VM boot test
secrets/                     Encrypted keys and the rules for who can decrypt them
.github/                     The CI workflow and Renovate, which updates the versions
```

Each file starts with one comment line. That line says what the file does and which file imports it.

## Where to make a change

| Change | File |
|---|---|
| A CLI tool on every machine | `modules/home/packages.nix` |
| A language toolchain | `modules/home/dev.nix` |
| A Mac app on both Macs | `modules/darwin/packages.nix` |
| A Mac app on one Mac | `hosts/macos-personal/default.nix` or `hosts/macos-work/default.nix` |
| Shell, Git, SSH or Ghostty settings | `modules/home/shell.nix`, `git.nix`, `ssh.nix` or `ghostty.nix` |
| macOS preferences | `modules/darwin/macos-defaults.nix` |
| A tool in the workshop VM | `modules/nixos/workshop/guest.nix` or `tools.nix` |
| A newer version of a pinned app | Renovate does this. It edits `packages/<app>/release.json`. |

An unfree app also needs its name in `allowUnfreePredicate` in `modules/darwin/default.nix`.

## Test a change

1. Run `nix flake check --all-systems --no-build`. This evaluates every machine without a build.
2. On a Mac, run `reload!` to build and apply the change.
3. Push a branch. CI builds the server and runs the VM test.

## Operations in Notion

- [Mac setup](https://app.notion.com/p/3f42dfc5083e81578892e808c2bfdc28)
- [Server operations](https://app.notion.com/p/3f92dfc5083e81ac943bf47ef6e53fcd)
- [Guest access](https://app.notion.com/p/3f92dfc5083e815a8f98f88829b13848)

The Nix modules define behavior. Keep operational instructions and private inventory in Notion.
