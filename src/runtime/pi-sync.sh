#!/bin/bash
# RX1R to Google Drive 自動同期スクリプト
# ez Share Wi-Fi SD経由でRX1Rの写真をGoogle Driveに自動アップロード

set -euo pipefail

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# .envファイルを安全に読み込み（存在する場合）
load_env() {
    local env_file="$1"
    if [ -f "$env_file" ]; then
        # コメントと空行を除外し、KEY=VALUE形式のみ読み込み
        set -a
        # shellcheck disable=SC1090
        source <(grep -v '^#' "$env_file" | grep -v '^[[:space:]]*$' | grep '=' || true)
        set +a
    fi
}

# .envファイルを読み込み
if [ -f "$PROJECT_ROOT/.env" ]; then
    load_env "$PROJECT_ROOT/.env"
elif [ -f "$HOME/RX1R-to-GoogleDrive/.env" ]; then
    load_env "$HOME/RX1R-to-GoogleDrive/.env"
fi

# 設定（環境変数で上書き可能、デフォルト値）
BASE_URL="${EZSHARE_BASE_URL:-http://192.168.4.1}"
TMP_DIR="${SYNC_TMP_DIR:-$HOME/rx1r/tmp}"
DB="${SYNC_DB_PATH:-$HOME/rx1r/db/uploaded.db}"
DRIVE="${GDRIVE_REMOTE:-gdrive}:${GDRIVE_FOLDER:-RX1R}"
LOG_FILE="${SYNC_LOG_FILE:-$HOME/rx1r/sync.log}"
TIMEOUT="${EZSHARE_TIMEOUT:-5}"
DELETE_AFTER="${DELETE_AFTER_UPLOAD:-true}"

# rcloneオプションを配列として処理
IFS=' ' read -r -a RCLONE_OPTS_ARRAY <<< "${RCLONE_OPTIONS:---progress}"

# ログ出力関数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# エラーハンドリング
error_exit() {
    log "ERROR: $1"
    exit 1
}

# 作業ディレクトリの確認・作成
mkdir -p "$TMP_DIR"

# ez Share接続確認
if ! curl -s --connect-timeout "$TIMEOUT" "$BASE_URL" > /dev/null 2>&1; then
    log "WARNING: ez Share に接続できません ($BASE_URL)"
    exit 0
fi

log "INFO: 同期を開始します"

# ファイルリスト取得（配列に格納）
mapfile -t FILES_ARRAY < <(curl -s "$BASE_URL/cgi-bin/ezshare.cgi?op=ls" \
  | grep -E '\.(ARW|JPG|arw|jpg)$' \
  | awk '{print $NF}') || {
    log "WARNING: ファイルリストの取得に失敗しました"
    exit 0
}

if [ ${#FILES_ARRAY[@]} -eq 0 ]; then
    log "INFO: 新しいファイルはありません"
    exit 0
fi

# ファイル数をカウント
FILE_COUNT=${#FILES_ARRAY[@]}
log "INFO: $FILE_COUNT 個のファイルを検出しました"

# 処理済みファイル数
UPLOADED=0
SKIPPED=0

# 各ファイルを処理
for FILE in "${FILES_ARRAY[@]}"; do
    # データベースで既アップロード済みか確認（パラメータ化クエリ使用）
    EXISTS=$(sqlite3 "$DB" \
        "SELECT 1 FROM uploaded WHERE path=? LIMIT 1;" "$FILE" 2>/dev/null || echo "")

    if [ -n "$EXISTS" ]; then
        ((SKIPPED++))
        continue
    fi

    log "INFO: ダウンロード中: $FILE"

    # ファイルをダウンロード
    if ! wget -q "$BASE_URL/$FILE" -P "$TMP_DIR"; then
        log "ERROR: ダウンロード失敗: $FILE"
        continue
    fi

    # ファイルサイズ取得
    BASENAME=$(basename "$FILE")
    LOCAL_FILE="$TMP_DIR/$BASENAME"

    if [ ! -f "$LOCAL_FILE" ]; then
        log "ERROR: ファイルが見つかりません: $LOCAL_FILE"
        continue
    fi

    SIZE=$(stat -c%s "$LOCAL_FILE")

    # Google Driveにアップロード
    DIRNAME=$(dirname "$FILE")
    log "INFO: アップロード中: $FILE ($SIZE bytes)"

    if rclone copy "$LOCAL_FILE" "$DRIVE/$DIRNAME" "${RCLONE_OPTS_ARRAY[@]}"; then
        # アップロード成功をDBに記録（パラメータ化クエリ使用）
        sqlite3 "$DB" \
            "INSERT INTO uploaded VALUES (?, ?, datetime('now'));" "$FILE" "$SIZE" 2>/dev/null || {
            log "WARNING: DB記録失敗（ファイルは既にアップロード済み）: $FILE"
        }

        log "SUCCESS: アップロード完了: $FILE"
        ((UPLOADED++))

        # ローカルファイルを削除（設定による）
        if [ "$DELETE_AFTER" = "true" ]; then
            rm -f "$LOCAL_FILE"
        fi
    else
        log "ERROR: アップロード失敗: $FILE"
        # アップロード失敗時も削除
        rm -f "$LOCAL_FILE"
    fi
done

# 結果サマリー
log "INFO: 同期完了 - アップロード: $UPLOADED, スキップ: $SKIPPED"
