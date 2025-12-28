#!/bin/bash
# Raspberry Pi Zero WH 初期セットアップ用SDカード準備スクリプト（Mac用）
# Raspberry Pi OS Lite書き込み後に実行

set -e

# 色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Raspberry Pi Zero WH SDカード準備（Mac用）"
echo "=========================================="
echo ""

# 前提条件の確認
echo -e "${YELLOW}前提条件：${NC}"
echo "  1. Raspberry Pi ImagerでRaspberry Pi OS Liteを書き込み済み"
echo "  2. SDカードがMacにマウントされている"
echo "  3. bootパーティションにアクセス可能"
echo ""

# bootパーティションのパスを検索
BOOT_PATH=""
if [ -d "/Volumes/bootfs" ]; then
    BOOT_PATH="/Volumes/bootfs"
elif [ -d "/Volumes/boot" ]; then
    BOOT_PATH="/Volumes/boot"
else
    echo -e "${YELLOW}bootパーティションを検索中...${NC}"
    for vol in /Volumes/*; do
        if [ -f "$vol/config.txt" ] || [ -f "$vol/cmdline.txt" ]; then
            BOOT_PATH="$vol"
            break
        fi
    done
fi

if [ -z "$BOOT_PATH" ]; then
    echo -e "${RED}エラー: bootパーティションが見つかりません${NC}"
    echo "Raspberry Pi OSを書き込んだSDカードを挿入してください"
    exit 1
fi

echo -e "${GREEN}bootパーティション検出: $BOOT_PATH${NC}"
echo ""

# Wi-Fi設定の入力
echo -e "${BLUE}=== Wi-Fi設定 ===${NC}"
read -p "Wi-Fi SSID: " WIFI_SSID
read -sp "Wi-Fi パスワード: " WIFI_PASSWORD
echo ""
read -p "Wi-Fi国コード (JP/US等, デフォルト: JP): " WIFI_COUNTRY
WIFI_COUNTRY=${WIFI_COUNTRY:-JP}

echo ""
echo -e "${BLUE}=== ホスト名設定 ===${NC}"
read -p "ホスト名 (デフォルト: rx1r-pi): " HOSTNAME
HOSTNAME=${HOSTNAME:-rx1r-pi}
echo "  → Macから「${HOSTNAME}.local」でSSH接続できます"

echo ""
echo -e "${YELLOW}設定内容確認：${NC}"
echo "  Wi-Fi SSID: $WIFI_SSID"
echo "  Wi-Fi 国コード: $WIFI_COUNTRY"
echo "  ホスト名: $HOSTNAME"
echo ""
read -p "この設定でよろしいですか？ (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}キャンセルしました${NC}"
    exit 1
fi

# SSH有効化
echo ""
echo -e "${GREEN}[1/3] SSH有効化${NC}"
touch "$BOOT_PATH/ssh"
echo "  ✓ ssh ファイル作成完了"

# Wi-Fi設定ファイル作成
echo ""
echo -e "${GREEN}[2/3] Wi-Fi設定ファイル作成${NC}"
cat > "$BOOT_PATH/wpa_supplicant.conf" <<EOF
country=$WIFI_COUNTRY
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={
    ssid="$WIFI_SSID"
    psk="$WIFI_PASSWORD"
    key_mgmt=WPA-PSK
}
EOF
echo "  ✓ wpa_supplicant.conf 作成完了"

# ホスト名設定用スクリプト作成
echo ""
echo -e "${GREEN}[3/3] 初回起動用設定ファイル作成${NC}"
cat > "$BOOT_PATH/firstboot.sh" <<'EOFSCRIPT'
#!/bin/bash
# 初回起動時の設定（Pi上で自動実行される想定）
HOSTNAME_FILE="/etc/hostname"
HOSTS_FILE="/etc/hosts"
NEW_HOSTNAME="HOSTNAME_PLACEHOLDER"

# ホスト名変更
if [ "$(cat $HOSTNAME_FILE)" != "$NEW_HOSTNAME" ]; then
    echo "$NEW_HOSTNAME" | sudo tee $HOSTNAME_FILE
    sudo sed -i "s/127.0.1.1.*/127.0.1.1\t$NEW_HOSTNAME/" $HOSTS_FILE
    sudo hostnamectl set-hostname $NEW_HOSTNAME
fi

# avahi-daemon確認（mDNS用）
sudo systemctl enable avahi-daemon
sudo systemctl start avahi-daemon

# 完了後、自分自身を削除
rm -f /boot/firstboot.sh
EOFSCRIPT

# ホスト名をプレースホルダーから置換
sed -i.bak "s/HOSTNAME_PLACEHOLDER/$HOSTNAME/" "$BOOT_PATH/firstboot.sh"
rm -f "$BOOT_PATH/firstboot.sh.bak"
chmod +x "$BOOT_PATH/firstboot.sh"
echo "  ✓ firstboot.sh 作成完了"

# userconf作成（Raspberry Pi OS Bullseye以降）
echo ""
echo -e "${BLUE}=== ユーザー設定 ===${NC}"
echo "デフォルトユーザー「pi」のパスワードを設定します"
echo -e "${YELLOW}注意: 初回SSH接続時にこのパスワードが必要です${NC}"
read -sp "piユーザーのパスワード: " PI_PASSWORD
echo ""

# パスワードをハッシュ化（openssl使用）
PI_PASSWORD_HASH=$(echo "$PI_PASSWORD" | openssl passwd -6 -stdin)
echo "pi:$PI_PASSWORD_HASH" > "$BOOT_PATH/userconf.txt"
echo "  ✓ userconf.txt 作成完了"

# 完了メッセージ
echo ""
echo "=========================================="
echo -e "${GREEN}SDカード準備完了！${NC}"
echo "=========================================="
echo ""
echo -e "${YELLOW}次のステップ：${NC}"
echo ""
echo "1. SDカードを安全に取り出す"
echo "   右クリック → 取り出し"
echo ""
echo "2. Raspberry Pi Zero WHにSDカードを挿入して起動"
echo "   ※ 初回起動は2〜3分かかります"
echo ""
echo "3. MacからSSH接続"
echo "   ssh pi@${HOSTNAME}.local"
echo "   パスワード: （設定したパスワード）"
echo ""
echo "4. Pi上で初期セットアップスクリプト実行"
echo "   curl -sL https://raw.githubusercontent.com/your-repo/RX1R-to-GoogleDrive/main/scripts/raspi-init.sh | bash"
echo "   または、リポジトリをクローンして実行"
echo ""
echo -e "${BLUE}トラブルシューティング：${NC}"
echo "  - 接続できない場合: ping ${HOSTNAME}.local で疎通確認"
echo "  - IPアドレス確認: arp -a | grep -i b8:27:eb"
echo "  - ルーター管理画面でIPアドレス確認"
echo ""
