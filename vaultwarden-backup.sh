#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="vaultwarden"
STACK_DIR="/home/rvaitpros/stacks/vaultwarden"
VW_DATA_DIR="${STACK_DIR}/vw-data"

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

echo "[$(date)] Starting Vaultwarden backup..."

docker exec "${CONTAINER_NAME}" /vaultwarden backup

LATEST_SQLITE=$(ls -t "${VW_DATA_DIR}"/db_*.sqlite3 | head -n1)
cp "${LATEST_SQLITE}" "${TEMP_DIR}/db.sqlite3"
rm -f "${LATEST_SQLITE}"

[ -f "${STACK_DIR}/docker-compose.yml" ] && cp "${STACK_DIR}/docker-compose.yml" "${TEMP_DIR}/"
[ -f "${STACK_DIR}/.env" ] && cp "${STACK_DIR}/.env" "${TEMP_DIR}/"
[ -d "${STACK_DIR}/ssl" ] && cp -r "${STACK_DIR}/ssl" "${TEMP_DIR}/"
[ -f "${VW_DATA_DIR}/config.json" ] && cp "${VW_DATA_DIR}/config.json" "${TEMP_DIR}/"
cp -r "${VW_DATA_DIR}"/rsa_key* "${TEMP_DIR}/" 2>/dev/null || true
[ -d "${VW_DATA_DIR}/attachments" ] && cp -r "${VW_DATA_DIR}/attachments" "${TEMP_DIR}/"
[ -d "${VW_DATA_DIR}/sends" ] && cp -r "${VW_DATA_DIR}/sends" "${TEMP_DIR}/"

# 1. Build the new archive in a staging path
STAGED_ARCHIVE="${LOCAL_BACKUP_DIR}/${ARCHIVE_NAME}.tmp"
tar -czf "${STAGED_ARCHIVE}" -C "${TEMP_DIR}" .

# 2. Verify archive integrity and non-zero size before touching local or remote backups
echo "[$(date)] Verifying archive integrity..."
[ -s "${STAGED_ARCHIVE}" ]
tar -tzf "${STAGED_ARCHIVE}" > /dev/null

# Also check SQLite database integrity if sqlite3 is installed
if command -v sqlite3 > /dev/null 2>&1; then
    sqlite3 "${TEMP_DIR}/db.sqlite3" "PRAGMA integrity_check;" | grep -qx "ok"
fi

# Promote verified archive locally
mv -f "${STAGED_ARCHIVE}" "${LOCAL_BACKUP_DIR}/${ARCHIVE_NAME}"
chmod 600 "${LOCAL_BACKUP_DIR}/${ARCHIVE_NAME}"

# 3. Move any existing .tar.gz backup(s) on the Shared Drive to Trash (avoids Manager-only permanent delete restriction)
echo "[$(date)] Removing old backup archive from Google Drive..."
rclone --config "${RCLONE_CONFIG}" delete "${RCLONE_DEST}" --include "*.tar.gz"

# 4. Upload the newly verified backup archive to Google Drive
echo "[$(date)] Uploading verified archive to Google Drive..."
rclone --config "${RCLONE_CONFIG}" copyto "${LOCAL_BACKUP_DIR}/${ARCHIVE_NAME}" "${RCLONE_DEST}/${ARCHIVE_NAME}"

echo "[$(date)] Vaultwarden backup verified, old remote copy removed, and new backup uploaded successfully."
