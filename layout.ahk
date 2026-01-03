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

; --- Thirds (Q/W/E) ---
^+q::SnapToZone("third1")
^+w::SnapToZone("third2")
^+e::SnapToZone("third3")

; --- Special ---
^+c::SnapToZone("center")
^+,::MoveToMonitor("prev")
^+.::MoveToMonitor("next")
^+Tab::ShowCollage()

; --- Save/Load Layout ---
^+s::ShowSaveDialog()
^+1::LoadSaveByIndex(1)
^+2::LoadSaveByIndex(2)
^+3::LoadSaveByIndex(3)
^+4::LoadSaveByIndex(4)
^+5::LoadSaveByIndex(5)
^+6::LoadSaveByIndex(6)
^+7::LoadSaveByIndex(7)
^+8::LoadSaveByIndex(8)
^+9::LoadSaveByIndex(9)
