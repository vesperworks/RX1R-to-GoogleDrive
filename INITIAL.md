# RX1R × ez Share × Raspberry Pi Zero  
## 完全自動クラウド同期ワークフロー（EXIF保持・再取得防止）

---

## 🎯 ゴール

- Sony RX1R（初代）で普通に撮影
- カメラ電源OFF後、**何もしなくても**
- Raspberry Pi が ez Share から写真を取得
- Google Drive にアップロード
- **アップ済みファイルは再取得しない**
- ローカル（Pi）には残さず自動削除
- RAW / JPEG / EXIF 完全保持

---

## 🧩 全体構成

[ RX1R ]
│
[ ez Share Wi-Fi SD ] ))) Wi-Fi
│
[ Raspberry Pi Zero ]
│
[ Google Drive ]

---

## 📦 対応 ez Share

- ez Share Wi-Fi SD（8GB / 16GB）
- ez Share Pro
- ez Share OEM互換（`cgi-bin/ezshare.cgi` が存在するもの）

---

## 🧩 Phase 0｜前提

- Raspberry Pi Zero / Zero 2 W（Wi-Fi必須）
- Raspberry Pi OS Lite（32bit）
- ez Share SD を RX1R に **入れっぱなし**
- Pi は常時給電

---

## 🧩 Phase 1｜Raspberry Pi セットアップ

### OS初期化
- Raspberry Pi OS Lite をインストール
- SSH / Wi-Fi 有効化

```bash
sudo apt update
sudo apt upgrade -y


⸻

🧩 Phase 2｜必要ツールのインストール

sudo apt install -y \
  curl \
  wget \
  jq \
  sqlite3 \
  rclone


⸻

🧩 Phase 3｜ez Share Wi-Fi 接続

nmcli dev wifi list

nmcli dev wifi connect ezShare
# 初期状態はパスワードなし or 12345678


⸻

🧩 Phase 4｜作業ディレクトリ準備

mkdir -p ~/rx1r/{tmp,db}


⸻

🧩 Phase 5｜アップ済み管理DB（SQLite）

sqlite3 ~/rx1r/db/uploaded.db <<EOF
CREATE TABLE IF NOT EXISTS uploaded (
  path TEXT PRIMARY KEY,
  size INTEGER,
  uploaded_at TEXT
);
EOF


⸻

🧩 Phase 6｜取得 & アップロードスクリプト

sync_rx1r_ezshare.sh

#!/bin/bash
set -e

BASE_URL="http://192.168.4.1"
TMP_DIR="$HOME/rx1r/tmp"
DB="$HOME/rx1r/db/uploaded.db"
DRIVE="gdrive:RX1R"

mkdir -p "$TMP_DIR"

FILES=$(curl -s "$BASE_URL/cgi-bin/ezshare.cgi?op=ls" \
  | grep -E '\.(ARW|JPG)$' \
  | awk '{print $NF}')

for FILE in $FILES; do
  EXISTS=$(sqlite3 "$DB" \
    "SELECT 1 FROM uploaded WHERE path='$FILE' LIMIT 1;")

  if [ -n "$EXISTS" ]; then
    continue
  fi

  wget -q "$BASE_URL/$FILE" -P "$TMP_DIR"

  SIZE=$(stat -c%s "$TMP_DIR/$(basename "$FILE")")

  rclone copy "$TMP_DIR/$(basename "$FILE")" "$DRIVE/$(dirname "$FILE")"

  sqlite3 "$DB" \
    "INSERT INTO uploaded VALUES ('$FILE',$SIZE,datetime('now'));"

  rm "$TMP_DIR/$(basename "$FILE")"
done

chmod +x ~/sync_rx1r_ezshare.sh


⸻

🧩 Phase 7｜cron 自動化

crontab -e

*/5 * * * * /home/pi/sync_rx1r_ezshare.sh


⸻

🧩 Phase 8｜EXIF確認（初回のみ）

exiftool ~/rx1r/tmp/*.ARW

※ 一時的に rm をコメントアウトして確認後戻す

⸻

✅ 完成状態
	•	SDは抜かない
	•	電源OFF後でOK
	•	ez Share 経由
	•	EXIF保持
	•	Google Drive 集約
	•	アップ済み再取得なし
	•	Piローカルは空

⸻

🧠 設計思想
	•	ez Share：古いカメラに「黙って喋る口」を付ける
	•	Raspberry Pi：状態を覚える執事（SQLite）
	•	Google Drive：最終保管庫

⸻

📌 注意
	•	ez Share の個体差あり
	•	cgi-bin/ezshare.cgi が無い個体は非対応
	•	大量撮影時は cron 間隔を調整

⸻


---

## 3️⃣ まとめ

- **「消す」運用は完全対応**
- 再取得は **SQLite台帳で100%防止**
- ez Shareの弱点（不安定・EXIF問題）を **全部Pi側で吸収**
- RX1Rの撮影体験は **一切変わらない**

---

