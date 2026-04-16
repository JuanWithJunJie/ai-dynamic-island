# MacIrland Homebrew Formula

Install MacIrland via [Homebrew](https://brew.sh/):

```bash
brew install JuanWithJunJie/macirland/macirland
```

Or tap first:

```bash
brew tap JuanWithJunJie/macirland
brew install macirland
```

## What is MacIrland?

MacIrland is a macOS AI CLI session observer that displays Claude Code status in a Dynamic Island-style interface at the top of your screen.

## Features

- Real-time Claude Code session status (running, waiting, completed)
- Multi-session management with Terminal/iTerm2 jump
- 8-bit chiptune sound notifications
- Hover expand with session details

## Requirements

- macOS 14+
- Claude Code hook installed (done automatically on first install)

## Usage

After installation:
1. Open MacIrland from `/Applications`
2. Grant Automation permissions in System Settings
3. Restart Claude Code

## Uninstall

```bash
brew uninstall macirland
rm -rf ~/.claude/hooks/macirland.py
```
