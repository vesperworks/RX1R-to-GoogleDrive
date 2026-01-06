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
echo "  5. Wi-Fi接続プロファイル作成 (ez Share, 自宅Wi-Fi)"
echo "  6. 同期スクリプトの配置"
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

# Phase 5: ez Share Wi-Fi接続プロファイル作成
echo ""
echo -e "${GREEN}[Phase 5] ez Share Wi-Fi接続プロファイル作成${NC}"

# .envからパスワードを読み込み
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
ENV_FILE="$PROJECT_ROOT/.env"

EZSHARE_SSID="ez Share"
EZSHARE_PASSWORD=""

if [ -f "$ENV_FILE" ]; then
    # shellcheck disable=SC1090
    source <(grep -E '^EZSHARE_(SSID|PASSWORD)=' "$ENV_FILE" || true)
fi

if [ -z "$EZSHARE_PASSWORD" ]; then
    read -p "ez Shareのパスワードを入力してください (デフォルト: 88888888): " input_password
    EZSHARE_PASSWORD="${input_password:-88888888}"
fi

# 既存の接続を削除して再作成
sudo nmcli connection delete ezshare 2>/dev/null || true
sudo nmcli connection add type wifi con-name "ezshare" ifname wlan0 ssid "$EZSHARE_SSID" \
    wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$EZSHARE_PASSWORD"
echo "ez Share接続プロファイルを作成しました: ezshare"

# Phase 5b: 自宅Wi-Fi接続プロファイル作成
echo ""
echo -e "${GREEN}[Phase 5b] 自宅Wi-Fi接続プロファイル作成${NC}"

HOME_WIFI_SSID=""
HOME_WIFI_PASSWORD=""

if [ -f "$ENV_FILE" ]; then
    # shellcheck disable=SC1090
    source <(grep -E '^HOME_WIFI_(SSID|PASSWORD)=' "$ENV_FILE" || true)
fi

if [ -z "$HOME_WIFI_SSID" ]; then
    read -p "自宅Wi-FiのSSIDを入力してください: " HOME_WIFI_SSID
fi

if [ -z "$HOME_WIFI_SSID" ]; then
    echo -e "${YELLOW}自宅Wi-Fi SSIDが未設定のため、スキップします${NC}"
else
    if [ -z "$HOME_WIFI_PASSWORD" ]; then
        read -sp "自宅Wi-Fiのパスワードを入力してください: " HOME_WIFI_PASSWORD
        echo ""
    fi

    # 既存の接続を削除して再作成
    sudo nmcli connection delete home 2>/dev/null || true
    sudo nmcli connection add type wifi con-name "home" ifname wlan0 ssid "$HOME_WIFI_SSID" \
        wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$HOME_WIFI_PASSWORD"
    echo "自宅Wi-Fi接続プロファイルを作成しました: home"
fi

# Phase 6: 同期スクリプトの配置
echo ""
echo -e "${GREEN}[Phase 6] 同期スクリプトの配置${NC}"

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
echo "1. rclone設定（Google Drive接続）"
echo "   rclone config"
echo "   リモート名: gdrive"
echo "   タイプ: drive (Google Drive)"
echo ""
echo "2. 同期スクリプトの動作確認"
echo "   ~/pi-sync.sh"
echo ""
echo "3. cron設定（自動実行）"
echo "   crontab -e"
echo "   以下を追加:"
echo "   */5 * * * * /home/$USER/pi-sync.sh"
echo ""
echo "詳細は Instruction.md を参照してください"
echo ""
