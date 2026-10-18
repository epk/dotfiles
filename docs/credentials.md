# Credentials

## What each key does

Agenix uses a dedicated key pair for each host and guest. The Macs use no agenix key.
These keys decrypt encrypted repository files. They do not grant SSH login access.
Do not add their public keys to `authorized_keys`.

The host private key decrypts files encrypted for the host public key.
The recovery private key decrypts files encrypted for the recovery public key.
Recovery does not work for files that omit the recovery public key.

## Where keys are stored

Keep one record for each key in the operator-only 1Password operations vault.
Each record holds the key pair and notes for installation, use, recovery and rotation.

The host stores its private key at `/var/lib/agenix/identity`.
The file uses root ownership and mode 0600. Its directory uses mode 0700.
The host SSH key and Tailscale state remain separate.
Keep the recovery private key in the operations vault. Do not install it on hosts or application guests.

`secrets/recipients.nix` contains public keys only.
On the server, the option `age.identityPaths` selects the private key file.
Do not commit private keys or plaintext secrets.

## How services receive secrets

Create each credential with only the permissions its consumer needs.
Record its owner, purpose and rotation procedure in the operations vault.
Encrypt the service file for its consumer public key and the recovery public key.

1. Add the encrypted filename and `publicKeys` list to `secrets/agenix-rules.nix`.
2. Create the encrypted file with the pinned CLI command below.
3. Declare `age.secrets.<name>.file` in the consumer module.
4. Set `owner`, `group` and `mode` explicitly.
5. Pass `config.age.secrets.<name>.path` to the consumer.

```sh
AGENIX_RULES=secrets/agenix-rules.nix nix run .#agenix -- -e <name>.age
```

Filenames in the rules file are relative to its directory.
Agenix decrypts declared files into private runtime storage during NixOS activation.
Use mode 0400 for a file read directly by its service user.
For `LoadCredential`, keep the source root-owned with mode 0400.
Systemd supplies a private credential file to the service.
Do not put secret values in Nix expressions, derivations, command arguments, prompts or logs.

The declared secret is the Tailscale enrollment key.
See [server automation](automation.md) for the Tailscale secret and its replacement.
Declare each application secret only when its consumer exists.
The host does not need a live 1Password connection for boot or Tailscale access.

## Rebuilding and recovery

A normal server rebuild keeps its existing private key.
After a fresh installation, restore that existing private key from the operations vault before NixOS activation.
Use root ownership, file mode 0600 and directory mode 0700.
Check the restored public key with `sudo ssh-keygen -y -f /var/lib/agenix/identity`.
Compare it with `secrets/recipients.nix`.

Each new VM that uses agenix receives a separate key pair.
The trusted host provisioning process supplies guest keys without interactive vault access.
Keep recovery copies in the operations vault when the guest requires recovery.
Give the VM its own private key. Do not copy the host or recovery private key into it.
Before storing irreplaceable guest data, configure encrypted backups on another machine.

Use the recovery private key only through protected files or pipes during authorized recovery.
Remove temporary private key files after use.
Restore Tailscale state separately. These keys do not restore Tailscale access.

## When rotation is necessary

Replace a private key if it is exposed or its authorized use ends.
A normal rebuild does not require a new key pair.
After a public key change, re-encrypt affected files with the command below.

```sh
AGENIX_RULES=secrets/agenix-rules.nix nix run .#agenix -- -r -i <recovery-private-key-file>
```

Verify delivery before removing the previous key.
If a private key was exposed, rotate the actual credentials at their issuers.
Re-encryption does not revoke access to credentials recovered from old encrypted files.

## AI access

Agents can use public keys and encrypted files for authorized work.
Do not give application agents host or recovery private keys or direct access to the operations vault.
Do not expose private keys in prompts, chat, tool output or logs.

The current configuration does not install a vault reader, secret broker or 1Password service account.
