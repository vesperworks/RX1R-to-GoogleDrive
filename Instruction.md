# RX1R to Google Drive セットアップガイド

## 📋 目次

1. [前提条件](#前提条件)
2. [インストール手順](#インストール手順)
3. [ez Share Wi-Fi接続設定](#ez-share-wi-fi接続設定)
4. [Google Drive設定（rclone）](#google-drive設定rclone)
5. [動作確認](#動作確認)
6. [自動実行設定（cron）](#自動実行設定cron)
7. [トラブルシューティング](#トラブルシューティング)
8. [メンテナンス](#メンテナンス)

---

## 前提条件

### ハードウェア
- **Raspberry Pi Zero / Zero 2 W**（Wi-Fi必須）
- **ez Share Wi-Fi SD カード**（8GB / 16GB または互換品）
  - `cgi-bin/ezshare.cgi` APIが利用可能な機種
- **Sony RX1R**（初代）
- **常時給電可能な電源**

### ソフトウェア
- **Raspberry Pi OS Lite（32bit）**
- SSH有効化済み
- Wi-Fi設定済み（初期セットアップ用）

---

## インストール手順

### Step 1: リポジトリのクローン

```bash
cd ~
git clone https://github.com/your-username/RX1R-to-GoogleDrive.git
cd RX1R-to-GoogleDrive
```

### Step 2: セットアップスクリプトの実行

```bash
chmod +x scripts/setup.sh
./scripts/setup.sh
```

セットアップスクリプトは以下を自動実行します：

1. ✅ システムパッケージの更新
2. ✅ 必要ツールのインストール（curl, wget, jq, sqlite3, rclone）
3. ✅ 作業ディレクトリ作成（`~/rx1r/{tmp,db}`）
4. ✅ SQLiteデータベース初期化
5. ✅ 同期スクリプトの配置（`~/sync_rx1r_ezshare.sh`）

---

## ez Share Wi-Fi接続設定

### 方法1: NetworkManager（nmcli）を使用

```bash
# 利用可能なWi-Fiを確認
nmcli dev wifi list

# ez Shareに接続（パスワードなしの場合）
nmcli dev wifi connect ezShare

# パスワードありの場合（初期パスワード: 12345678）
nmcli dev wifi connect ezShare password 12345678
```

### 方法2: wpa_supplicant設定（永続化）

`/etc/wpa_supplicant/wpa_supplicant.conf` に追加：

```
network={
    ssid="ezShare"
    psk="12345678"
    priority=1
}
```

設定反映：

```bash
sudo wpa_cli -i wlan0 reconfigure
```

### 接続確認

```bash
# ez Share APIにアクセス
curl http://192.168.4.1/cgi-bin/ezshare.cgi?op=ls

# 正常な場合、ファイルリストが返ります
```

---

## Google Drive設定（rclone）

### Step 1: rclone設定開始

```bash
rclone config
```

### Step 2: 新しいリモート作成

```
n) New remote
name> gdrive
Type of storage> drive
Google Application Client Id> （空Enter）
Google Application Client Secret> （空Enter）
scope> 1  # Full access
service_account_file> （空Enter）
Edit advanced config?> n
Use web browser to automatically authenticate?> n
```

### Step 3: 認証URLの取得

表示されたURLをブラウザで開き、Googleアカウントでログイン後、認証コードをコピー

```
Enter verification code> （認証コードを貼り付け）
Configure this as a Shared Drive?> n
Yes this is OK> y
```

### Step 4: 設定確認

```bash
rclone lsd gdrive:
```

Google Driveのフォルダ一覧が表示されればOK

### Step 5: RX1Rフォルダの作成

```bash
rclone mkdir gdrive:RX1R
```

---

## 動作確認

### 1. 手動実行テスト

```bash
~/sync_rx1r_ezshare.sh
```

### 2. ログ確認

```bash
tail -f ~/rx1r/sync.log
```

### 3. データベース確認

```bash
sqlite3 ~/rx1r/db/uploaded.db "SELECT * FROM uploaded ORDER BY uploaded_at DESC LIMIT 5;"
```

### 4. Google Drive確認

```bash
rclone ls gdrive:RX1R
```

---

## 自動実行設定（cron）

### cronジョブの追加

```bash
crontab -e
```

以下を追加：

```cron
# RX1R自動同期（5分間隔）
*/5 * * * * /home/pi/sync_rx1r_ezshare.sh >> /home/pi/rx1r/cron.log 2>&1
```

### cron間隔の調整例

```cron
# 1分間隔（大量撮影時）
* * * * * /home/pi/sync_rx1r_ezshare.sh

# 10分間隔（通常使用）
*/10 * * * * /home/pi/sync_rx1r_ezshare.sh

# 30分間隔（省電力モード）
*/30 * * * * /home/pi/sync_rx1r_ezshare.sh
```

### cron動作確認

```bash
# cronログ確認
grep CRON /var/log/syslog | tail -20

# 実行ログ確認
tail -f ~/rx1r/cron.log
```

---

## トラブルシューティング

### 問題1: ez Shareに接続できない

**症状**: `curl http://192.168.4.1` でタイムアウト

**解決策**:
1. Wi-Fi接続確認
   ```bash
   nmcli dev wifi
   ```
2. ez ShareのSSIDが見えるか確認
   ```bash
   nmcli dev wifi list | grep ezShare
   ```
3. 手動接続
   ```bash
   nmcli dev wifi connect ezShare
   ```

### 問題2: ファイルリストが取得できない

**症状**: `cgi-bin/ezshare.cgi` が404エラー

**解決策**:
- お使いのez Shareカードが対応していない可能性があります
- 代替API: `http://192.168.4.1/dir?dir=A:` を試してください
- `scripts/sync_rx1r_ezshare.sh` の `BASE_URL` 設定を変更

### 問題3: Google Driveアップロード失敗

**症状**: `rclone copy` がエラー

**解決策**:
1. rclone設定確認
   ```bash
   rclone config show
   ```
2. 認証再実行
   ```bash
   rclone config reconnect gdrive:
   ```
3. 接続テスト
   ```bash
   rclone lsd gdrive:
   ```

### 問題4: 重複アップロード

**症状**: 同じファイルが何度もアップロードされる

**解決策**:
1. データベース整合性確認
   ```bash
   sqlite3 ~/rx1r/db/uploaded.db ".schema"
   ```
2. 同期スクリプトの多重起動チェック
   ```bash
   ps aux | grep sync_rx1r_ezshare.sh
   ```

### 問題5: EXIF情報が消える

**症状**: アップロード後のファイルにEXIFデータがない

**解決策**:
- `rclone copy` を使用していることを確認（`rclone move` は非推奨）
- テスト:
  ```bash
  exiftool ~/rx1r/tmp/*.ARW  # ダウンロード直後
  # スクリプト内の rm をコメントアウトして確認
  ```

---

## メンテナンス

### ログのローテーション

```bash
# ログファイルが大きくなった場合
> ~/rx1r/sync.log
> ~/rx1r/cron.log
```

または、logrotateを設定：

```bash
sudo nano /etc/logrotate.d/rx1r-sync
```

内容：
```
/home/pi/rx1r/*.log {
    weekly
    rotate 4
    compress
    missingok
    notifempty
}
```

### データベースのバックアップ

```bash
# 定期的にバックアップ
cp ~/rx1r/db/uploaded.db ~/rx1r/db/uploaded.db.backup
```

### アップロード済みファイルの確認

```bash
# 件数確認
sqlite3 ~/rx1r/db/uploaded.db "SELECT COUNT(*) FROM uploaded;"

# 最新10件
sqlite3 ~/rx1r/db/uploaded.db "SELECT path, datetime(uploaded_at, 'localtime') FROM uploaded ORDER BY uploaded_at DESC LIMIT 10;"

# 容量確認
sqlite3 ~/rx1r/db/uploaded.db "SELECT SUM(size)/1024/1024 || ' MB' FROM uploaded;"
```

### ez Share SD カードの健全性確認

```bash
# カード内のファイル数確認
curl -s http://192.168.4.1/cgi-bin/ezshare.cgi?op=ls | grep -c '\.(ARW\|JPG)'
```

---

## 付録

### 使用ツールのドキュメント

- **rclone**: https://rclone.org/docs/
- **SQLite**: https://sqlite.org/docs.html
- **ez Share API**: 機種により異なる（`/cgi-bin/ezshare.cgi?op=help` で確認）

### ディレクトリ構成（Pi上）

```
$HOME/
├── rx1r/
│   ├── tmp/              # 一時ダウンロード先
│   ├── db/
│   │   └── uploaded.db   # アップロード管理DB
│   ├── sync.log          # 同期ログ
│   └── cron.log          # cronログ
└── sync_rx1r_ezshare.sh  # 同期スクリプト
```

### よくある質問（FAQ）

**Q1: SDカードをカメラから抜く必要はありますか？**
A: いいえ、ez Share SDは入れっぱなしで使用します。

**Q2: カメラの電源が入っていないと同期できませんか？**
A: ez Shareは電源OFF後もしばらくWi-Fiを提供します（機種による）。

**Q3: RAWファイルのアップロードは時間がかかりますか？**
A: RX1RのARWファイルは約25MB程度です。ez ShareのWi-Fi速度次第ですが、1ファイルあたり30秒〜1分程度が目安です。

**Q4: Google Driveの容量が足りなくなったら？**
A: rclone設定で別のGoogle Driveアカウントを追加するか、外付けHDDに変更できます。

---

**最終更新**: 2025-12-28
**バージョン**: 1.0
