#Requires AutoHotkey v2.0

#Include "monitor.ahk"

; Global storage for saved window positions
global SavedWindowPositions := Map()

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

; Get all visible, normal windows
GetAllWindows() {
    windows := []
    for hwnd in WinGetList() {
        ; Skip windows that aren't visible or are special
        if (!WinExist(hwnd))
            continue

        style := WinGetStyle(hwnd)
        exStyle := WinGetExStyle(hwnd)

        ; Must be visible (WS_VISIBLE = 0x10000000)
        if (!(style & 0x10000000))
            continue

        ; Skip tool windows (WS_EX_TOOLWINDOW = 0x80)
        if (exStyle & 0x80)
            continue

        ; Must have a title
        title := WinGetTitle(hwnd)
        if (title = "")
            continue

        ; Skip minimized windows
        if (WinGetMinMax(hwnd) = -1)
            continue

        ; Skip tiny windows (likely hidden/system)
        WinGetPos(&x, &y, &w, &h, hwnd)
        if (w < 100 || h < 100)
            continue

        windows.Push(hwnd)
    }
    return windows
}

; Arrange all windows in a collage grid per monitor
ShowCollage() {
    windows := GetAllWindows()
    if (windows.Length = 0)
        return

    ; Group windows by monitor
    monitorCount := MonitorGetCount()
    monitorWindows := Map()
    Loop monitorCount {
        monitorWindows[A_Index] := []
    }

    for hwnd in windows {
        mon := GetWindowMonitor(hwnd)
        monitorWindows[mon].Push(hwnd)
    }

    ; Arrange windows on each monitor
    Loop monitorCount {
        wins := monitorWindows[A_Index]
        if (wins.Length = 0)
            continue

        area := GetMonitorWorkArea(A_Index)
        count := wins.Length

        ; Calculate grid dimensions
        cols := Ceil(Sqrt(count))
        rows := Ceil(count / cols)

        cellW := area.width // cols
        cellH := area.height // rows

        ; Position each window
        for i, hwnd in wins {
            ; Restore if maximized
            if (WinGetMinMax(hwnd) != 0)
                WinRestore(hwnd)

            col := Mod(i - 1, cols)
            row := (i - 1) // cols

            x := area.left + col * cellW
            y := area.top + row * cellH

            ; Adjust for borders
            borders := GetWindowBorders(hwnd)
            WinMove(x - borders.left, y - borders.top, cellW + borders.left + borders.right, cellH + borders.top + borders.bottom, hwnd)
        }
    }
}

; Save positions of all visible windows
SaveWindowPositions() {
    global SavedWindowPositions
    SavedWindowPositions := Map()

    windows := GetAllWindows()
    for hwnd in windows {
        WinGetPos(&x, &y, &w, &h, hwnd)
        SavedWindowPositions[hwnd] := {x: x, y: y, w: w, h: h}
    }
}

; Restore windows to their saved positions
RestoreWindowPositions() {
    global SavedWindowPositions

    if (SavedWindowPositions.Count = 0)
        return

    for hwnd, pos in SavedWindowPositions {
        ; Skip if window no longer exists
        if (!WinExist(hwnd))
            continue

        ; Restore if minimized/maximized
        if (WinGetMinMax(hwnd) != 0)
            WinRestore(hwnd)

        WinMove(pos.x, pos.y, pos.w, pos.h, hwnd)
    }
}
