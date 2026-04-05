# AI Dynamic Island

A native macOS SwiftUI + AppKit scaffold for an AI CLI task hub inspired by the project spec in `docs/superpowers/specs/2026-04-05-mac-ai-cli-dynamic-island-design.md`.

## Current status

This repository currently contains the first MVP scaffold:

- Swift Package based macOS app structure
- `MacIrlandApp` executable target
- `MacIrlandKit` shared domain/UI/services module
- `MacIrlandTests` test target
- mock adapters for Codex / Claude Code / Gemini CLI
- normalized task/session models, state store, diagnostics and panel UI
- status bar capsule prototype for a dynamic-island-like summary surface
- dark floating panel prototype for richer task detail review
- configurable mock observation mode (`静态样例` / `动态轮播`) in Settings and directly inside the panel
- configurable auto-refresh cadence for the prototype timeline
- lightweight recent-history and recovery guidance blocks for task wrap-up states
- clearer panel information architecture for realtime overview, controls, active task, history, and diagnostics

## Structure

- `MacIrlandApp/` — app lifecycle, AppKit bridge, status item, panel coordinator
- `MacIrlandKit/` — core models, adapters, services, SwiftUI views, mock data
- `MacIrlandTests/` — unit tests for aggregation and reply validation
- `docs/` — product and requirements documentation

## Notes

Local verification is currently blocked by the machine's Apple developer toolchain setup:

- `swift test` currently prompts for installing developer tools because no active Apple developer directory is selected
- `xcodebuild` is unavailable because full Xcode is not selected as the active developer directory

Once full Xcode is configured, the next steps are:

1. run `swift test`
2. launch the app and verify the Settings-driven and panel-driven prototype controls update the live status bar/panel behavior
3. replace mock observation/reply services with real macOS integrations
4. refine panel anchoring and animation to feel closer to a true dynamic-island interaction
