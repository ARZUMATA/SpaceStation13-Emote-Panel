;Environment Controls
;///////////////////////////////////////////////////////////////////////////////////////////
#Requires AutoHotkey v2
#SingleInstance Force
#Include Lib\WebViewToo.ahk
GroupAdd("ScriptGroup", "ahk_pid" DllCall("GetCurrentProcessId"))

; Global variables for the biggest dialog window
biggestDialogHWND := 0
biggestDialogPID := 0

; Find and log all windows with CLASS:#32770
FindGameWindow()

; Global variable for the hotkey
buttonHotkey := "t"
buttonHotkeyEmote := "m"

; "t" = lowercase t key
; "T" = Shift+T
; "^t" = Ctrl+t
; "^T" = Ctrl+Shift+T
; "Enter" - Enter key
; "Space" - Spacebar
; "Tab" - Tab key
; "Esc" - Escape key
; "Backspace" - Backspace key
; "Delete" - Delete key
; "Insert" - Insert key
; "Home" - Home key
; "End" - End key
; "PgUp" - Page Up
; "PgDn" - Page Down
; "Up" - Up arrow
; "Down" - Down arrow
; "Left" - Left arrow
; "Right" - Right arrow
; "buttonHotkey": "Enter"
; "buttonHotkey": "^Enter" - Ctrl+Enter

; Configuration
CONFIG_LOAD_DELAY := 500  ; milliseconds to wait before loading configs
;///////////////////////////////////////////////////////////////////////////////////////////

;Global variables for window state
windowConfig := Map("x", 100, "y", 100, "width", 800, "height", 600, "maximized", false)
isHidden := false  ; Global state variable
sendKeysToGame := true

;FindGameWindow
;///////////////////////////////////////////////////////////////////////////////////////////

FindGameWindow() {
    OutputDebug("Searching for the biggest dialog window (CLASS:#32770)...`r`n")
    
    biggestHwnd := 0
    biggestArea := 0
    biggestPid := 0
    
    ; Enumerate all windows with class #32770
    for hwnd in WinGetList("ahk_class #32770") {
        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
        area := w * h
        
        ; Get the process ID for this window
        pid := WinGetPID("ahk_id " hwnd)
        
        ; Check if this window is bigger than the current biggest
        if (area > biggestArea) {
            biggestArea := area
            biggestHwnd := hwnd
            biggestPid := pid
        }
    }
    
    ; Store the biggest window's HWND and PID as global variables
    global biggestDialogHWND := biggestHwnd
    global biggestDialogPID := biggestPid
    
    ; Log the biggest window if found
    if (biggestHwnd != 0) {
        title := WinGetTitle("ahk_id " biggestHwnd)
        WinGetPos(&x, &y, &w, &h, "ahk_id " biggestHwnd)
        OutputDebug("Biggest Dialog Window: HWND=" biggestHwnd ", PID=" biggestPid ", Title='" title "', Pos=" x "," y " Size=" w "x" h " Area=" biggestArea "`r`n")
    } else {
        OutputDebug("No dialog windows found.`r`n")
    }
}


