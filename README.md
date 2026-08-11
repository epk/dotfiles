# dotfiles

Nix workstation configurations.

The realized hosts are:

- `adityas-shopitop`: shared workstation configuration plus Shopify hooks.
- `adityas-macbook-pro`: shared workstation configuration plus personal apps.

The target is a fast, minimal terminal with profile-specific hooks kept
explicit in the host/module graph.

## Layout

`flake.nix` supplies each host with `user` (account identity) and `host`
(machine identity); everything shared between machines lives in `modules/`.

- `modules/darwin` — system settings, the user account, Homebrew, and the
  Home Manager wiring that pulls in `modules/home`.
- `modules/home` — the shared user environment.
- `profiles/{work,personal}` — the employer- or personal-only additions.
- `hosts/*` — one host per directory, importing `modules/darwin` plus a profile.

## Package Boundary

- Command-line tools: Home Manager. Prefer a native `programs.*` module when
  one exists; otherwise add the package to `modules/home/packages.nix`.
- GUI apps: Homebrew casks in `modules/darwin/packages.nix`. Homebrew is also
  the fallback for CLI tools that are unavailable or unusable from nixpkgs.
- App Store apps: `homebrew.masApps`, which needs the `mas` formula.
- Homebrew itself is installed and migrated by `nix-homebrew`; packages are
  still declared through nix-darwin's `homebrew.*` options.

Keep the shared modules free of employer-specific or personal-only behavior.

Home Manager is intentionally managed through nix-darwin, not as a separate
standalone activation path. The normal switch command applies system settings,
Homebrew, fonts, macOS defaults, launchd services, and the Home Manager profile
together.

## Profiles

The shared zsh config is deliberately small: Home Manager enables zsh, default
Starship, history, and native shell integrations. The work profile adds TEC,
`/opt/dev/dev.sh`, Shopify kubeconfig wiring, and the `update-kubeconfig`
helper. The personal profile has no extra shell hooks.

## Fresh macOS install

Both hosts use Determinate Nix. Install it interactively so its proposed system
changes can be reviewed before confirmation:

```sh
curl -fsSL https://install.determinate.systems/nix | sh -s -- install
```

Sign into the Mac App Store before the first personal activation; Homebrew
Bundle uses `mas` to install the declared personal App Store apps.

## Apply

Use an authenticated GitHub token when evaluating or building so private or
rate-limited GitHub fetches do not fail:

```sh
GH_TOKEN=$(gh auth token)
NIX_CONFIG="access-tokens = github.com=$GH_TOKEN" \
  nix build --no-link --print-out-paths .#darwinConfigurations.adityas-macbook-pro.system
```

To activate the personal host:

```sh
GH_TOKEN=$(gh auth token)
NIX_CONFIG="access-tokens = github.com=$GH_TOKEN" \
  sudo -E nix run nix-darwin -- switch --flake .#adityas-macbook-pro
```

Replace `adityas-macbook-pro` with `adityas-shopitop` for the work host.

After the first activation, `nh` knows the flake path and becomes the usual
day-to-day command:

```sh
nh darwin switch
```

This repo does not expose a standalone `homeConfigurations` output. Use
`nh darwin switch` even for Home Manager changes so the machine is always
evaluated through the same host graph.

During activation, existing files that Home Manager now owns are moved aside
with the `.before-nix` extension.
