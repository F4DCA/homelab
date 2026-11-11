#!/bin/bash
set -euo pipefail

set -a
source <redacted credential file>
set +a

proxmox-backup-client backup \
  syncthing.pxar:/mnt/hdd/syncthing \
  sftpgo.pxar:/mnt/hdd/sftpgo \
  hermes-agent.pxar:/mnt/hdd/hermes-agent \
  immich.pxar:/mnt/hdd/immich \
  suwayomi.pxar:/mnt/hdd/suwayomi \
  --repository root@pam@100.64.1.11:8007:pg15
