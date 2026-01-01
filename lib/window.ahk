#Requires AutoHotkey v2.0

#Include "monitor.ahk"

; Move and resize the active window to a specific zone
SnapToZone(zone) {
    hwnd := WinExist("A")
    if (!hwnd)
        return

    ; Restore window if maximized
    if (WinGetMinMax(hwnd) != 0)
        WinRestore(hwnd)

    monitorNum := GetWindowMonitor(hwnd)
    pos := GetZone(monitorNum, zone)
    WinMove(pos.x, pos.y, pos.w, pos.h, hwnd)
}

; Move active window to an adjacent monitor, keeping relative position
MoveToMonitor(direction) {
    hwnd := WinExist("A")
    if (!hwnd)
        return

    ; Restore window if maximized
    if (WinGetMinMax(hwnd) != 0)
        WinRestore(hwnd)

    currentMonitor := GetWindowMonitor(hwnd)
    targetMonitor := GetAdjacentMonitor(currentMonitor, direction)

    ; Get current window position relative to current monitor
    WinGetPos(&winX, &winY, &winW, &winH, hwnd)
    currentArea := GetMonitorWorkArea(currentMonitor)
    targetArea := GetMonitorWorkArea(targetMonitor)

    ; Calculate relative position (0-1 range)
    relX := (winX - currentArea.left) / currentArea.width
    relY := (winY - currentArea.top) / currentArea.height
    relW := winW / currentArea.width
    relH := winH / currentArea.height

    ; Apply to target monitor
    newX := targetArea.left + Round(relX * targetArea.width)
    newY := targetArea.top + Round(relY * targetArea.height)
    newW := Round(relW * targetArea.width)
    newH := Round(relH * targetArea.height)

    WinMove(newX, newY, newW, newH, hwnd)
}
