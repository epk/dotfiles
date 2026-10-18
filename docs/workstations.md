# Workstations

## Install Nix

Both macOS hosts use Determinate Nix.
Run the installer interactively. Examine its proposed changes before you confirm them.

```sh
curl -fsSL https://install.determinate.systems/nix | sh -s -- install
```

Before the first activation of `macos-personal`, sign in to the Mac App Store.
Homebrew Bundle uses `mas` to install the declared App Store applications.
The configuration of `macos-personal` replaces the `/etc/nix/nix.custom.conf` of the installer.
Before its first activation, run `sudo mv /etc/nix/nix.custom.conf /etc/nix/nix.custom.conf.before-nix-darwin`.

## Apply the configuration

Clone the repository to `~/src/github.com/epk/dotfiles`. `reload!` reads the repository at this path.
For the first setup, run `./setup.sh personal` or `./setup.sh work`. The script builds and activates that configuration.
After the first setup, use this command:

```sh
reload!
```

The command applies the system settings and Home Manager configuration together.
This flake does not define a separate `homeConfigurations` output.
If a file already exists, Home Manager moves it to a file with the `.before-nix` suffix.

The installed `reload!` of a Mac selects its output by name. After a rename of an output, run `./setup.sh <role>` on that Mac.

## Check a build

This command builds the configuration. It does not activate the Mac.
Use a GitHub token to increase the API request limit.

```sh
GH_TOKEN=$(gh auth token)
NIX_CONFIG="access-tokens = github.com=$GH_TOKEN" \
  nix build --no-link --print-out-paths .#darwinConfigurations.macos-personal.system
```

## Git email

The work profile sets the work email. The other hosts commit with the GitHub noreply address.
On the work Mac, commits in this repository also use the noreply address.

## Add a Mac

1. Add the role in `flake.nix` and a `hosts/macos-<role>` module with the `networking` names of the Mac.
2. Add `macos-<role>` to the `host` list in the CI matrix in `.github/workflows/check.yml`. Keep the list in alphabetical order.

Then run `./setup.sh <role>` on the Mac from a checkout that has these changes.
