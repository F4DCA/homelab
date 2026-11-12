# Verbatim host files

Copies of hand-written host configuration, taken from the root audit of 2026-11-10 or read
from the host afterwards.
Paths under each host directory mirror the original absolute path.

| Host | Copied |
| --- | --- |
| PG15 | `/etc/network/interfaces`; CT 100, CT 101 and CT 102 interface files; `pbs-binds.sh`; `restic-binds.sh`; `nvidia-init`, `pbs-binds` and `restic-binds` units; CT 202 embedding unit |
| X99A | `llama-server` units; `netbird`; `snapraid-aio`; Strata and embed user units |
| dv6 | `/etc/network/interfaces`; the `restic-containers` unit, timer and script |

The remaining PG15 containers use the default static `eth0` configuration and are not
duplicated here. The effective addresses are in [`../../docs/architecture.md`](../../docs/architecture.md).

The SnapRAID AIO script itself is upstream v3.4 from `auanasgheps/snapraid-aio-script`; only
its unit and timer are copied. The audit did not capture its
`/opt/snapraid-aio-script/script-config.conf`, so where it sends notifications is recorded in
[the architecture notes](../../docs/architecture.md#notifications) instead.
