You can migrate this Fedora 44 desktop cleanly, but the existing `desktop` NixOS configuration must not be installed unchanged.

The important mismatch is storage: Fedora currently uses Btrfs on `nvme0n1p3`, with separate `/boot` and `/boot/efi`; the checked-in NixOS hardware configuration expects an older LUKS/ext4 layout and encrypted swap with entirely different UUIDs.

## Recommended target

- Clean NixOS installation from USB—not an in-place conversion.
- Host: `desktop` / hostname `selipaq`.
- NixOS 26.05 installer, while retaining the repository’s pinned flake inputs during migration.
- UEFI with systemd-boot.
- LUKS2-encrypted Btrfs root.
- Btrfs subvolumes for `/`, `/home`, and `/nix`.
- Zram initially; no hibernation until a dedicated swap/resume design is tested.
- Preserve `/dev/sda1` and `/dev/sdb1` without repartitioning or formatting.
- First boot with a reduced configuration; enable Immich and optional virtualization afterward.

The official manual supports generating hardware configuration from the filesystems mounted during installation and installing a named flake output with `nixos-install --flake`. It also recommends systemd-boot for UEFI installations. [NixOS installation manual](https://nixos.org/manual/nixos/stable/)

## Migration plan

### 1. Prepare the repository

Before touching disks:

- Commit or separately save the current uncommitted content:
  - `.config/niri/config.kdl`
  - `.config/karukan-im/`
  - `.local/`
- Pin the exact migration state with a Git tag or commit.
- Do not run `nix flake update` during the migration.
- Regenerate `hosts/desktop/hardware-configuration.nix` during installation.
- Review the desktop configuration and temporarily gate:
  - Immich
  - VirtualBox
  - remote Nix builder
  - unusual udev rules
  - nonessential custom flake packages
- Build the exact system closure from Fedora before installation:

```bash
cd ~/dotfiles
nix flake check
nix build .#nixosConfigurations.desktop.config.system.build.toplevel
```

The check could not be completed from my sandbox because it cannot access your Nix daemon socket; that is not evidence of a flake error.

### 2. Create two independent backups

A Git clone alone is insufficient.

Back up:

- The complete 76 GB home directory
- SSH and GPG keys
- Browser profiles and password/keyring data
- Karukan/Fcitx dictionaries and configuration
- Git repositories with uncommitted changes
- VM images
- `/etc`, package list, enabled services, and disk metadata
- Immich database, media, and Compose configuration

Store at least one backup on media other than `sda` and `sdb`. Those disks are application data, not an adequate sole backup.

Record recovery information:

```bash
lsblk -f
sudo blkid
sudo sfdisk --dump /dev/nvme0n1
findmnt --real
```

For Immich, stop uploads, record the running version, take a logical database backup, and verify that several original photos can be read from the backup. Do not rely on copying PostgreSQL’s live data directory.

### 3. Perform a recovery rehearsal

Before erasing Fedora:

- Boot the NixOS USB in UEFI mode.
- Confirm Ethernet, Wi-Fi, keyboard, and both displays work.
- Confirm all three disks are visible with their expected sizes:
  - `nvme0n1`: OS disk, approximately 477 GB
  - `sda`: preserved 466 GB data disk
  - `sdb`: preserved 239 GB data disk
- Confirm you can unlock/read the backup.
- Keep the Fedora installer or another rescue USB available.

This is the point to stop if any disk identity is ambiguous.

### 4. Partition only the NVMe OS disk

The destructive target must be exactly `/dev/nvme0n1`.

Suggested layout:

| Partition | Size | Purpose |
|---|---:|---|
| ESP | 1 GiB | FAT32, mounted at `/boot` |
| Root | remainder | LUKS2 containing Btrfs |

Inside Btrfs, create subvolumes such as:

- `@root`
- `@home`
- `@nix`
- `@snapshots`

Use `compress=zstd` and `noatime`. Keep zram for the first installation. If hibernation is wanted later, add properly sized persistent swap and a tested resume configuration as a separate project.

Btrfs subvolume installation guidance is available in the [official NixOS Wiki](https://wiki.nixos.org/wiki/Btrfs).

### 5. Generate fresh hardware configuration

After mounting the new root and ESP under `/mnt`:

```bash
sudo nixos-generate-config --root /mnt
```

Copy only the newly generated hardware configuration into:

```text
hosts/desktop/hardware-configuration.nix
```

Verify that it references the new UUIDs and mount points. In particular:

- Root points to the new LUKS mapper/Btrfs filesystem.
- `/boot` points to the ESP.
- No old UUID beginning with `5c4ff8a1` or `82faf233` remains.
- `sda1` and `sdb1` appear only as preserved data mounts.
- The generated Intel CPU and initrd modules are retained.

### 6. Install a minimal first-boot system

Install from the pinned repository:

```bash
sudo nixos-install --flake /mnt/home/rei/dotfiles#desktop
```

Before rebooting, set the `rei` password and confirm that a boot entry exists.

The first configuration should provide only:

- Boot and storage
- NetworkManager
- User `rei`
- Fish or Bash
- SSH, if needed
- GNOME or one known-working session
- Home Manager essentials
- Intel graphics and audio
- Firewall

Do not make the first boot depend on Immich, VirtualBox, remote builders, Hazkey, or the full customized niri session.

### 7. First-boot acceptance gate

Do not restore application services until all of these pass:

- Two consecutive cold boots
- Root unlock and systemd-boot work
- Network and DNS work
- Audio input/output work
- Intel graphics acceleration works
- Sleep and resume work
- Japanese input works
- Screen sharing and portals work
- `sudo` and Git signing work
- `systemctl --failed` and `systemctl --user --failed` are empty or understood
- Both data disks mount at their intended fixed paths
- `nixos-rebuild test --flake ~/dotfiles#desktop` succeeds

NixOS retains prior generations in the boot menu, and a running system can use `nixos-rebuild switch --rollback`. [NixOS rollback documentation](https://nixos.org/manual/nixos/stable/)

### 8. Restore the desktop in layers

Enable one layer at a time:

1. Home Manager configuration and CLI tools
2. Niri, Waybar/Noctalia, notifications, clipboard, and portals
3. Fcitx5, Mozc/Hazkey, Karukan, and keyd
4. Tailscale and SSH
5. Libvirt
6. VirtualBox only if still needed
7. Remote Nix builder
8. Immich last

Use `nixos-rebuild test` before `switch` for risky changes.

The current configuration enables both GNOME and XFCE alongside niri, plus both libvirt and VirtualBox. I would trim those combinations after migration once you confirm what is still needed.

### 9. Restore Immich separately

Treat this as an application migration, not part of OS installation.

- Keep `sda1` and `sdb1` untouched.
- Bring NixOS up without Immich first.
- Decide whether to continue the current Docker Compose deployment or return to the native NixOS Immich service.
- Restore the exact existing Immich version first.
- Restore the logical database into a fresh database location.
- Preserve the old database directory until users, albums, originals, thumbnails, and videos are verified.
- Keep port 2283 restricted to localhost or `tailscale0`.
- Upgrade Immich only after the restored version is proven healthy.

### 10. Decommission Fedora backups later

Retain the Fedora backup and old Immich database for at least one or two weeks of normal use. Remove them only after:

- Several successful upgrades and reboots
- Suspend/resume testing
- A completed Immich backup-and-restore cycle
- Confirmation that no keys, browser data, or project files are missing

The two decisions to settle before implementation are whether full-disk encryption is desired and whether hibernation is required. My default recommendation is encrypted Btrfs plus zram, with hibernation deferred.
