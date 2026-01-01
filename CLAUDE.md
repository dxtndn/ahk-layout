# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AutoHotkey v2 window management tool. Provides keyboard shortcuts (Ctrl+Shift + key) for snapping windows to grid zones across multiple monitors.

## Running

Run `layout.ahk` with AutoHotkey v2.

## Architecture

```
layout.ahk           # Entry point, hotkey definitions
lib/
  monitor.ahk        # Monitor detection, zone calculations (GetZone, GetWindowMonitor)
  window.ahk         # Window manipulation (SnapToZone, MoveToMonitor)
```

- `lib/monitor.ahk` handles all monitor-related calculations including work area bounds and zone positions (halves, thirds, quadrants, center)
- `lib/window.ahk` provides the main functions used by hotkeys: `SnapToZone(zone)` and `MoveToMonitor(direction)`
- Hotkey modifier is `^+` (Ctrl+Shift)
