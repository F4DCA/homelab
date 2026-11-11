#!/bin/bash
set -euo pipefail

export RESTIC_REPOSITORY="sftp:restic@100.64.0.13:/mnt/pool/restic-backups"
export RESTIC_PASSWORD_FILE="<redacted credential file>"
export RESTIC_CACHE_DIR="/var/cache/restic"

trap 'incus start --all' EXIT

incus stop --all --timeout 120

restic backup \
  /var/lib/incus/storage-pools/ssd/containers \
  /mnt/hdd/incus/storage-pools/default/containers \
  /mnt/hdd/agents \
  --tag incus

incus start --all

restic forget --tag incus --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune
