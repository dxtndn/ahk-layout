#Requires AutoHotkey v2.0

; Get the monitor that contains the specified window
GetWindowMonitor(hwnd) {
    MonitorGetWorkArea(MonitorGetPrimary(), &left, &top, &right, &bottom)

    WinGetPos(&winX, &winY, &winW, &winH, hwnd)
    winCenterX := winX + (winW // 2)
    winCenterY := winY + (winH // 2)

    monitorCount := MonitorGetCount()
    Loop monitorCount {
        MonitorGetWorkArea(A_Index, &mLeft, &mTop, &mRight, &mBottom)
        if (winCenterX >= mLeft && winCenterX < mRight && winCenterY >= mTop && winCenterY < mBottom) {
            return A_Index
        }
    }
    return MonitorGetPrimary()
}

; Get work area bounds for a monitor
GetMonitorWorkArea(monitorNum) {
    MonitorGetWorkArea(monitorNum, &left, &top, &right, &bottom)
    return {left: left, top: top, right: right, bottom: bottom, width: right - left, height: bottom - top}
}

; Calculate zone position based on zone type
GetZone(monitorNum, zone) {
    area := GetMonitorWorkArea(monitorNum)

    switch zone {
        ; Halves
        case "left":
            return {x: area.left, y: area.top, w: area.width // 2, h: area.height}
        case "right":
            return {x: area.left + area.width // 2, y: area.top, w: area.width // 2, h: area.height}
        case "top":
            return {x: area.left, y: area.top, w: area.width, h: area.height // 2}
        case "bottom":
            return {x: area.left, y: area.top + area.height // 2, w: area.width, h: area.height // 2}

        ; Quadrants
        case "topleft":
            return {x: area.left, y: area.top, w: area.width // 2, h: area.height // 2}
        case "topright":
            return {x: area.left + area.width // 2, y: area.top, w: area.width // 2, h: area.height // 2}
        case "bottomleft":
            return {x: area.left, y: area.top + area.height // 2, w: area.width // 2, h: area.height // 2}
        case "bottomright":
            return {x: area.left + area.width // 2, y: area.top + area.height // 2, w: area.width // 2, h: area.height // 2}

        ; Thirds
        case "third1":
            return {x: area.left, y: area.top, w: area.width // 3, h: area.height}
        case "third2":
            return {x: area.left + area.width // 3, y: area.top, w: area.width // 3, h: area.height}
        case "third3":
            return {x: area.left + (area.width // 3) * 2, y: area.top, w: area.width - (area.width // 3) * 2, h: area.height}

        ; Center
        case "center":
            centerW := area.width * 2 // 3
            centerH := area.height * 2 // 3
            return {x: area.left + (area.width - centerW) // 2, y: area.top + (area.height - centerH) // 2, w: centerW, h: centerH}

        ; Fullscreen
        case "full":
            return {x: area.left, y: area.top, w: area.width, h: area.height}
    }
    return {x: area.left, y: area.top, w: area.width, h: area.height}
}

; Get next/previous monitor number
GetAdjacentMonitor(currentMonitor, direction) {
    monitorCount := MonitorGetCount()
    if (direction = "next") {
        return Mod(currentMonitor, monitorCount) + 1
    } else {
        return Mod(currentMonitor - 2 + monitorCount, monitorCount) + 1
    }
}
