# Workstations

## Install Nix

Both macOS hosts use Determinate Nix.
Run the installer interactively. Examine its proposed changes before you confirm them.

```sh
curl -fsSL https://install.determinate.systems/nix | sh -s -- install
```

Before the first activation of `macos-personal`, sign in to the Mac App Store.
Homebrew Bundle uses `mas` to install the declared App Store applications.

## Apply the configuration

Clone the repository to `~/src/github.com/epk/dotfiles`. `reload!` reads the repository at this path.
For the first setup, copy the agenix private key of the Mac from 1Password. Then run `./setup.sh`.
The script selects the Mac role from the key. It installs the key at `/var/lib/agenix/identity` and activates the configuration.
It clears the clipboard when it ends.
After the first setup, use this command:

```sh
reload!
```

The command applies the system settings and Home Manager configuration together.
This flake does not define a separate `homeConfigurations` output.
If a file already exists, Home Manager moves it to a file with the `.before-nix` suffix.

The installed `reload!` of a Mac selects its output by name. CI refuses a PR that removes a deployed Mac output.
To rename or remove an output, add the old name to `retired` in `.github/check-live.nix`.
After the merge, run `./setup.sh` again on that Mac.

## Check a build

This command builds the example variant. It does not activate the Mac.
Use a GitHub token to increase the API request limit.

```sh
GH_TOKEN=$(gh auth token)
NIX_CONFIG="access-tokens = github.com=$GH_TOKEN" \
  nix build --no-link --print-out-paths .#darwinConfigurations.macos-personal.system
```

## Private metadata

`secrets/private/metadata.age` contains machine-specific values.
`reload!` decrypts it with the Mac key at `/var/lib/agenix/identity` to a temporary file. It removes the file after the build.
`macos-personal`, `macos-work` and `server` are public output names. The machines keep their names from the metadata.
The public example uses neutral values for CI. It refuses live activation without the private metadata.
Do not put plaintext credentials in the metadata file.
To edit the file, see [credentials](credentials.md#private-metadata).

## Add a Mac

1. Create an agenix key pair for the Mac. Store the private key in 1Password.
2. Add the role in `flake.nix` and a `hosts/macos-<role>` module.
3. Add the public key to `secrets/recipients.nix` as `macos-<role>` and to the `private/metadata.age` rule in `secrets/agenix-rules.nix`.
4. Add `workstations.<role>` to `lib/example-metadata.json` and to the encrypted metadata. Re-encrypt `metadata.age` with the recovery key.
5. Add `macos-<role>` to the `host` list in the CI matrix in `.github/workflows/check.yml`. Keep the list in alphabetical order.

Then run `./setup.sh` on the Mac from a checkout that has these changes.
