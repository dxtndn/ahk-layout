#Requires AutoHotkey v2.0

#Include "monitor.ahk"

; Migrate old saved_positions.txt to new saves system
MigrateOldSave() {
    oldFile := A_ScriptDir . "\saved_positions.txt"
    if (FileExist(oldFile)) {
        result := MsgBox("Found an existing window layout save.`nWould you like to import it to the new multi-save system?", "Migrate Layout Save", "YesNo Icon?")
        if (result = "Yes") {
            newFile := GetSavesDir() . "\Migrated.txt"
            FileMove(oldFile, newFile, false)
            MsgBox("Saved as 'Migrated'. You can rename it using Ctrl+Shift+S.", "Migration Complete", "Icon!")
        } else {
            FileDelete(oldFile)
        }
    }
}
MigrateOldSave()

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

; ============================================
; Multi-Save Window Position Manager
; ============================================

; Get the saves directory path, create if needed
GetSavesDir() {
    dir := A_ScriptDir . "\saves"
    if (!DirExist(dir))
        DirCreate(dir)
    return dir
}

; Get array of all save names (without .txt extension), sorted by creation time
GetAllSaves() {
    saves := []
    dir := GetSavesDir()
    Loop Files dir . "\*.txt" {
        name := RegExReplace(A_LoopFileName, "\.txt$", "")
        saves.Push({name: name, time: A_LoopFileTimeCreated})
    }
    ; Sort by creation time (oldest first, newest at end)
    SortByTime(saves)
    ; Extract just the names
    names := []
    for item in saves {
        names.Push(item.name)
    }
    return names
}

; Sort array of objects by time property (bubble sort)
SortByTime(arr) {
    n := arr.Length
    Loop n - 1 {
        i := A_Index
        Loop n - i {
            j := A_Index
            if (arr[j].time > arr[j + 1].time) {
                temp := arr[j]
                arr[j] := arr[j + 1]
                arr[j + 1] := temp
            }
        }
    }
}

; Save current window positions to a named slot
SaveToSlot(name) {
    windows := GetAllWindows()
    saveFile := GetSavesDir() . "\" . name . ".txt"

    if (FileExist(saveFile))
        FileDelete(saveFile)

    for hwnd in windows {
        WinGetPos(&x, &y, &w, &h, hwnd)
        procPath := WinGetProcessPath(hwnd)
        title := WinGetTitle(hwnd)
        ; Format: processPath<TAB>title<TAB>x<TAB>y<TAB>w<TAB>h
        line := procPath . "`t" . title . "`t" . x . "`t" . y . "`t" . w . "`t" . h . "`n"
        FileAppend(line, saveFile)
    }
}

; Load window positions from a named slot
LoadFromSlot(name) {
    saveFile := GetSavesDir() . "\" . name . ".txt"

    if (!FileExist(saveFile))
        return

    positions := []
    fileContent := FileRead(saveFile)
    lines := StrSplit(fileContent, "`n")

    for line in lines {
        if (line = "")
            continue

        parts := StrSplit(line, "`t")
        ; Support both old format (5 parts) and new format (6 parts with title)
        if (parts.Length < 5)
            continue

        try {
            if (parts.Length >= 6) {
                ; New format: procPath, title, x, y, w, h
                positions.Push({
                    procPath: parts[1],
                    title: parts[2],
                    x: Integer(parts[3]),
                    y: Integer(parts[4]),
                    w: Integer(parts[5]),
                    h: Integer(parts[6])
                })
            } else {
                ; Old format: procPath, x, y, w, h (no title)
                positions.Push({
                    procPath: parts[1],
                    title: "",
                    x: Integer(parts[2]),
                    y: Integer(parts[3]),
                    w: Integer(parts[4]),
                    h: Integer(parts[5])
                })
            }
        }
    }

    windows := GetAllWindows()
    usedPositions := Map()
    usedWindows := Map()

    ; First pass: match by process path AND title (exact match)
    for hwnd in windows {
        procPath := WinGetProcessPath(hwnd)
        title := WinGetTitle(hwnd)

        for i, pos in positions {
            if (usedPositions.Has(i))
                continue

            if (pos.procPath = procPath && pos.title = title && pos.title != "") {
                if (WinGetMinMax(hwnd) != 0)
                    WinRestore(hwnd)
                WinMove(pos.x, pos.y, pos.w, pos.h, hwnd)
                usedPositions[i] := true
                usedWindows[hwnd] := true
                break
            }
        }
    }

    ; Second pass: match remaining windows by process path only
    for hwnd in windows {
        if (usedWindows.Has(hwnd))
            continue

        procPath := WinGetProcessPath(hwnd)

        for i, pos in positions {
            if (usedPositions.Has(i))
                continue

            if (pos.procPath = procPath) {
                if (WinGetMinMax(hwnd) != 0)
                    WinRestore(hwnd)
                WinMove(pos.x, pos.y, pos.w, pos.h, hwnd)
                usedPositions[i] := true
                usedWindows[hwnd] := true
                break
            }
        }
    }

}

