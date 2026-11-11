#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="vaultwarden"

VW_DATA_DIR="/home/rvaitpros/stacks/vaultwarden/vw-data"

LOCAL_BACKUP_DIR="/var/backups/vaultwarden"
ARCHIVE_NAME="vaultwarden-nightly.tar.gz"

RCLONE_CONFIG="/home/rvaitpros/stacks/rclone/config/rclone.conf"
RCLONE_DEST="gdrive:VaultwardenBackups"


TEMP_DIR=$(mktemp -d /tmp/vw-backup-XXXXXX)
mkdir -p "${LOCAL_BACKUP_DIR}"
chmod 700 "${LOCAL_BACKUP_DIR}"

cleanup() {
	rm -rf "${TEMP_DIR}"
}
trap cleanup EXIT

echo "[$(date)] Starting Vaultwarden backup...."

docker exec "${CONTAINER_NAME}" /vaultwarden backup

LATEST_SQLITE=$(ls -t "${VW_DATA_DIR}"/db_*.sqlite3 | head -n1)
cp "${LATEST_SQLITE}" "${TEMP_DIR}/db.sqlite3"
rm -f "${LATEST_SQLITE}"

[ -f "${VW_DATA_DIR}/config.json" ] && cp "${VW_DATA_DIR}/config.json" "${TEMP_DIR}/"
cp -r "${VW_DATA_DIR}"/rsa_key* "${TEMP_DIR}/" 2>/dev/null || true
[ -d "{VW_DATA_DIR}/attachments" ] && cp -r "${VIEW_DATA_DIR}/attachments" "${TEMP_DIR}/"
[ -d "${VW_DATA_DIR}/sends" ] && cp -r "${VW_DATA_DIR}/sends" "${TEMP_DIR}/"

tar -czf "${LOCAL_BACKUP_DIR}/${ARCHIVE_NAME}.tmp" -C "${TEMP_DIR}" .
mv -f "${LOCAL_BACKUP_DIR}/${ARCHIVE_NAME}.tmp" "${LOCAL_BACKUP_DIR}/${ARCHIVE_NAME}"
chmod 600 "${LOCAL_BACKUP_DIR}/${ARCHIVE_NAME}"

echo "[$(date)] Uploading archive to Google Drive..."
rclone --config "${RCLONE_CONFIG}" copyto "${LOCAL_BACKUP_DIR}/${ARCHIVE_NAME}" "${RCLONE_DEST}/${ARCHIVE_NAME}"

echo "[$(date)] Vaultwarden backup and cloud sync competed successfully."
