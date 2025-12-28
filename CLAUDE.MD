# CLAUDE.MD - Project Context

## Project Overview

**RX1R to Google Drive Automatic Sync System**

This project implements a fully automated photo synchronization workflow for the Sony RX1R camera using an ez Share Wi-Fi SD card and Raspberry Pi Zero. Photos are automatically transferred to Google Drive with EXIF data preservation and duplicate prevention.

## System Architecture

```
[Sony RX1R Camera]
        ↓
[ez Share Wi-Fi SD Card] ))) Wi-Fi
        ↓
[Raspberry Pi Zero]
        ↓
[Google Drive]
```

## Key Features

- **Zero-touch operation**: Camera powers off, photos sync automatically
- **Duplicate prevention**: SQLite database tracks uploaded files
- **EXIF preservation**: Maintains all metadata for RAW/JPEG files
- **Auto-cleanup**: Local temporary files deleted after upload
- **File format support**: ARW (RAW) and JPG files

## Technical Stack

- **Hardware**: Raspberry Pi Zero/Zero 2 W with Wi-Fi
- **OS**: Raspberry Pi OS Lite (32-bit)
- **Storage Card**: ez Share Wi-Fi SD (8GB/16GB or compatible)
- **Cloud Storage**: Google Drive via rclone
- **Database**: SQLite3 for upload tracking
- **Automation**: cron (5-minute intervals)

## Project Structure

```
~/rx1r/
├── tmp/              # Temporary download directory
├── db/
│   └── uploaded.db   # SQLite database tracking uploaded files
└── sync_rx1r_ezshare.sh  # Main sync script
```

## Core Components

### 1. ez Share Integration
- **Base URL**: `http://192.168.4.1`
- **API Endpoint**: `/cgi-bin/ezshare.cgi?op=ls`
- **Connection**: Direct Wi-Fi (SSID: ezShare)
- **File Access**: HTTP download via wget

### 2. Upload Tracking Database

**Schema**:
```sql
CREATE TABLE uploaded (
  path TEXT PRIMARY KEY,
  size INTEGER,
  uploaded_at TEXT
);
```

**Purpose**: Prevent re-downloading and re-uploading files that have already been processed.

### 3. Sync Script (`sync_rx1r_ezshare.sh`)

**Workflow**:
1. Query ez Share for available files (ARW/JPG)
2. Check each file against SQLite database
3. Download new files to temporary directory
4. Upload to Google Drive using rclone
5. Record upload in database
6. Delete local temporary file

**Execution**: Runs every 5 minutes via cron

### 4. Google Drive Configuration
- **rclone remote name**: `gdrive:RX1R`
- **Directory structure**: Preserves original ez Share folder structure
- **Transfer method**: rclone copy (preserves EXIF)

## Important Design Principles

1. **Non-invasive**: RX1R shooting experience remains unchanged
2. **Stateful**: SQLite prevents duplicate transfers
3. **Resilient**: Handles ez Share instability and individual device differences
4. **Clean**: No local storage accumulation on Pi

## Development Guidelines

### When Working on This Project

1. **Never modify EXIF data**: Preserve all camera metadata
2. **Always check database first**: Prevent duplicate downloads
3. **Handle network failures gracefully**: ez Share can be unstable
4. **Test with actual file formats**: ARW (RAW) and JPG must both work
5. **Consider SD card compatibility**: Not all ez Share devices support `cgi-bin/ezshare.cgi`

### Common Tasks

**Check uploaded files**:
```bash
sqlite3 ~/rx1r/db/uploaded.db "SELECT * FROM uploaded ORDER BY uploaded_at DESC LIMIT 10;"
```

**Verify EXIF preservation**:
```bash
exiftool ~/rx1r/tmp/*.ARW  # Comment out rm in script first
```

**Test sync manually**:
```bash
~/sync_rx1r_ezshare.sh
```

**Check cron schedule**:
```bash
crontab -l
```

## Known Limitations

1. **ez Share variance**: Individual devices may have different APIs
2. **API requirement**: Requires `cgi-bin/ezshare.cgi` endpoint
3. **Network stability**: ez Share Wi-Fi can be unreliable
4. **Sync interval**: 5-minute cron interval (adjustable for heavy shooting)
5. **Single camera support**: Designed for one RX1R camera workflow

## Dependencies

**System packages**:
- curl
- wget
- jq
- sqlite3
- rclone

**External services**:
- Google Drive account
- Configured rclone remote

## Troubleshooting

### Photos not syncing
1. Check Pi Wi-Fi connection to ezShare
2. Verify ez Share API endpoint: `curl http://192.168.4.1/cgi-bin/ezshare.cgi?op=ls`
3. Check cron logs: `grep CRON /var/log/syslog`

### Duplicate uploads
1. Verify database integrity: `sqlite3 ~/rx1r/db/uploaded.db ".schema"`
2. Check for concurrent script executions

### EXIF data loss
1. Verify rclone preserves metadata
2. Test with exiftool before and after upload

## Future Enhancement Ideas

- Web dashboard for upload status
- Email notifications on errors
- Support for multiple cameras
- Automatic SD card health monitoring
- RAW conversion options

## References

- ez Share API documentation (varies by device)
- rclone documentation: https://rclone.org/
- Sony RX1R specifications
- Raspberry Pi Zero setup guides

---

**Last Updated**: 2025-12-28
**Project Status**: Initial setup phase
**Maintainer**: User