; Delete a named save
DeleteSave(name) {
    saveFile := GetSavesDir() . "\" . name . ".txt"
    if (FileExist(saveFile))
        FileDelete(saveFile)
}

; Rename a save
RenameSave(oldName, newName) {
    oldFile := GetSavesDir() . "\" . oldName . ".txt"
    newFile := GetSavesDir() . "\" . newName . ".txt"
    if (FileExist(oldFile))
        FileMove(oldFile, newFile, true)
}

; ============================================
; Save/Restore Dialog GUIs
; ============================================

; Apply dark mode styling to a GUI
ApplyDarkMode(guiObj) {
    ; Enable dark title bar (Windows 10 1809+ / Windows 11)
    ; DWMWA_USE_IMMERSIVE_DARK_MODE = 20
    DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", guiObj.Hwnd, "Int", 20, "Int*", 1, "Int", 4)

    ; Enable rounded corners (Windows 11)
    ; DWMWA_WINDOW_CORNER_PREFERENCE = 33, DWMWCP_ROUND = 2
    DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", guiObj.Hwnd, "Int", 33, "Int*", 2, "Int", 4)

    ; Dark background
    guiObj.BackColor := "1e1e1e"
}

; Create a dark styled button with rounded corners
AddDarkButton(guiObj, options, text, callback) {
    btn := guiObj.AddButton(options, text)
    btn.OnEvent("Click", callback)

    ; Get button dimensions and apply rounded corners
    btn.GetPos(,, &w, &h)
    radius := 8
    hRgn := DllCall("CreateRoundRectRgn", "Int", 0, "Int", 0, "Int", w, "Int", h, "Int", radius, "Int", radius, "Ptr")
    DllCall("SetWindowRgn", "Ptr", btn.Hwnd, "Ptr", hRgn, "Int", true)

    return btn
}

; Fade in animation for a GUI
FadeIn(guiObj, duration := 120) {
    guiObj.Opt("+E0x80000")  ; WS_EX_LAYERED
    steps := 12
    delay := duration // steps
    Loop steps {
        alpha := Round((A_Index / steps) * 255)
        DllCall("SetLayeredWindowAttributes", "Ptr", guiObj.Hwnd, "UInt", 0, "UChar", alpha, "UInt", 2)
        Sleep(delay)
    }
    guiObj.Opt("-E0x80000")  ; Remove layered style for better performance
}

; Enable dark mode for all controls in a GUI (call after Show)
EnableDarkControls(guiObj) {
    static DWMWA_USE_IMMERSIVE_DARK_MODE := 20
    ; Set preferred app mode to dark
    try {
        DllCall("uxtheme\SetPreferredAppMode", "Int", 2)  ; ForceDark
        DllCall("uxtheme\FlushMenuThemes")
    }
}

; Track if dialogs are open
global SaveDialogOpen := false
global RestoreDialogOpen := false

; Show the save dialog
ShowSaveDialog() {
    global SaveGui, SaveListView, SaveNameEdit, SaveDialogOpen

    if (SaveDialogOpen)
        return
    SaveDialogOpen := true

    SaveGui := Gui("+AlwaysOnTop", "Save Window Layout")
    SaveGui.OnEvent("Close", OnSaveClose)
    SaveGui.SetFont("s10", "Segoe UI")
    ApplyDarkMode(SaveGui)

    SaveGui.SetFont("s10 c99ccff", "Segoe UI")
    SaveGui.AddText(, "Click to select, or type a new name:")
    SaveGui.SetFont("s10 ce0e0e0", "Segoe UI")
    SaveListView := SaveGui.AddListView("w300 h150 -Multi -Hdr Background2d2d2d ce0e0e0", ["Name"])
    RefreshSaveList(SaveListView)

    SaveGui.SetFont("s10 ce0e0e0", "Segoe UI")
    SaveNameEdit := SaveGui.AddEdit("w300 Background2d2d2d ce0e0e0")

    SaveGui.SetFont("s9 cffffff", "Segoe UI")
    AddDarkButton(SaveGui, "xm w145 h30", "Save", OnSave)
    AddDarkButton(SaveGui, "x+10 w145 h30", "Rename", OnSaveRename)
    AddDarkButton(SaveGui, "xm w145 h30", "Delete", OnSaveDelete)
    AddDarkButton(SaveGui, "x+10 w145 h30", "Cancel", OnSaveCancel)

    SaveListView.OnEvent("ItemSelect", OnSaveListSelect)
    SaveListView.OnEvent("DoubleClick", OnSaveListDoubleClick)

    SaveGui.Show("Hide")
    FadeIn(SaveGui)
    SaveGui.Show()
}

