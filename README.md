# dotfiles

Nix workstation configurations.

The current realized host is `adityas-shopitop`. The target is a fast, minimal
terminal with host-specific hooks kept explicit in the host/module graph.

## Package Boundary

Package ownership is intentionally consolidated in
`modules/darwin/packages.nix`:

- Nix terminal binaries: command-line tools used from the shell, including
  `kubectl`, `gcloud`, `gh`, `op`, `go`, `node`, `pnpm`, `ripgrep`, `tenv`,
  and `nano`. Git, zsh, and Starship are managed through their Home Manager
  program modules.
- Nix GUI applications: currently empty.
- Homebrew GUI casks: signed macOS apps where Homebrew is the pragmatic source,
  currently `1password`, `appcleaner`, `ghostty`, `rectangle`, `tuple`, and
  `visual-studio-code`.
- Homebrew binary casks/formulae: intentionally empty. Add here only when a CLI
  is unavailable or unusable from nixpkgs.
- Homebrew itself: installed and migrated by `nix-homebrew`; packages are still
  declared through nix-darwin's `homebrew.*` options.

## Shell

The zsh config is deliberately small: Home Manager enables zsh, default
Starship, history, `/opt/dev/dev.sh`, Shopify kubeconfig wiring, and the
`update-kubeconfig` helper.

## Apply

Use an authenticated GitHub token when evaluating or building so private or
rate-limited GitHub fetches do not fail:

```sh
GH_TOKEN=$(gh auth token)
NIX_CONFIG="access-tokens = github.com=$GH_TOKEN" \
  nix build --no-link --print-out-paths .#darwinConfigurations.adityas-shopitop.system
```

To activate the current host:

```sh
GH_TOKEN=$(gh auth token)
NIX_CONFIG="access-tokens = github.com=$GH_TOKEN" \
  sudo -E nix run nix-darwin -- switch --flake .#adityas-shopitop
```

During activation, existing files that Home Manager now owns are moved aside
with the `.before-nix` extension.
