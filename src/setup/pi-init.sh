#!/bin/bash
# Raspberry Pi Zero WH 初期設定スクリプト
# SSH接続後、Pi上で実行

set -e

# 色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Raspberry Pi Zero WH 初期設定"
echo "=========================================="
echo ""

# root権限確認
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}エラー: このスクリプトはroot権限で実行しないでください${NC}"
    echo "通常ユーザー（pi）で実行してください"
    exit 1
fi

# インタラクティブ確認
echo -e "${YELLOW}このスクリプトは以下の設定を行います：${NC}"
echo "  1. タイムゾーン設定（Asia/Tokyo）"
echo "  2. ロケール設定（ja_JP.UTF-8）"
echo "  3. システムアップデート"
echo "  4. 基本パッケージインストール"
echo "  5. mDNS設定確認（raspberrypi.local）"
echo "  6. メモリ分割最適化（GPU: 16MB）"
echo "  7. 不要サービス無効化"
echo ""
read -p "続行しますか？ (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}セットアップを中止しました${NC}"
    exit 1
fi

# Phase 1: タイムゾーン設定
echo ""
echo -e "${GREEN}[Phase 1] タイムゾーン設定${NC}"
CURRENT_TZ=$(timedatectl | grep "Time zone" | awk '{print $3}')
if [ "$CURRENT_TZ" != "Asia/Tokyo" ]; then
    sudo timedatectl set-timezone Asia/Tokyo
    echo "  ✓ タイムゾーン: Asia/Tokyo"
else
    echo "  ✓ タイムゾーンは既に設定済み: $CURRENT_TZ"
fi

# Phase 2: ロケール設定
echo ""
echo -e "${GREEN}[Phase 2] ロケール設定${NC}"
if ! locale -a | grep -q "ja_JP.utf8"; then
    sudo sed -i 's/^# ja_JP.UTF-8 UTF-8/ja_JP.UTF-8 UTF-8/' /etc/locale.gen
    sudo locale-gen ja_JP.UTF-8
    echo "  ✓ 日本語ロケール生成完了"
else
    echo "  ✓ 日本語ロケールは既に有効"
fi

# Phase 3: システムアップデート
echo ""
echo -e "${GREEN}[Phase 3] システムアップデート${NC}"
echo "  この処理には数分かかる場合があります..."
sudo apt update -qq
sudo apt upgrade -y -qq
echo "  ✓ システムアップデート完了"

# Phase 4: 基本パッケージインストール
echo ""
echo -e "${GREEN}[Phase 4] 基本パッケージインストール${NC}"
sudo apt install -y -qq \
    vim \
    git \
    curl \
    wget \
    htop \
    tree \
    avahi-daemon \
    avahi-utils
echo "  ✓ 基本パッケージインストール完了"

# Phase 5: mDNS設定確認
echo ""
echo -e "${GREEN}[Phase 5] mDNS設定確認${NC}"
HOSTNAME=$(hostname)
if systemctl is-active --quiet avahi-daemon; then
    echo "  ✓ avahi-daemon は稼働中"
    echo "  ✓ Macから「${HOSTNAME}.local」でアクセス可能です"
else
    sudo systemctl enable avahi-daemon
    sudo systemctl start avahi-daemon
    echo "  ✓ avahi-daemon を起動しました"
fi

# Phase 6: メモリ分割最適化（GPU不要）
echo ""
echo -e "${GREEN}[Phase 6] メモリ分割最適化${NC}"
if ! grep -q "^gpu_mem=" /boot/config.txt; then
    echo "gpu_mem=16" | sudo tee -a /boot/config.txt > /dev/null
    echo "  ✓ GPUメモリを16MBに設定（要再起動）"
else
    echo "  ✓ GPUメモリ設定は既に存在"
fi

# Phase 7: 不要サービス無効化（省電力化）
echo ""
echo -e "${GREEN}[Phase 7] 不要サービス無効化${NC}"
SERVICES_TO_DISABLE=(
    "bluetooth.service"
    "hciuart.service"
    "triggerhappy.service"
)

for service in "${SERVICES_TO_DISABLE[@]}"; do
    if systemctl is-enabled --quiet "$service" 2>/dev/null; then
        sudo systemctl disable "$service" 2>/dev/null || true
        sudo systemctl stop "$service" 2>/dev/null || true
        echo "  ✓ $service を無効化"
    fi
done

# Phase 8: Wi-Fi省電力モード無効化（安定性向上）
echo ""
echo -e "${GREEN}[Phase 8] Wi-Fi省電力モード無効化${NC}"
if ! grep -q "wireless-power off" /etc/network/interfaces 2>/dev/null; then
    echo "# Disable Wi-Fi power management" | sudo tee -a /etc/rc.local > /dev/null
    echo "/sbin/iw wlan0 set power_save off" | sudo tee -a /etc/rc.local > /dev/null
    sudo iw wlan0 set power_save off 2>/dev/null || echo "  (現在Wi-Fi未接続のためスキップ)"
    echo "  ✓ Wi-Fi省電力モード無効化設定完了"
else
    echo "  ✓ Wi-Fi省電力モード設定は既に存在"
fi

# Phase 9: スワップ無効化（SDカード保護）
echo ""
echo -e "${GREEN}[Phase 9] スワップ無効化（SDカード寿命延長）${NC}"
if systemctl is-active --quiet dphys-swapfile; then
    sudo dphys-swapfile swapoff
    sudo systemctl disable dphys-swapfile
    echo "  ✓ スワップを無効化しました"
else
    echo "  ✓ スワップは既に無効"
fi

# Phase 10: システム情報表示
echo ""
echo -e "${GREEN}[Phase 10] システム情報${NC}"
echo "  ホスト名: $(hostname)"
echo "  IPアドレス: $(hostname -I | awk '{print $1}')"
echo "  mDNS名: $(hostname).local"
echo "  タイムゾーン: $(timedatectl | grep "Time zone" | awk '{print $3}')"
echo "  稼働時間: $(uptime -p)"
echo "  メモリ使用: $(free -h | grep Mem | awk '{print $3 "/" $2}')"

# 完了メッセージ
echo ""
echo "=========================================="
echo -e "${GREEN}初期設定完了！${NC}"
echo "=========================================="
echo ""
echo -e "${YELLOW}次のステップ：${NC}"
echo ""
echo "1. 再起動（推奨）"
echo "   sudo reboot"
echo ""
echo "2. 再起動後、RX1R同期環境をセットアップ"
echo "   git clone https://github.com/your-username/RX1R-to-GoogleDrive.git"
echo "   cd RX1R-to-GoogleDrive"
echo "   chmod +x scripts/setup.sh"
echo "   ./scripts/setup.sh"
echo ""
echo "3. 詳細手順は Instruction.md を参照"
echo ""
echo -e "${BLUE}接続情報：${NC}"
echo "  SSH: ssh pi@$(hostname).local"
echo "  IP: $(hostname -I | awk '{print $1}')"
echo ""

# 再起動確認
echo ""
read -p "今すぐ再起動しますか？ (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}再起動します...${NC}"
    sleep 2
    sudo reboot
else
    echo -e "${YELLOW}後で手動で再起動してください: sudo reboot${NC}"
fi
