# The other three machines

`PG15` gets its own document. The rest of the lab is three machines doing three jobs: X99A
is bulk storage and the compute box, the B860H answers DNS, and dv6 is the offsite copy.

## Addresses

| Machine | LAN | Mesh | Role |
|---|---|---|---|
| X99A | `192.0.2.20` | `100.64.0.13` | Bulk storage, LAN-side backup server, compute |
| B860H | `192.0.2.30` | `100.64.0.12` | Pi-hole and unbound |
| dv6 | `198.51.100.10` | `100.64.1.11` | Offsite backup server, Syncthing, authoring container |
| `x99a-pbs` | `192.0.2.21` | none | Proxmox Backup Server on X99A, port `8007` |
| `compute` | `192.0.2.22` | none | Build container on X99A, SSH 22, `ssh compute` |
| `agents-dv6` | `198.51.100.11` | `100.64.1.12` | Authoring container on dv6, SSH 22 |
| `routefinder` | `198.51.100.12` | none | Public-transport route search on `:8000` |
| `overleaf` | `198.51.100.13` | none | Overleaf on `:7777`, reachable from the internet through the tunnel |

The two LANs are reached from the mesh through CT 100 on `PG15`; see [network.md](network.md).

## X99A

An ex-workstation: Intel Xeon E5-2696v4, 22 cores and 44 threads, 64 GB RAM, Arch Linux. It
dual-boots Windows from the same NVMe.

Seven disks: a 512 GB NVMe for both operating systems and the Incus pool, a 240 GB SATA SSD
that Windows uses, a 320 GB and a 1 TB HDD, and three 500 GB HDDs. Bulk storage is a
mergerfs union at `/mnt/pool` over three of them (`/mnt/static`, `/mnt/scratch1`,
`/mnt/scratch2`), with `/mnt/parity` as SnapRAID parity. The array has three data disks and
one parity disk, and its check runs daily at 04:00. The 1 TB disk at `/mnt/shared` is NTFS
and shared with the Windows install; it is not in SnapRAID.

Two Incus guests:

- `proxmox-backup-server`, storage ID `x99a-pbs`, at `192.0.2.21:8007`, datastore `pg15`.
  This is the LAN-side backup target, reachable from `PG15` without the mesh.
- `agents`, documented as `compute`, at `192.0.2.22`. It shares the host's chassis, CPU and
  disks, is allocated 20 cores and 24 GB, and has an RX 6700 XT passed through. Heavy jobs
  (builds, test suites, package installs) run there over `ssh compute`.

The host also runs Strata on `:8080`, serving a Qwen3.6 model, and keeps an Immich
machine-learning container on `:3003` that was stopped on 2026-11-10. `smartd` there posts
to the `smartd-x99a` topic, and the SnapRAID script posts its start and completion messages
to `snapraid-x99a`.

The restic destination lives on this machine too: `/mnt/pool/restic-backups`, reached over
SFTP. Restic snapshots of `PG15`'s bind mounts therefore sit on the same pool they protect.

## B860H

A ZTE ZXV10 B860H v2, an Android TV box running Armbian with an Amlogic S905X (4× Cortex-A53),
2 GB RAM and 8 GB eMMC. It exists to answer DNS: Pi-hole v6 in front of unbound on
`127.0.0.1:5335` over DNS-over-TLS, with the same configuration as the pair on dv6 since
October 2026. It advertises no subnet on the mesh, and it offers exit-node capability that
nothing selects.

## dv6

The offsite machine: a 2011 laptop running Debian 13 on an Intel Core i7-2720QM with 16 GB
RAM. The root filesystem is an LVM volume of about 110 GB; the 1 TB data disk is mounted at
`/mnt/hdd`.

| Service | Listener | Notes |
|---|---|---|
| Proxmox Backup Server | `:8007` | datastore `pg15`, consumed by `PG15` as storage `dv6-pbs` over the mesh |
| Pi-hole and unbound | `:53`, web `:80`/`:443`, NTP `:123` | the offsite resolver; unbound on `127.0.0.1:5335` over DoT, same pair as the B860H |
| Incus | none | containers `agents`, `routefinder`, `overleaf`; storage pools `default` and `ssd` |
| Syncthing | `:8384` | runs as `operator`, data in `/mnt/hdd/syncthing` |
| restic | timer, daily 00:30 | stops every Incus container, copies their storage to X99A, starts them again |
| NetBird | none | client, and a peer for `192.0.2.0/24` |
| smartd | none | posts disk-health warnings to the `smartd-dv6` topic |
| Podman | none | installed, no containers, no quadlets |

Pi-hole answers DNS for the whole offsite LAN, not just for the host. A query sent from
`agents-dv6` proves less than it looks, because that container shares the host's kernel and
reaches Pi-hole over the Incus bridge rather than the physical network.

One disk serves two purposes: `/dev/sdb1` is mounted both at `/mnt/hdd` and at
`/var/lib/incus/storage-pools/default`, so the Incus guests and the PBS datastore share a
single physical device. Losing that disk loses both the containers and the backups of
`PG15`. The second pool, `ssd`, is a plain directory under `/var/lib/incus` rather than a
mount, so whatever lives in it sits on the 110 GB root volume.

`agents-dv6` is the authoring container, with one snapshot and the repository checkout.
`routefinder` serves a regional public-transport route search. `overleaf` runs Overleaf on
`:7777` and is one of the two services published to the internet.

## What backs up what

Three machines, four jobs:

- `x99a-pbs` on the LAN: Proxmox guests, `keep-all=1`.
- `dv6-pbs` over the mesh: the same guests, a second copy that survives losing X99A.
- restic on X99A: the bind-mounted directories that a guest snapshot does not carry.
- restic on dv6: the Incus container storage, daily at 00:30, into the same X99A
  repository under tag `incus`.

dv6's job stops every container before it starts copying and restarts them when it exits,
so the containers are down for as long as the backup runs. It backs up
`/var/lib/incus/storage-pools/ssd/containers`,
`/mnt/hdd/incus/storage-pools/default/containers` and `/mnt/hdd/agents`.

The big pool on X99A has no healthy copy of its own. It is the restic destination, and its
own backup goes to dv6. The figures here come from a root audit of each host on 2026-11-10.