;Create the WebViewGui
;///////////////////////////////////////////////////////////////////////////////////////////
if (A_IsCompiled) {
	WebViewCtrl.CreateFileFromResource((A_PtrSize * 8) "bit\WebView2Loader.dll", WebViewCtrl.TempDir)
    WebViewSettings := {DllPath: WebViewCtrl.TempDir "\" (A_PtrSize * 8) "bit\WebView2Loader.dll"}
} else {
    WebViewSettings := {}
}

MyWindow := WebViewGui("+Resize -Caption",, WebViewSettings)
MyWindow.OnEvent("Close", WindowClose)
MyWindow.Navigate("Pages/index.html")
; MyWindow.Debug()
MyWindow.AddHostObjectToScript("ButtonClick", {func: WebButtonClickEvent})
MyWindow.AddHostObjectToScript("PanelToggle", {func: WebPanelToggleEvent})


; Load window config and show window
LoadAndSendConfigs()
ShowWindowWithConfig()

SetTimer EnsureWebViewOnTop, 1000
;///////////////////////////////////////////////////////////////////////////////////////////

;Hotkeys
;///////////////////////////////////////////////////////////////////////////////////////////
#HotIf WinActive("ahk_group ScriptGroup")
F1:: {
	MsgBox(MyWindow.Title)
	MyWindow.Title := "New Title!"
    MyWindow.ExecuteScriptAsync("document.querySelector('#ahkTitleBar').textContent = '" MyWindow.Title "'")
	MsgBox(MyWindow.Title)
}

F2:: {
    static Toggle := 0
    Toggle := !Toggle
    if (Toggle) {
	    MyWindow.PostWebMessageAsString("Hello World")
    } else {
        MyWindow.PostWebMessageAsJson('{"key1": "value1"}')
    }
}

F3:: {
	MyWindow.SimplePrintToPdf()
}
#HotIf
;///////////////////////////////////////////////////////////////////////////////////////////

;Window Event Handlers
;///////////////////////////////////////////////////////////////////////////////////////////
WindowClose(*) {
    SaveWindowConfig()
    ExitApp()
}

CheckWindowPosition() {
    global MyWindow, windowConfig, isHidden
    
    ; Get current window position using WinGetPos
    WinGetPos(&x, &y, &w, &h, "ahk_id " MyWindow.Hwnd)
    
    if (isHidden) {
        ; Update hidden position/size
        if (x != windowConfig["hiddenX"] || y != windowConfig["hiddenY"] || 
            w != windowConfig["hiddenWidth"] || h != windowConfig["hiddenHeight"]) {
            windowConfig["hiddenX"] := x
            windowConfig["hiddenY"] := y
            windowConfig["hiddenWidth"] := w
            windowConfig["hiddenHeight"] := h
            ; Save config immediately when window moves
            SaveWindowConfig()
        }
    } else {
        ; Update normal position/size
        if (x != windowConfig["x"] || y != windowConfig["y"] || 
            w != windowConfig["width"] || h != windowConfig["height"]) {
            windowConfig["x"] := x
            windowConfig["y"] := y
            windowConfig["width"] := w
            windowConfig["height"] := h
            ; Save config immediately when window moves
            SaveWindowConfig()
        }
    }
}
;///////////////////////////////////////////////////////////////////////////////////////////

;Window Config Functions
;///////////////////////////////////////////////////////////////////////////////////////////
ValidateWindowPosition() {
    global windowConfig
    
    ; Get primary monitor dimensions
    screenWidth := A_ScreenWidth
    screenHeight := A_ScreenHeight
    
    ; Ensure window is within bounds
    if (windowConfig["x"] < 0)
        windowConfig["x"] := 0
    if (windowConfig["y"] < 0)
        windowConfig["y"] := 0
    if (windowConfig["x"] >= screenWidth)
        windowConfig["x"] := screenWidth - 100
    if (windowConfig["y"] >= screenHeight)
        windowConfig["y"] := screenHeight - 100
    if (windowConfig["width"] <= 100)
        windowConfig["width"] := 800
    if (windowConfig["height"] <= 100)
        windowConfig["height"] := 600
    if (windowConfig["width"] > screenWidth)
        windowConfig["width"] := screenWidth
    if (windowConfig["height"] > screenHeight)
        windowConfig["height"] := screenHeight
}

SaveWindowConfig() {
    global windowConfig, isHidden, buttonHotkey, buttonHotkeyEmote
    
    ; Read existing config content
    existingContent := ""
    if (FileExist("configs/config.json")) {
        file := FileOpen("configs/config.json", "r", "UTF-8")
        existingContent := file.Read()
        file.Close()
    }
    
    ; Parse existing content to extract non-window properties
    buttonWidth := 190
    buttonHeight := 35
    buttonSpacing := 5

    ; Extract existing button properties if they exist
    if (RegExMatch(existingContent, "`"buttonWidth`":\s*(\d+)", &bwMatch))
        buttonWidth := Integer(bwMatch[1])
    if (RegExMatch(existingContent, "`"buttonHeight`":\s*(\d+)", &bhMatch))
        buttonHeight := Integer(bhMatch[1])
    if (RegExMatch(existingContent, "`"buttonSpacing`":\s*(\d+)", &bsMatch))
        buttonSpacing := Integer(bsMatch[1])
    ; Extract existing buttonHotkey if it exists
    if (RegExMatch(existingContent, "`"buttonHotkey`":\s*`"([^`"]*)`"", &hkMatch))
        buttonHotkey := hkMatch[1]
    if (RegExMatch(existingContent, "`"buttonHotkeyEmote`":\s*`"([^`"]*)`"", &hkMatch))
        buttonHotkeyEmote := hkMatch[1]
    
    ; Create clean JSON content
    content := "{`n"
    content .= "  `"buttonWidth`": " buttonWidth ",`n"
    content .= "  `"buttonHeight`": " buttonHeight ",`n"
    content .= "  `"buttonSpacing`": " buttonSpacing ",`n"
    content .= "  `"hiddenWidth`": " windowConfig["hiddenWidth"] ",`n"
    content .= "  `"hiddenHeight`": " windowConfig["hiddenHeight"] ",`n"
    content .= "  `"hiddenX`": " windowConfig["hiddenX"] ",`n"
    content .= "  `"hiddenY`": " windowConfig["hiddenY"] ",`n"
    content .= "  `"x`": " windowConfig["x"] ",`n"
    content .= "  `"y`": " windowConfig["y"] ",`n"
    content .= "  `"width`": " windowConfig["width"] ",`n"
    content .= "  `"height`": " windowConfig["height"] ",`n"
    content .= "  `"maximized`": " (windowConfig["maximized"] ? "true" : "false") ",`n"
    content .= "  `"isHidden`": " (isHidden ? "true" : "false") ",`n"
    content .= "  `"buttonHotkey`": `"" buttonHotkey "`"`n"
    content .= "  `"buttonHotkeyEmote`": `"" buttonHotkeyEmote "`"`n"
    content .= "}"
    
    ; Write to file
    file := FileOpen("configs/config.json", "w", "UTF-8")
    file.Write(content)
    file.Close()
}

ShowWindowWithConfig() {
    global MyWindow, windowConfig, isHidden
    
    if (isHidden) {
        ; Show window in hidden state
        MyWindow.Style := "-Caption"
        hiddenWidth := windowConfig.Has("hiddenWidth") ? windowConfig["hiddenWidth"] : 150
        hiddenHeight := windowConfig.Has("hiddenHeight") ? windowConfig["hiddenHeight"] : 50
        hiddenX := windowConfig.Has("hiddenX") ? windowConfig["hiddenX"] : 100
        hiddenY := windowConfig.Has("hiddenY") ? windowConfig["hiddenY"] : 100
        MyWindow.Show("x" hiddenX " y" hiddenY " w" hiddenWidth " h" hiddenHeight)
        
        ; Send hide command to web to update UI
        SetTimer SendHideCommand, -100
    } else {
        ; Show window in normal state
        MyWindow.Style := "+Resize -Caption"
        MyWindow.Show("x" windowConfig["x"] " y" windowConfig["y"] " w" windowConfig["width"] " h" windowConfig["height"])
        
        ; Restore maximized state if needed
        if (windowConfig["maximized"])
            MyWindow.Maximize()
    }
    
    ; Load configs after window is shown
    LoadAndSendConfigs()
}

SendHideCommand() {
    global MyWindow
    ; Send message to web to update UI to hidden state
    MyWindow.ExecuteScriptAsync("if (typeof togglePanel === 'function') togglePanel();")
}
;///////////////////////////////////////////////////////////////////////////////////////////

;Web Callback Functions
;///////////////////////////////////////////////////////////////////////////////////////////
WebButtonClickEvent(button) {
    global biggestDialogHWND, biggestDialogPID, buttonHotkey, buttonHotkeyEmote, sendKeysToGame, MyWindow
    
    ; Parse the JSON button data to extract command and emote flag
    command := ""
    isEmote := false
    try {
        ; Extract command using regex
        if (RegExMatch(button, "`"command`":`"([^`"]*)`"", &cmdMatch)) {
            command := cmdMatch[1]
        }
        ; Extract emote flag
        if (RegExMatch(button, "`"emote`":(true|false)", &emoteMatch)) {
            isEmote := (emoteMatch[1] = "true")
        }
    } catch {
        command := ""
        isEmote := false
    }
    
    ; Check if we have a valid HWND
    if (biggestDialogHWND != 0) {
        ; Focus the window using its HWND
        WinActivate("ahk_id " biggestDialogHWND)
        
        ; Wait for window to become active (with timeout)
        timeout := 1000  ; 1 second timeout
        start := A_TickCount
        while (WinActive("ahk_id " biggestDialogHWND) = 0) {
            Sleep(25)
            if (A_TickCount - start > timeout) {
                OutputDebug("Timeout waiting for window to become active`r`n")
                break
            }
        }
        
        ; Check if we should send keys to the game
        if (sendKeysToGame) {
            ; Copy command to clipboard and paste it
            if (command != "") {
                ; Save current clipboard
                oldClipboard := A_Clipboard
                A_Clipboard := command
                
                ; Wait for clipboard to be set
                ClipWait(1)
                
                ; Determine which hotkey to send based on emote flag
                hotkeyToSend := isEmote ? buttonHotkeyEmote : buttonHotkey
                
                ; Send the configured hotkey as raw key code
                SendRawKey(hotkeyToSend)

                Sleep(100)

                ; Paste the command using Ctrl+V
                SendInput("^v")  ; Ctrl+V to paste
                OutputDebug("Sent command: " command "`r`n")
                OutputDebug("Hotkey used: " hotkeyToSend " (Emote: " (isEmote ? "true" : "false") ")`r`n")
                
                ; Restore clipboard after a short delay
                SetTimer () => A_Clipboard := oldClipboard, -500
            }
        } else {
            OutputDebug("SendInput skipped - sendKeysToGame is false`r`n")
        }
        
        ; Ensure our WebView window stays on top
        WinSetAlwaysOnTop(1, "ahk_id " MyWindow.Hwnd)
    } else {
        MsgBox("No target window found to send hotkey to.")
    }
}

WebPanelToggleEvent(action) {
    global isHidden, windowConfig, MyWindow
    
    ; Log the received action
    OutputDebug("PanelToggleEvent received: " action "`r`n")
    SetTimer () => ToolTip(), -2000  ; Clear tooltip after 2 seconds
    
    if (action = "hide") {
        isHidden := true
        ; Save current window size before hiding
        WinGetPos(&x, &y, &w, &h, "ahk_id " MyWindow.Hwnd)
        windowConfig["prevX"] := x
        windowConfig["prevY"] := y
        
        ; Make window borderless and small when hidden
        MyWindow.Style := "-Caption"
        ; Use configurable hidden size
        hiddenWidth := windowConfig.Has("hiddenWidth") ? windowConfig["hiddenWidth"] : 150
        hiddenHeight := windowConfig.Has("hiddenHeight") ? windowConfig["hiddenHeight"] : 50
        ; Use saved hidden position if available
        hiddenX := windowConfig.Has("hiddenX") ? windowConfig["hiddenX"] : 100
        hiddenY := windowConfig.Has("hiddenY") ? windowConfig["hiddenY"] : 100
        MyWindow.Show("x" hiddenX " y" hiddenY " w" hiddenWidth " h" hiddenHeight)
        OutputDebug("Window hidden: " hiddenX "," hiddenY " " hiddenWidth "x" hiddenHeight "`r`n")
    } else if (action = "show") {
        isHidden := false
        ; Restore normal window with caption
        MyWindow.Style := "+Resize -Caption"
        ; Restore previous size from config
        if (windowConfig.Has("width") && windowConfig.Has("height")) {
            MyWindow.Show("x" windowConfig["x"]  " y" windowConfig["y"]  " w" windowConfig["width"] " h" windowConfig["height"])

            OutputDebug("Window shown: " windowConfig["width"] "x" windowConfig["height"] "`r`n")
        } else {
            ; Fallback to default size
            MyWindow.Show("w800 h600")
            OutputDebug("Window shown: 800x600 (fallback) `r`n")
        }
    }
    
    ; Return a value to prevent promise rejection
    return "OK"
}

WebWindowMoveEvent(x, y) {
    global isHidden, windowConfig, MyWindow
    
    ; Move the window to the new position
    MyWindow.Show("x" Integer(x) " y" Integer(y))
    OutputDebug("Window moved to: " x "," y "`r`n")
    
    ; Save position based on current state
    WinGetPos(&winX, &winY, &winW, &winH, "ahk_id " MyWindow.Hwnd)
    if (isHidden) {  ; Check if currently hidden
        windowConfig["hiddenX"] := winX
        windowConfig["hiddenY"] := winY
    } else {
        windowConfig["x"] := winX
        windowConfig["y"] := winY
    }
    SaveWindowConfig()  ; Save immediately
    return "OK"
}

;///////////////////////////////////////////////////////////////////////////////////////////

;Config Loading Functions
;///////////////////////////////////////////////////////////////////////////////////////////
LoadAndSendConfigs() {
    global windowConfig, isHidden, buttonHotkey
    
    ; Load main config
    configFile := FileOpen("configs/config.json", "r", "UTF-8")
    configContent := configFile.Read()
    configFile.Close()
    
    ; Extract window position from main config
    configClean := StrReplace(configContent, " ", "")
    configClean := StrReplace(configClean, "`n", "")
    configClean := StrReplace(configClean, "`r", "")
    
    ; Extract window position values
    if (RegExMatch(configClean, "`"x`":(-?\d+)", &xMatch))
        windowConfig["x"] := Integer(xMatch[1])
    if (RegExMatch(configClean, "`"y`":(-?\d+)", &yMatch))
        windowConfig["y"] := Integer(yMatch[1])
    if (RegExMatch(configClean, "`"width`":(\d+)", &wMatch))
        windowConfig["width"] := Integer(wMatch[1])
    if (RegExMatch(configClean, "`"height`":(\d+)", &hMatch))
        windowConfig["height"] := Integer(hMatch[1])
    if (RegExMatch(configClean, "`"maximized`":(true|false)", &maxMatch))
        windowConfig["maximized"] := (maxMatch[1] = "true")
    
    ; Extract hidden size and position values
    if (RegExMatch(configClean, "`"hiddenWidth`":(\d+)", &hwMatch))
        windowConfig["hiddenWidth"] := Integer(hwMatch[1])
    if (RegExMatch(configClean, "`"hiddenHeight`":(\d+)", &hhMatch))
        windowConfig["hiddenHeight"] := Integer(hhMatch[1])
    if (RegExMatch(configClean, "`"hiddenX`":(-?\d+)", &hxMatch))
        windowConfig["hiddenX"] := Integer(hxMatch[1])
    if (RegExMatch(configClean, "`"hiddenY`":(-?\d+)", &hyMatch))
        windowConfig["hiddenY"] := Integer(hyMatch[1])
    
    ; Extract isHidden state
    if (RegExMatch(configClean, "`"isHidden`":(true|false)", &hiddenMatch))
        isHidden := (hiddenMatch[1] = "true")
    
    ; Extract button hotkey
    if (RegExMatch(configContent, "`"buttonHotkey`":\s*`"([^`"]*)`"", &hkMatch))
        buttonHotkey := hkMatch[1]
    
    ; Validate window position
    ValidateWindowPosition()
    
    ; Load character configs
    charConfigs := []
    loop files, "configs/*.json" {
        if (A_LoopFileName != "config.json") {
            file := FileOpen(A_LoopFilePath, "r", "UTF-8")
            charContent := file.Read()
            file.Close()
            charConfigs.Push(charContent)
        }
    }
    
    ; Send configs to web with a delay to ensure page is loaded
    SetTimer SendConfigData, -CONFIG_LOAD_DELAY
}

SendConfigData() {
    global MyWindow
    
    ; Load main config
    configFile := FileOpen("configs/config.json", "r", "UTF-8")
    configContent := configFile.Read()
    configFile.Close()
    
    MyWindow.PostWebMessageAsString("{`"type`":`"config`",`"data`":" configContent "}")
    
    ; Load and send character configs
    charConfigs := []
    loop files, "configs/*.json" {
        if (A_LoopFileName != "config.json") {
            file := FileOpen(A_LoopFilePath, "r", "UTF-8")
            content := file.Read()
            file.Close()
            charConfigs.Push(content)
        }
    }
    
    ; Build charConfigs array string
    charConfigsStr := ""
    for i, config in charConfigs {
        if (i > 1)
            charConfigsStr .= ","
        charConfigsStr .= config
    }
    MyWindow.PostWebMessageAsString("{`"type`":`"charConfigs`",`"data`":[" charConfigsStr "]}")
    
    ; Start timer to periodically check window position
    SetTimer CheckWindowPosition, 1000
}

EnsureWebViewOnTop() {
    global MyWindow
    WinSetAlwaysOnTop(1, "ahk_id " MyWindow.Hwnd)
}
;///////////////////////////////////////////////////////////////////////////////////////////

;Helpers
;///////////////////////////////////////////////////////////////////////////////////////////
SendRawKey(key) {
    ; Handle special keys
    if (key = "Enter") {
        SendInput("{Blind}{vk0D}")
    } else if (key = "Space") {
        SendInput("{Blind}{vk20}")
    } else if (key = "Tab") {
        SendInput("{Blind}{vk09}")
    } else if (key = "Esc") {
        SendInput("{Blind}{vk1B}")
    } else if (key = "Backspace") {
        SendInput("{Blind}{vk08}")
    } else if (StrLen(key) = 1) {
        ; Handle single character keys using AHK's built-in GetKeyVK
        try {
            vk := GetKeyVK(key)
            if (vk) {
                SendInput("{Blind}{vk" Format("{:02X}", vk) "}")
            } else {
                ; Fallback
                SendInput("{Blind}" key)
            }
        } catch {
            ; Fallback if GetKeyVK fails
            SendInput("{Blind}" key)
        }
    } else {
        ; For key combinations like ^t, !t, etc.
        SendInput("{Blind}" key)
    }
}
;///////////////////////////////////////////////////////////////////////////////////////////

;Resources for Compiled Scripts
;///////////////////////////////////////////////////////////////////////////////////////////
;@Ahk2Exe-AddResource Lib\32bit\WebView2Loader.dll, 32bit\WebView2Loader.dll
;@Ahk2Exe-AddResource Lib\64bit\WebView2Loader.dll, 64bit\WebView2Loader.dll
;@Ahk2Exe-AddResource Pages\index.html, Pages\index.html
;@Ahk2Exe-AddResource Pages\Bootstrap\bootstrap.bundle.min.js, Pages\Bootstrap\bootstrap.bundle.min.js
;@Ahk2Exe-AddResource Pages\Bootstrap\bootstrap.min.css, Pages\Bootstrap\bootstrap.min.css
;@Ahk2Exe-AddResource Pages\Bootstrap\color-modes.js, Pages\Bootstrap\color-modes.js
;@Ahk2Exe-AddResource Pages\Bootstrap\sidebars.css, Pages\Bootstrap\sidebars.css
;@Ahk2Exe-AddResource Pages\Bootstrap\sidebars.js, Pages\Bootstrap\sidebars.js
;@Ahk2Exe-AddResource Pages\Bootstrap\custom-colors.css, Pages\Bootstrap\custom-colors.css
;@Ahk2Exe-AddResource Pages\Bootstrap\fonts\glyphicons-halflings-regular.ttf, Pages\Bootstrap\fonts\glyphicons-halflings-regular.ttf
;@Ahk2Exe-AddResource Pages\Bootstrap\fonts\glyphicons-halflings-regular.woff, Pages\Bootstrap\fonts\glyphicons-halflings-regular.woff
;@Ahk2Exe-AddResource Pages\Bootstrap\fonts\glyphicons-halflings-regular.woff2, Pages\Bootstrap\fonts\glyphicons-halflings-regular.woff2
;////////////////////////////////////////////////////////////////////