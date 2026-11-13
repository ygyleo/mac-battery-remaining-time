# Battery Time Implementation Plan

**Goal:** Ship a minimal native battery time menu app and public source + DMG.

**Architecture:** A pure BatteryCore module owns power-source parsing and localized presentation. AppKit reads system power notifications and renders the menu; SwiftUI renders two settings. Scripts build arm64 and package the DMG.

**Tech Stack:** Swift 5.9+, AppKit, SwiftUI, IOKit, ServiceManagement, XcodeGen.

**Spec:** ../specs/2026-11-13-battery-time-design.md

## Global constraints

- macOS 13+, Apple Silicon only, no third-party runtime dependencies.
- Exactly two settings: Chinese/English and launch at login.
- Credentials excluded from git and release artifacts.

## Tasks

- [x] BatteryCore: parse internal batteries, validate capacities and time estimates, localize time/status; test thresholds, missing values, AC transitions and both languages.
- [x] Native app: NSStatusItem and NSMenu with two data rows; system power events plus low-frequency refresh and wake refresh; SwiftUI settings persisted through UserDefaults and real SMAppService status.
- [x] Packaging: restrained app icon, reproducible build and drag-install DMG, architecture and signature validation.
- [x] Review and release: inspect native UI, run all core tests and release build, inspect tracked files for secrets, publish MIT public repo and v1.0.0 release.

## Review focus

Unknown estimates after wake/unplug must not become zero; peripherals must not count as the internal battery; switching language updates an open settings window and menu; denied login-item permission cannot look enabled; DMG app must run and contain arm64 only.
