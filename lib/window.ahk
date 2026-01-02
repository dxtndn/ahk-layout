#Requires AutoHotkey v2.0

#Include "monitor.ahk"

; Get the invisible border size for a window (Windows 10/11 shadow borders)
GetWindowBorders(hwnd) {
    ; DWMWA_EXTENDED_FRAME_BOUNDS = 9
    rect := Buffer(16, 0)
    DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", hwnd, "UInt", 9, "Ptr", rect, "UInt", 16)
    frameLeft := NumGet(rect, 0, "Int")
    frameTop := NumGet(rect, 4, "Int")
    frameRight := NumGet(rect, 8, "Int")
    frameBottom := NumGet(rect, 12, "Int")

    WinGetPos(&winX, &winY, &winW, &winH, hwnd)

    return {
        left: frameLeft - winX,
        top: frameTop - winY,
        right: (winX + winW) - frameRight,
        bottom: (winY + winH) - frameBottom
    }
}

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

    ; Adjust for invisible window borders
    borders := GetWindowBorders(hwnd)
    WinMove(pos.x - borders.left, pos.y - borders.top, pos.w + borders.left + borders.right, pos.h + borders.top + borders.bottom, hwnd)
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

    ; Get actual visible bounds using extended frame
    borders := GetWindowBorders(hwnd)
    WinGetPos(&winX, &winY, &winW, &winH, hwnd)
    visibleX := winX + borders.left
    visibleY := winY + borders.top
    visibleW := winW - borders.left - borders.right
    visibleH := winH - borders.top - borders.bottom

    currentArea := GetMonitorWorkArea(currentMonitor)
    targetArea := GetMonitorWorkArea(targetMonitor)

    ; Calculate relative position (0-1 range) based on visible bounds
    relX := (visibleX - currentArea.left) / currentArea.width
    relY := (visibleY - currentArea.top) / currentArea.height
    relW := visibleW / currentArea.width
    relH := visibleH / currentArea.height

    ; Apply to target monitor
    newX := targetArea.left + Round(relX * targetArea.width)
    newY := targetArea.top + Round(relY * targetArea.height)
    newW := Round(relW * targetArea.width)
    newH := Round(relH * targetArea.height)

    ; Adjust for borders
    WinMove(newX - borders.left, newY - borders.top, newW + borders.left + borders.right, newH + borders.top + borders.bottom, hwnd)
}
