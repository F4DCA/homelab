#!/bin/bash
set -euo pipefail

export RESTIC_REPOSITORY="sftp:restic@192.0.2.20:/mnt/pool/restic-backups"
export RESTIC_PASSWORD_FILE="<redacted credential file>"
export RESTIC_CACHE_DIR="/var/cache/restic"

restic backup \
  /mnt/hdd/syncthing \
  /mnt/hdd/sftpgo \
  /mnt/hdd/immich \
  /mnt/hdd/suwayomi \
  --tag binds

restic forget --tag binds --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune
