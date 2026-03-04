# PulseMon

macOS Task Manager — Windows Task Manager style process viewer and system monitor.

## Install

### Download (Recommended)

1. [Releases](https://github.com/LowAHN/PulseMon/releases) 페이지에서 `PulseMon.dmg` 다운로드
2. DMG를 열고 `PulseMon.app`을 `/Applications`로 드래그
3. 최초 실행 시 **System Settings > Privacy & Security**에서 "Open Anyway" 클릭

> Ad-hoc 서명이므로 Gatekeeper 경고가 표시됩니다. `xattr -cr /Applications/PulseMon.app` 으로 해제할 수도 있습니다.

### Build from Source

```bash
git clone https://github.com/LowAHN/PulseMon.git
cd PulseMon
make release    # .app bundle 생성
open PulseMon.app
```

## Features

- **Process Tab** — Real-time process list (Name, PID, CPU%, Memory, User, Status)
- **Right-click Context Menu** — Terminate (SIGTERM) / Force Kill (SIGKILL)
- **Column Sorting** — Click column headers to sort
- **Search** — Filter processes by name or PID
- **Performance Tab** — Real-time CPU, Memory, Network graphs (60-second history)
- **Keyboard Shortcuts** — ⌘Q Quit, ⌘F Search, Delete to terminate process

## Performance

| Metric | Value |
|--------|-------|
| Refresh cycle | ~5ms (process tab 2s interval) |
| Peak memory | ~10 MB |
| Binary size | ~270 KB |

## Requirements

- macOS 13.0+
- Swift 5.9+ (build from source only)

## License

MIT
