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

    ; Save original position
    WinGetPos(&origX, &origY, &origW, &origH, hwnd)

    monitorNum := GetWindowMonitor(hwnd)
    pos := GetZone(monitorNum, zone)
    area := GetMonitorWorkArea(monitorNum)

    ; Adjust for invisible window borders
    borders := GetWindowBorders(hwnd)
    targetW := pos.w + borders.left + borders.right
    targetH := pos.h + borders.top + borders.bottom

    WinMove(pos.x - borders.left, pos.y - borders.top, targetW, targetH, hwnd)
    Sleep(20)

    ; Get actual position and visible bounds after move
    borders := GetWindowBorders(hwnd)
    WinGetPos(&newX, &newY, &newW, &newH, hwnd)
    visibleLeft := newX + borders.left
    visibleTop := newY + borders.top
    visibleRight := newX + newW - borders.right
    visibleBottom := newY + newH - borders.bottom

    ; Check if window is fully contained within monitor work area
    if (visibleLeft < area.left - 5
        || visibleTop < area.top - 5
        || visibleRight > area.right + 5
        || visibleBottom > area.bottom + 5) {
        ; Window goes off screen, restore original position
        WinMove(origX, origY, origW, origH, hwnd)
    }
}

; Move active window to an adjacent monitor, keeping relative position
MoveToMonitor(direction) {
    hwnd := WinExist("A")
    if (!hwnd)
        return

    ; Restore window if maximized
    if (WinGetMinMax(hwnd) != 0)
        WinRestore(hwnd)

    ; Save original position
    WinGetPos(&origX, &origY, &origW, &origH, hwnd)

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
    Sleep(20)

    ; Check if window is fully contained within target monitor work area
    borders := GetWindowBorders(hwnd)
    WinGetPos(&finalX, &finalY, &finalW, &finalH, hwnd)
    visibleLeft := finalX + borders.left
    visibleTop := finalY + borders.top
    visibleRight := finalX + finalW - borders.right
    visibleBottom := finalY + finalH - borders.bottom

    if (visibleLeft < targetArea.left - 5
        || visibleTop < targetArea.top - 5
        || visibleRight > targetArea.right + 5
        || visibleBottom > targetArea.bottom + 5) {
        ; Window goes off screen, restore original position
        WinMove(origX, origY, origW, origH, hwnd)
    }
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

        ; Track windows that don't fit in grid
        overflowWindows := []

        ; Position each window
        for i, hwnd in wins {
            ; Restore if maximized
            if (WinGetMinMax(hwnd) != 0)
                WinRestore(hwnd)

            col := Mod(i - 1, cols)
            row := (i - 1) // cols

            x := area.left + col * cellW
            y := area.top + row * cellH
            cellRight := x + cellW
            cellBottom := y + cellH

            ; Adjust for borders
            borders := GetWindowBorders(hwnd)
            WinMove(x - borders.left, y - borders.top, cellW + borders.left + borders.right, cellH + borders.top + borders.bottom, hwnd)
            Sleep(20)

            ; Check if window fits in its cell
            borders := GetWindowBorders(hwnd)
            WinGetPos(&newX, &newY, &newW, &newH, hwnd)
            visibleRight := newX + newW - borders.right
            visibleBottom := newY + newH - borders.bottom

            if (visibleRight > cellRight + 5 || visibleBottom > cellBottom + 5) {
                ; Window doesn't fit in grid cell
                overflowWindows.Push(hwnd)
            }
        }

        ; Cascade overflow windows on the same monitor
        if (overflowWindows.Length > 0) {
            cascadeOffset := 0
            for hwnd in overflowWindows {
                borders := GetWindowBorders(hwnd)
                WinGetPos(, , &winW, &winH, hwnd)

                ; Calculate cascade position
                newX := area.left + cascadeOffset
                newY := area.top + cascadeOffset

                ; Check if it fits on this monitor
                visibleRight := newX + winW
                visibleBottom := newY + winH

                if (visibleRight <= area.right + 5 && visibleBottom <= area.bottom + 5) {
                    ; Fits on same monitor, cascade here
                    WinMove(newX - borders.left, newY - borders.top, winW, winH, hwnd)
                } else if (monitorCount > 1) {
                    ; Doesn't fit, move to another monitor
                    targetMon := (A_Index = 1) ? 2 : 1
                    targetArea := GetMonitorWorkArea(targetMon)
                    WinMove(targetArea.left - borders.left, targetArea.top - borders.top, winW, winH, hwnd)
                }

                cascadeOffset += 50
            }
        }
    }
}

; Get the save file path
GetSaveFilePath() {
    return A_ScriptDir . "\saved_positions.txt"
}

; Save positions of all visible windows to file
SaveWindowPositions() {
    windows := GetAllWindows()
    saveFile := GetSaveFilePath()

    ; Delete old file
    if (FileExist(saveFile))
        FileDelete(saveFile)

    for hwnd in windows {
        WinGetPos(&x, &y, &w, &h, hwnd)
        procPath := WinGetProcessPath(hwnd)

        ; Save as: processPath<TAB>x<TAB>y<TAB>w<TAB>h
        line := procPath . "`t" . x . "`t" . y . "`t" . w . "`t" . h . "`n"
        FileAppend(line, saveFile)
    }
}

; Restore windows to their saved positions from file
RestoreWindowPositions() {
    saveFile := GetSaveFilePath()

    if (!FileExist(saveFile))
        return

    ; Build a list of positions to restore (in order)
    positions := []
    fileContent := FileRead(saveFile)
    lines := StrSplit(fileContent, "`n")

    for line in lines {
        if (line = "")
            continue

        parts := StrSplit(line, "`t")
        if (parts.Length < 5)
            continue

        try {
            positions.Push({
                procPath: parts[1],
                x: Integer(parts[2]),
                y: Integer(parts[3]),
                w: Integer(parts[4]),
                h: Integer(parts[5])
            })
        }
    }

    ; Get current windows and match them to saved positions
    windows := GetAllWindows()
    usedPositions := Map()

    for hwnd in windows {
        procPath := WinGetProcessPath(hwnd)

        ; Find a matching position that hasn't been used
        for i, pos in positions {
            if (usedPositions.Has(i))
                continue

            if (pos.procPath = procPath) {
                ; Restore if minimized/maximized
                if (WinGetMinMax(hwnd) != 0)
                    WinRestore(hwnd)

                WinMove(pos.x, pos.y, pos.w, pos.h, hwnd)
                usedPositions[i] := true
                break
            }
        }
    }
}