; Refresh the save list in a ListView (with numbers)
RefreshSaveList(lv) {
    lv.Delete()
    saves := GetAllSaves()
    for i, name in saves {
        lv.Add(, i . ". " . name)
    }
    lv.ModifyCol(1, "AutoHdr")
}

; Get save name without the number prefix
StripNumber(text) {
    return RegExReplace(text, "^\d+\.\s*", "")
}

; Get selected save name from ListView (strips number prefix)
GetSelectedSave(lv) {
    row := lv.GetNext(0, "F")
    if (row = 0)
        return ""
    return StripNumber(lv.GetText(row, 1))
}

OnSave(*) {
    global SaveGui, SaveNameEdit, SaveDialogOpen
    name := Trim(SaveNameEdit.Value)
    if (name = "" || InStr(name, "\") || InStr(name, "/") || InStr(name, ":"))
        return
    SaveToSlot(name)
    SaveDialogOpen := false
    SaveGui.Destroy()
}

OnSaveListSelect(lv, item, selected) {
    global SaveNameEdit
    if (selected && item > 0) {
        SaveNameEdit.Value := StripNumber(lv.GetText(item, 1))
    }
}

OnSaveDelete(*) {
    global SaveListView
    name := GetSelectedSave(SaveListView)
    if (name = "")
        return
    DeleteSave(name)
    RefreshSaveList(SaveListView)
}

OnSaveRename(*) {
    global SaveListView, SaveNameEdit
    oldName := GetSelectedSave(SaveListView)
    newName := Trim(SaveNameEdit.Value)
    if (oldName = "" || newName = "" || InStr(newName, "\") || InStr(newName, "/") || InStr(newName, ":"))
        return
    RenameSave(oldName, newName)
    RefreshSaveList(SaveListView)
    SaveNameEdit.Value := newName
}

OnSaveCancel(*) {
    global SaveGui, SaveDialogOpen
    SaveDialogOpen := false
    SaveGui.Destroy()
}

OnSaveClose(*) {
    global SaveDialogOpen
    SaveDialogOpen := false
}

OnSaveListDoubleClick(lv, row) {
    global SaveGui, SaveDialogOpen
    if (row > 0) {
        name := StripNumber(lv.GetText(row, 1))
        SaveToSlot(name)
        SaveDialogOpen := false
        SaveGui.Destroy()
    }
}

; Show the restore dialog
ShowRestoreDialog() {
    global RestoreGui, RestoreListView, RestoreDialogOpen

    if (RestoreDialogOpen)
        return
    RestoreDialogOpen := true

    RestoreGui := Gui("+AlwaysOnTop", "Restore Window Layout")
    RestoreGui.OnEvent("Close", OnRestoreClose)
    RestoreGui.SetFont("s10", "Segoe UI")
    ApplyDarkMode(RestoreGui)

    RestoreGui.SetFont("s10 c99ccff", "Segoe UI")
    RestoreGui.AddText(, "Double-click to restore:")
    RestoreGui.SetFont("s10 ce0e0e0", "Segoe UI")
    RestoreListView := RestoreGui.AddListView("w300 h200 -Multi -Hdr Background2d2d2d ce0e0e0", ["Name"])
    RefreshSaveList(RestoreListView)

    RestoreGui.SetFont("s9 cffffff", "Segoe UI")
    AddDarkButton(RestoreGui, "xm w145 h30", "Restore", OnRestore)
    AddDarkButton(RestoreGui, "x+10 w145 h30", "Delete", OnRestoreDelete)
    AddDarkButton(RestoreGui, "xm w300 h30", "Cancel", OnRestoreCancel)

    RestoreListView.OnEvent("DoubleClick", OnRestoreDoubleClick)

    RestoreGui.Show("Hide")
    FadeIn(RestoreGui)
    RestoreGui.Show()
}

OnRestore(*) {
    global RestoreGui, RestoreListView, RestoreDialogOpen
    name := GetSelectedSave(RestoreListView)
    if (name = "")
        return
    RestoreDialogOpen := false
    RestoreGui.Destroy()
    LoadFromSlot(name)
}

OnRestoreDelete(*) {
    global RestoreListView
    name := GetSelectedSave(RestoreListView)
    if (name = "")
        return
    DeleteSave(name)
    RefreshSaveList(RestoreListView)
}

OnRestoreCancel(*) {
    global RestoreGui, RestoreDialogOpen
    RestoreDialogOpen := false
    RestoreGui.Destroy()
}

OnRestoreClose(*) {
    global RestoreDialogOpen
    RestoreDialogOpen := false
}

OnRestoreDoubleClick(lv, row) {
    global RestoreGui, RestoreDialogOpen
    if (row > 0) {
        name := StripNumber(lv.GetText(row, 1))
        RestoreDialogOpen := false
        RestoreGui.Destroy()
        LoadFromSlot(name)
    }
}
