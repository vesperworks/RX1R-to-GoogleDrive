#!/bin/bash
# RX1R to Google Drive 自動同期スクリプト
# ez Share Wi-Fi SD経由でRX1Rの写真をGoogle Driveに自動アップロード

set -e

# 設定
BASE_URL="http://192.168.4.1"
TMP_DIR="$HOME/rx1r/tmp"
DB="$HOME/rx1r/db/uploaded.db"
DRIVE="gdrive:RX1R"
LOG_FILE="$HOME/rx1r/sync.log"

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
if ! curl -s --connect-timeout 5 "$BASE_URL" > /dev/null 2>&1; then
    log "WARNING: ez Share に接続できません ($BASE_URL)"
    exit 0
fi

log "INFO: 同期を開始します"

# ファイルリスト取得
FILES=$(curl -s "$BASE_URL/cgi-bin/ezshare.cgi?op=ls" \
  | grep -E '\.(ARW|JPG|arw|jpg)$' \
  | awk '{print $NF}') || {
    log "WARNING: ファイルリストの取得に失敗しました"
    exit 0
}

if [ -z "$FILES" ]; then
    log "INFO: 新しいファイルはありません"
    exit 0
fi

# ファイル数をカウント
FILE_COUNT=$(echo "$FILES" | wc -l)
log "INFO: $FILE_COUNT 個のファイルを検出しました"

# 処理済みファイル数
UPLOADED=0
SKIPPED=0

# 各ファイルを処理
for FILE in $FILES; do
    # データベースで既アップロード済みか確認
    EXISTS=$(sqlite3 "$DB" \
        "SELECT 1 FROM uploaded WHERE path='$FILE' LIMIT 1;" 2>/dev/null || echo "")

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

    if rclone copy "$LOCAL_FILE" "$DRIVE/$DIRNAME" --progress; then
        # アップロード成功をDBに記録
        sqlite3 "$DB" \
            "INSERT INTO uploaded VALUES ('$FILE', $SIZE, datetime('now'));" 2>/dev/null || {
            log "WARNING: DB記録失敗（ファイルは既にアップロード済み）: $FILE"
        }

        log "SUCCESS: アップロード完了: $FILE"
        ((UPLOADED++))
    else
        log "ERROR: アップロード失敗: $FILE"
    fi

    # ローカルファイルを削除
    rm -f "$LOCAL_FILE"
done

# 結果サマリー
log "INFO: 同期完了 - アップロード: $UPLOADED, スキップ: $SKIPPED"
