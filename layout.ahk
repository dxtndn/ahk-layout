#Requires AutoHotkey v2.0
#SingleInstance Force

#Include "lib/window.ahk"

; ============================================
; Window Layout Manager
; Modifier: Ctrl+Shift
; ============================================

; --- Halves (Arrow Keys) ---
^+Left::SnapToZone("left")
^+Right::SnapToZone("right")
^+Up::SnapToZone("top")
^+Down::SnapToZone("bottom")

; --- Quadrants (U/I/J/K) ---
^+u::SnapToZone("topleft")
^+i::SnapToZone("topright")
^+j::SnapToZone("bottomleft")
^+k::SnapToZone("bottomright")

; --- Thirds (1/2/3) ---
^+1::SnapToZone("third1")
^+2::SnapToZone("third2")
^+3::SnapToZone("third3")

; --- Special ---
^+c::SnapToZone("center")
^+,::MoveToMonitor("prev")
^+.::MoveToMonitor("next")
^+Tab::ShowCollage()

; --- Save/Restore Layout ---
^+s::ShowSaveDialog()
^+a::ShowRestoreDialog()
