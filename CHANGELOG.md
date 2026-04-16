# Changelog

All notable changes to MacIrland will be documented in this file.

## [0.1.0] - 2026-04-16

### Added
- Island-first UI with real-time Claude Code status display
- Hook-first session identity via Unix Domain Socket
- Hover expand with session list and details
- 8-bit chiptune sound feedback (Super Mario power-up style)
- TTY-first terminal session jump (Terminal.app / iTerm2)
- Multi-session management
- Hook auto-sync on app launch
- Animated running status icon (terminal + 4 animated dots)
- Sound toggle in hover expand panel
- GitHub Release workflow with automated build scripts

### Fixed
- Session status mapping (`.stop` → waiting, `.sessionEnd` → completed)
- Observation refresh no longer overwrites hook-derived status
- TTY-first session matching for reliable terminal jump

### Requirements
- macOS 14+
- Claude Code with hook installed
