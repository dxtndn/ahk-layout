# ahk-layout

Window management for Windows using AutoHotkey. Snap windows to zones with keyboard shortcuts.

## Requirements

- [AutoHotkey v2](https://www.autohotkey.com/)

## Installation

1. Install AutoHotkey v2
2. Run `layout.ahk`

To start automatically with Windows, place a shortcut to `layout.ahk` in your Startup folder (`shell:startup`).

## Keyboard Shortcuts

All shortcuts use `Ctrl+Shift` as the modifier.

### Halves

| Shortcut | Zone |
|----------|------|
| Ctrl+Shift+Left | Left half |
| Ctrl+Shift+Right | Right half |
| Ctrl+Shift+Up | Top half |
| Ctrl+Shift+Down | Bottom half |

### Quadrants

| Shortcut | Zone |
|----------|------|
| Ctrl+Shift+U | Top-left |
| Ctrl+Shift+I | Top-right |
| Ctrl+Shift+J | Bottom-left |
| Ctrl+Shift+K | Bottom-right |

### Thirds

| Shortcut | Zone |
|----------|------|
| Ctrl+Shift+1 | Left third |
| Ctrl+Shift+2 | Center third |
| Ctrl+Shift+3 | Right third |

### Special

| Shortcut | Action |
|----------|--------|
| Ctrl+Shift+C | Center window |
| Ctrl+Shift+, | Move to previous monitor |
| Ctrl+Shift+. | Move to next monitor |
| Ctrl+Shift+Tab | Show all windows in grid collage |

### Layout Saves

| Shortcut | Action |
|----------|--------|
| Ctrl+Shift+S | Open save dialog |
| Ctrl+Shift+A | Open restore dialog |

Save and restore window positions across sessions with unlimited named presets.

**Save Dialog:**
- Click a save to select it, or type a new name
- Double-click to quickly overwrite an existing save
- Buttons: Save, Rename, Delete, Cancel

**Restore Dialog:**
- Double-click a save to restore it immediately
- Buttons: Restore, Delete, Cancel

Saves are stored in the `saves/` folder as individual files.
