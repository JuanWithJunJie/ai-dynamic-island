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

## Structure

- `MacIrlandApp/` — app lifecycle, AppKit bridge, status item, panel coordinator
- `MacIrlandKit/` — core models, adapters, services, SwiftUI views, mock data
- `MacIrlandTests/` — unit tests for aggregation and reply validation
- `docs/` — product and requirements documentation

## Notes

Local verification is currently blocked by the machine's Apple developer toolchain setup:

- `swift test` fails in the active CommandLineTools environment due to an `llbuild` runtime mismatch
- `xcodebuild` is unavailable because full Xcode is not selected as the active developer directory

Once full Xcode is configured, the next steps are:

1. run `swift test`
2. optionally create/open an Xcode project or package workspace
3. replace mock observation/reply services with real macOS integrations
4. refine panel anchoring and animation to feel closer to a true dynamic-island interaction
