# server

`nixosConfigurations.server` defines the x86_64 NixOS host.
The host uses Determinate Nix and `linuxPackages_latest` from the pinned nixpkgs input.
The host runs SSH, Tailscale, DHCP, Nix and system maintenance.
Define each application in a guest or an explicit host module.

## Storage

`hosts/server/disko.nix` defines both SSDs by their disk IDs.
`/storage/nvme` and `/storage/sata` identify the two storage areas.
Each area contains `vms` and `artifacts`. SATA also contains `shares`.
These are local mount paths. [FHS defines `/srv` for served data](https://refspecs.linuxfoundation.org/FHS_3.0/fhs/ch03s17.html).

| Device | Dataset and mount | Capacity and use |
| --- | --- | --- |
| NVMe partition 1 | `/boot`, FAT32 EFI | 512 MiB |
| NVMe partition 4 | `@root` at `/`, `@nix` at `/nix` | 64 GiB shared host capacity |
| NVMe partition 2 | `@fast`, `@artifacts`, `@vms` under `/storage/nvme` | About 174 GiB for active VM disks and temporary artifacts |
| SATA partition 1 | `@data`, `@artifacts`, `@shares`, `@vms` under `/storage/sata` | 931 GiB for bulk data, retained artifacts and larger VM disks |
| VM subvolumes on either SSD | `@vms/<name>` | Shared capacity on the selected SSD |

NVMe SSD is faster for active VM state. SATA SSD has more capacity.
Use `/storage/nvme/vms/<name>/` for active guest state and databases.
Use `/storage/nvme/artifacts/` for temporary artifacts that need high throughput.
Use `/storage/sata/vms/<name>/` for larger guest data volumes.
Use `/storage/sata/artifacts/` for retained artifacts and `/storage/sata/shares/` for explicit host exports.
Each guest can use writable volumes on both SSDs.
The configuration does not move files automatically between SSDs.
Both SSDs contain persistent data. Neither SSD is an off-host backup.

All Btrfs mounts use `compress=zstd:1`, `noatime` and `discard=async`.
CoW and data checksums stay enabled. The configuration keeps the default durability settings.
The configuration does not enable NOCOW or automatic defragmentation.

The physical 64 GiB partition limits the combined host capacity, including root, Nix and `/var`.
Root and Nix subvolumes share this limit. The configuration does not use qgroups.
VM disks and bulk artifacts cannot consume this host capacity.
The system journal has a 256 MiB limit. The boot loader retains a maximum of five system entries.
Keep at least 4 GiB free on the host filesystem before builds or updates.
Store large build workspaces and temporary artifacts on `/storage/nvme/artifacts/`.
Use a larger guest volume for builds that exceed the host capacity.
Check `df -h / /nix` and `sudo btrfs filesystem usage /`.
Remove unused system generations and collect unreferenced store paths when necessary.
Keep GC roots for guest closures before store collection.
The 64 GiB limit controls host capacity; it does not guarantee space for an arbitrary build.

The host runs TRIM each week and Btrfs scrubs each month.
Scrubs cover each filesystem once: the host partition, fast storage and SATA data.
A single-SSD filesystem detects corrupt data but needs another good copy to restore that data.
The configuration does not create snapshots.

A system rebuild applies mount settings.
Disko formatting is a separate installation operation that deletes disk contents.

## Backups

Before you store data that you cannot replace, configure encrypted backups on another machine.
Test the restore procedure before you deploy stateful guests.
Include these items in the backup:

- Application data and guest disks.
- Artifacts and the required Nix closures or source files.
- SSH host keys, `/etc/machine-id` and Tailscale identity state.

Stop each VM, or stop its application writes, before you copy its writable disk.
Keep the recovery private key in the operations vault.
This configuration does not define a backup destination.

## Apply the configuration

CI deploys `main` to the host. See [server automation](automation.md#deployment).
To apply a configuration by hand, run this command:

```sh
sudo nixos-rebuild switch --flake github:epk/dotfiles#server
```

SSH listens on all interfaces and accepts key login only. Use Tailscale to connect from outside the local network.
Activation keeps the current Tailscale and DHCP connections.
Deployment does not reboot the host. Reboot the host by hand after a kernel update.
Keep `/var/lib/tailscale` and the SSH host keys.
Do not put enrollment keys or private credentials in Git, command arguments or the Nix store.
See [server automation](automation.md) for deployment, Tailscale enrollment and Nix input updates.


## Nix guests

`modules/nixos/microvm-guest.nix` defines the shared guest settings.
These settings are the latest kernel, no NixOS manual and the state version.
Each guest selects its hypervisor, resources, store access and disks.

Define each guest through `microvm.vms`.
Keep GC roots for all guest closures that remain in use.
The storage module rejects `microvm.shares`, so the host exports no directory to a guest.
A guest gets its store from a disk image. Do not put secrets in the store.
If a guest needs a writable store overlay, use a private guest block volume.
Treat the overlay as temporary build state unless its Nix database has an explicit persistence policy.

Before you deploy an application guest, define its identity, network policy, resource limits and credentials.
The host enables the persistent Firecracker agent guest. See [workshop access and storage](workshop.md).
That guest uses a read-only EROFS system image.

## Guest disks and I/O

`modules/nixos/microvm-storage.nix` creates a private Btrfs subvolume and host user for each declared VM.
The host uses `truncate` to create sparse raw images.
It formats ext4 inside each image without fallocate preallocation.
The disk size applies only when the host creates the image. A later change does not resize an existing disk.

The upstream disk creator sets `chattr +C`.
The storage module asserts `autoCreate = false` for each writable disk to keep CoW, data checksums and compression.
The host rejects existing NOCOW disks.
Root owns each VM state directory and disk directory.
Each VM user owns only its sparse raw images and the `run` directory that holds the VMM API socket.

Writable disks must have these settings:

- `imageType = "raw"` and `fsType = "ext4"`.
- `direct = false` and `autoCreate = false`.
- An image path under `/storage/nvme/vms/<vm-name>/` or `/storage/sata/vms/<vm-name>/`.

The workshop guest gives each Firecracker drive the `Sync` I/O engine.
The writable drives use the `Writeback` cache type, which passes guest flushes to the host.
See `modules/nixos/guests/workshop.nix`.
The configuration does not suppress flush requests.
Guest ext4 keeps its default journal and write barriers.
The workshop guest has no TRIM. The pinned Firecracker release does not support guest TRIM.
Host TRIM still runs and releases unused SSD blocks.

Btrfs compresses data when compression reduces its size.
The [Btrfs documentation](https://btrfs.readthedocs.io/en/latest/Compression.html) describes a kernel change:

- Before kernel 7.3, checksummed direct writes use buffered I/O and can compress data.
- From kernel 7.3, direct writes do not compress data.

Buffered I/O keeps host compression independent of this direct-write change.
Preallocated files and NOCOW files do not provide this compression policy.
Guest boot performance depends on the guest configuration.

## Credentials

See the [credential instructions](credentials.md).
