#!/usr/bin/env bash
# Backup diário configurável: bancos (MariaDB/MySQL, PostgreSQL, SQLite), diretórios e cópia opcional via rclone.
# Uso: BACKUP_CONFIG=/etc/server-backup/backup.conf ./backup.sh
set -euo pipefail

CONFIG="${BACKUP_CONFIG:-/etc/server-backup/backup.conf}"
MYSQL_DATABASES=(); POSTGRES_DATABASES=(); SQLITE_FILES=(); DIRECTORIES=(); EXCLUDES=("venv" "node_modules" "__pycache__")
BACKUP_DIR="/var/backups/server-backup"; RETENTION_DAYS=7
RCLONE_REMOTE=""; RCLONE_RETENTION_DAYS=30; NOTIFY_COMMAND=""
MYSQL_DEFAULTS_FILE=""; PGHOST_OVERRIDE=""
# shellcheck disable=SC1090
[ -f "$CONFIG" ] && source "$CONFIG"

TODAY="$(date +%F)"
DEST="$BACKUP_DIR/$TODAY"
LOG="$BACKUP_DIR/backup.log"
umask 077
mkdir -p "$DEST"
exec >>"$LOG" 2>&1
echo "=== $(date '+%F %T') início"

on_error() {
    echo "=== $(date '+%F %T') FALHOU (linha $1)"
    if [ -n "$NOTIFY_COMMAND" ]; then
        BACKUP_MESSAGE="Falha no backup de $TODAY. Veja $LOG" bash -c "$NOTIFY_COMMAND" || true
    fi
}
trap 'on_error $LINENO' ERR

# MariaDB/MySQL: credenciais em um arquivo .cnf (modo 600), nunca na linha de comando
if [ "${#MYSQL_DATABASES[@]}" -gt 0 ]; then
    : "${MYSQL_DEFAULTS_FILE:?defina MYSQL_DEFAULTS_FILE no arquivo de configuração}"
    for db in "${MYSQL_DATABASES[@]}"; do
        mysqldump --defaults-extra-file="$MYSQL_DEFAULTS_FILE" --single-transaction --routines --triggers "$db" | gzip >"$DEST/mysql-$db.sql.gz"
    done
fi

# PostgreSQL: usa as variáveis padrão PGHOST/PGUSER/PGPASSWORD ou ~/.pgpass
for db in "${POSTGRES_DATABASES[@]}"; do
    pg_dump "$db" | gzip >"$DEST/postgres-$db.sql.gz"
done

# SQLite: cópia consistente com .backup
for f in "${SQLITE_FILES[@]}"; do
    name="$(basename "$f")"
    sqlite3 "$f" ".backup '$DEST/sqlite-$name'" && gzip -f "$DEST/sqlite-$name"
done

# Diretórios
exclude_args=()
for e in "${EXCLUDES[@]}"; do exclude_args+=("--exclude=$e"); done
for d in "${DIRECTORIES[@]}"; do
    name="$(echo "$d" | sed 's#^/##; s#/#_#g')"
    tar czf "$DEST/dir-$name.tgz" "${exclude_args[@]}" -C / "${d#/}" 2>/dev/null
done

# Confere a integridade dos arquivos compactados
for f in "$DEST"/*.gz "$DEST"/*.tgz; do [ -e "$f" ] && gzip -t "$f"; done

# Rotação local
find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d -name '20*' -mtime +$((RETENTION_DAYS - 1)) -exec rm -rf {} +

# Cópia remota opcional (rclone), conferida após o envio
if [ -n "$RCLONE_REMOTE" ]; then
    rclone copy "$DEST" "$RCLONE_REMOTE/$TODAY" --transfers 2
    rclone check "$DEST" "$RCLONE_REMOTE/$TODAY"
    rclone delete "$RCLONE_REMOTE" --min-age "${RCLONE_RETENTION_DAYS}d"
    rclone rmdirs "$RCLONE_REMOTE" --leave-root
fi

echo "=== $(date '+%F %T') OK $(du -sh "$DEST" | cut -f1)"
