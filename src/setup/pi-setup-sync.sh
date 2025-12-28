#!/bin/bash
# RX1R to Google Drive 自動同期システム
# Raspberry Pi 環境構築スクリプト

set -e

echo "=========================================="
echo "RX1R to Google Drive 環境構築スクリプト"
echo "=========================================="
echo ""

# 色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ユーザー確認
echo -e "${YELLOW}このスクリプトは以下の操作を行います：${NC}"
echo "  1. システムパッケージの更新"
echo "  2. 必要なツールのインストール (curl, wget, jq, sqlite3, rclone)"
echo "  3. 作業ディレクトリの作成 (~/rx1r/{tmp,db})"
echo "  4. SQLiteデータベースの初期化"
echo "  5. 同期スクリプトの配置"
echo ""
read -p "続行しますか？ (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}セットアップを中止しました${NC}"
    exit 1
fi

# Phase 1: システムアップデート
echo ""
echo -e "${GREEN}[Phase 1] システムアップデート${NC}"
echo "sudo apt update && sudo apt upgrade -y を実行します..."
sudo apt update
sudo apt upgrade -y

# Phase 2: 必要ツールのインストール
echo ""
echo -e "${GREEN}[Phase 2] 必要ツールのインストール${NC}"
echo "curl, wget, jq, sqlite3, rclone をインストールします..."
sudo apt install -y \
  curl \
  wget \
  jq \
  sqlite3 \
  rclone

# インストール確認
echo ""
echo "インストールされたツールのバージョン確認:"
echo "  curl: $(curl --version | head -n1)"
echo "  wget: $(wget --version | head -n1)"
echo "  jq: $(jq --version)"
echo "  sqlite3: $(sqlite3 --version)"
echo "  rclone: $(rclone --version | head -n1)"

# Phase 3: 作業ディレクトリ準備
echo ""
echo -e "${GREEN}[Phase 3] 作業ディレクトリ準備${NC}"
mkdir -p ~/rx1r/{tmp,db}
echo "作成完了: ~/rx1r/tmp"
echo "作成完了: ~/rx1r/db"

# Phase 4: SQLiteデータベース初期化
echo ""
echo -e "${GREEN}[Phase 4] SQLiteデータベース初期化${NC}"
sqlite3 ~/rx1r/db/uploaded.db <<EOF
CREATE TABLE IF NOT EXISTS uploaded (
  path TEXT PRIMARY KEY,
  size INTEGER,
  uploaded_at TEXT
);
EOF
echo "データベース作成完了: ~/rx1r/db/uploaded.db"

# テーブル確認
echo "テーブル構造確認:"
sqlite3 ~/rx1r/db/uploaded.db ".schema"

# Phase 5: 同期スクリプトの配置
echo ""
echo -e "${GREEN}[Phase 5] 同期スクリプトの配置${NC}"

# スクリプトのパスを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
SYNC_SCRIPT="$PROJECT_ROOT/src/runtime/pi-sync.sh"

if [ -f "$SYNC_SCRIPT" ]; then
    cp "$SYNC_SCRIPT" ~/pi-sync.sh
    chmod +x ~/pi-sync.sh
    echo "同期スクリプトをコピーしました: ~/pi-sync.sh"
else
    echo -e "${YELLOW}警告: pi-sync.sh が見つかりません${NC}"
    echo "  探したパス: $SYNC_SCRIPT"
    echo "後で手動で配置してください"
fi

# 完了メッセージ
echo ""
echo "=========================================="
echo -e "${GREEN}環境構築が完了しました！${NC}"
echo "=========================================="
echo ""
echo -e "${YELLOW}次のステップ：${NC}"
echo ""
echo "1. ez Share Wi-Fi接続設定"
echo "   nmcli dev wifi list"
echo "   nmcli dev wifi connect ezShare"
echo "   (パスワードが必要な場合: nmcli dev wifi connect ezShare password 12345678)"
echo ""
echo "2. rclone設定（Google Drive接続）"
echo "   rclone config"
echo "   リモート名: gdrive"
echo "   タイプ: drive (Google Drive)"
echo ""
echo "3. 同期スクリプトの動作確認"
echo "   ~/pi-sync.sh"
echo ""
echo "4. cron設定（自動実行）"
echo "   crontab -e"
echo "   以下を追加:"
echo "   */5 * * * * /home/$USER/pi-sync.sh"
echo ""
echo "詳細は Instruction.md を参照してください"
echo ""
