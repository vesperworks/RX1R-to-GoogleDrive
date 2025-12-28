# RX1R to Google Drive 自動同期システム

Sony RX1R（初代）で撮影した写真を、ez Share Wi-Fi SD経由でRaspberry Pi Zero WHが自動的にGoogle Driveへアップロードするシステムです。

## 🎯 特徴

- **完全自動**: カメラ電源OFF後、何もせずに自動同期
- **EXIF保持**: RAW/JPEGのメタデータ完全保持
- **重複防止**: SQLiteで管理、再取得なし
- **ゼロタッチ**: 撮影体験は一切変わらない
- **Mac対応**: mDNS（.local）でSSH接続可能

## 📦 システム構成

```
[Sony RX1R]
     ↓
[ez Share Wi-Fi SD] ))) Wi-Fi
     ↓
[Raspberry Pi Zero WH]
     ↓
[Google Drive]
```

## 🚀 クイックスタート

### 前提条件

- **Raspberry Pi Zero WH**（Wi-Fi内蔵版）
- **ez Share Wi-Fi SD**（8GB/16GB）
- **Mac**（初期セットアップ用）
- **Raspberry Pi OS Lite**（32bit推奨）

### Step 1: SDカードにRaspberry Pi OSを書き込む

1. [Raspberry Pi Imager](https://www.raspberrypi.com/software/)をダウンロード
2. **Raspberry Pi OS Lite (32-bit)** を選択
3. SDカードに書き込み

### Step 2: Mac上でSDカードを準備（Wi-Fi・SSH設定）

```bash
# このリポジトリをクローン
git clone https://github.com/your-username/RX1R-to-GoogleDrive.git
cd RX1R-to-GoogleDrive

# SDカード準備スクリプト実行
chmod +x scripts/prepare-sd-card-mac.sh
./scripts/prepare-sd-card-mac.sh
```

スクリプトが以下を設定します：
- SSH有効化
- Wi-Fi接続設定
- ホスト名設定（デフォルト: `rx1r-pi.local`）
- piユーザーパスワード

### Step 3: Raspberry Piを起動してSSH接続

```bash
# SDカードをPiに挿入して電源ON（初回起動は2〜3分）

# MacからSSH接続
ssh pi@rx1r-pi.local
# パスワード: （Step 2で設定したもの）
```

### Step 4: Pi上で初期設定

```bash
# リポジトリをクローン
git clone https://github.com/your-username/RX1R-to-GoogleDrive.git
cd RX1R-to-GoogleDrive

# 初期設定スクリプト実行
chmod +x scripts/raspi-init.sh
./scripts/raspi-init.sh

# 再起動
sudo reboot
```

### Step 5: 環境設定ファイルの作成

```bash
# SSH再接続
ssh pi@rx1r-pi.local

cd RX1R-to-GoogleDrive

# .envファイルを作成
cp .env.sample .env

# 設定を編集
nano .env
```

**.envファイルの編集内容**:

```bash
# ez Share Wi-Fi SD 設定
EZSHARE_SSID="ezShare"              # ez ShareのSSID
EZSHARE_PASSWORD=""                  # パスワード（なければ空）
EZSHARE_BASE_URL="http://192.168.4.1"

# Google Drive 設定
GDRIVE_REMOTE="gdrive"               # rcloneリモート名
GDRIVE_FOLDER="RX1R"                 # アップロード先フォルダ

# Wi-Fi 設定（自宅ネットワーク）
WIFI_SSID="YourHomeWiFi"             # 自宅Wi-Fi SSID
WIFI_PASSWORD="YourPassword"         # Wi-Fiパスワード
WIFI_COUNTRY="JP"                    # 国コード

# 同期設定
SYNC_INTERVAL="5"                    # 同期間隔（分）
DELETE_AFTER_UPLOAD="true"           # アップロード後の削除
```

保存して閉じる: `Ctrl+X` → `Y` → `Enter`

### Step 6: RX1R同期環境をセットアップ

```bash
# セットアップスクリプト実行
chmod +x scripts/setup.sh
./scripts/setup.sh
```

### Step 7: Google Drive設定

```bash
rclone config
```

以下の手順で設定：
1. `n` (new remote)
2. name: `gdrive`
3. Storage: `drive` (Google Drive)
4. 認証フロー実行
5. `q` (quit)

```bash
# RX1Rフォルダ作成
rclone mkdir gdrive:RX1R
```

### Step 8: 動作確認

```bash
# ez Share接続（カメラの電源を入れる）
nmcli dev wifi connect ezShare

# 手動同期テスト
~/sync_rx1r_ezshare.sh

# ログ確認
tail -f ~/rx1r/sync.log
```

### Step 9: 自動実行設定

```bash
crontab -e

# 以下を追加（5分間隔で自動同期）
*/5 * * * * /home/pi/sync_rx1r_ezshare.sh
```

## 📁 ディレクトリ構成

```
RX1R-to-GoogleDrive/
├── README.md              # このファイル
├── CLAUDE.MD              # AI用プロジェクトコンテキスト
├── INITIAL.md             # 初期仕様書（日本語）
├── Instruction.md         # 詳細セットアップガイド
├── .env.sample            # 環境設定テンプレート
├── .gitignore             # Git除外設定
└── scripts/
    ├── prepare-sd-card-mac.sh    # Mac用SDカード準備
    ├── raspi-init.sh             # Pi初期設定
    ├── setup.sh                  # 同期環境セットアップ
    └── sync_rx1r_ezshare.sh      # 同期スクリプト
```

Raspberry Pi上の実行時構成：

```
$HOME/
├── rx1r/
│   ├── tmp/              # 一時ダウンロード
│   ├── db/
│   │   └── uploaded.db   # アップロード履歴DB
│   ├── sync.log          # 同期ログ
│   └── cron.log          # cronログ
└── sync_rx1r_ezshare.sh  # 同期スクリプト
```

## 🔧 トラブルシューティング

### Piに接続できない

```bash
# 疎通確認
ping rx1r-pi.local

# IPアドレス確認（MacのARPテーブル）
arp -a | grep -i b8:27:eb

# 直接IP指定で接続
ssh pi@192.168.x.x
```

### ez Shareに接続できない

```bash
# ez Share SSID確認
nmcli dev wifi list | grep ezShare

# 手動接続
nmcli dev wifi connect ezShare

# 接続確認
curl http://192.168.4.1/cgi-bin/ezshare.cgi?op=ls
```

### 同期が動かない

```bash
# ログ確認
tail -50 ~/rx1r/sync.log

# cron確認
crontab -l
grep CRON /var/log/syslog | tail -20

# 手動実行でデバッグ
~/sync_rx1r_ezshare.sh
```

### Google Driveアップロード失敗

```bash
# rclone設定確認
rclone config show

# 接続テスト
rclone lsd gdrive:

# 再認証
rclone config reconnect gdrive:
```

## 📚 ドキュメント

- **[Instruction.md](./Instruction.md)** - 詳細セットアップガイド（トラブルシューティング含む）
- **[INITIAL.md](./INITIAL.md)** - 初期仕様書（日本語）
- **[CLAUDE.MD](./CLAUDE.MD)** - プロジェクトコンテキスト

## 🛠️ スクリプト詳細

### prepare-sd-card-mac.sh（Mac用）

Raspberry Pi OS書き込み後のSDカード初期設定を自動化

- SSH有効化（`ssh`ファイル作成）
- Wi-Fi設定（`wpa_supplicant.conf`）
- ホスト名設定
- ユーザーパスワード設定

### raspi-init.sh（Pi用）

Raspberry Pi初回起動後の初期設定

- タイムゾーン（Asia/Tokyo）
- ロケール（ja_JP.UTF-8）
- システムアップデート
- 基本パッケージインストール
- mDNS設定（.local接続用）
- メモリ最適化
- 不要サービス無効化

### setup.sh（Pi用）

RX1R同期環境のセットアップ

- 必要ツールインストール（curl, wget, jq, sqlite3, rclone）
- 作業ディレクトリ作成
- SQLiteデータベース初期化
- 同期スクリプト配置

### sync_rx1r_ezshare.sh（Pi用・自動実行）

ez Share → Google Drive 同期の実行

- ez Shareからファイルリスト取得
- 重複チェック（SQLite）
- ダウンロード → アップロード → 削除
- ログ出力

## 🎥 対応ファイル形式

- **RAW**: `.ARW` (Sony RX1R)
- **JPEG**: `.JPG`
- **EXIF**: 完全保持

## ⚙️ カスタマイズ

### .envファイルで設定変更（推奨）

同期スクリプトは`.env`ファイルで設定をカスタマイズできます。

```bash
cd ~/RX1R-to-GoogleDrive
nano .env
```

**主要な設定項目**:

```bash
# ez Share設定
EZSHARE_BASE_URL="http://192.168.4.1"  # ez ShareのURL
EZSHARE_TIMEOUT="10"                    # 接続タイムアウト（秒）

# Google Drive設定
GDRIVE_REMOTE="gdrive"                  # rcloneリモート名
GDRIVE_FOLDER="RX1R"                    # アップロード先フォルダ

# 同期設定
DELETE_AFTER_UPLOAD="true"              # アップロード後に削除
SYNC_INTERVAL="5"                       # cron実行間隔（分）

# rcloneオプション
RCLONE_OPTIONS="--progress --transfers=1"  # 転送オプション

# ログ設定
SYNC_LOG_FILE="$HOME/rx1r/sync.log"    # ログファイルパス
```

設定変更後は同期スクリプトを再実行すれば反映されます（再起動不要）。

### cron実行間隔の変更

**.envファイルで設定**:
```bash
SYNC_INTERVAL="5"  # 分単位
```

**または、crontabを直接編集**:
```bash
crontab -e

# 1分間隔（大量撮影時）
* * * * * /home/pi/sync_rx1r_ezshare.sh

# 10分間隔（通常）
*/10 * * * * /home/pi/sync_rx1r_ezshare.sh
```

### Google Driveフォルダ変更

**.envファイルで設定**:
```bash
GDRIVE_FOLDER="Camera/RX1R"  # 任意のフォルダパス
```

## 🔐 セキュリティ

- SSH鍵認証の設定を推奨
- piユーザーのパスワードは強固なものに
- Google Drive認証トークンは適切に管理

## 📝 ライセンス

MIT License

## 🙏 謝辞

- ez Share Wi-Fi SD
- Raspberry Pi Foundation
- rclone project

---

**Last Updated**: 2025-12-28
**Author**: vesperworks
**Repository**: [RX1R-to-GoogleDrive](https://github.com/vesperworks/RX1R-to-GoogleDrive)
