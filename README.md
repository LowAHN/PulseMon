# PulseMon

macOS Task Manager — Windows Task Manager style process viewer and system monitor.

## Features

- **Process Tab** — Real-time process list (Name, PID, CPU%, Memory, User, Status)
- **Right-click Context Menu** — Terminate (SIGTERM) / Force Kill (SIGKILL)
- **Column Sorting** — Click column headers to sort
- **Search** — Filter processes by name or PID
- **Performance Tab** — Real-time CPU, Memory, Network graphs (60-second history)
- **Keyboard Shortcuts** — ⌘Q Quit, ⌘F Search, Delete to terminate process

## Build & Run

```bash
# Build
make build

# Run directly
make run

# Create .app bundle
make app

# Release build
make release
```

## Requirements

- macOS 13.0+
- Swift 5.9+
