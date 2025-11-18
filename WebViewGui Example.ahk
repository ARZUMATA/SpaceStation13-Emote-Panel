; Environment Controls
;///////////////////////////////////////////////////////////////////////////////////////////
#Requires AutoHotkey v2
#SingleInstance Force
#Include Lib\WebViewToo.ahk
#Include  Lib\_JXON.ahk
GroupAdd("ScriptGroup", "ahk_pid" DllCall("GetCurrentProcessId"))

; Global configuration dictionary
global globalConfiguration := Map(
    "buttonHeight", 35,
    "buttonWidth", 190,
    "buttonSpacing", 5,
    "buttonHotkey", "T",
    "buttonHotkeyEmote", "M",
    "sendKeysToGameUseEnter", false,
    "isHidden", false,
    "window", Map(
        "show", Map(
            "x", 100, 
            "y", 100, 
            "width", 800, 
            "height", 600, 
        ),
        "hidden", Map(
            "x", 100,
            "y", 100,
            "width", 150,
            "height", 50
        )
    )
)


; Global variables for the biggest dialog window
global biggestDialogHWND := 0
global biggestDialogPID := 0

; Global variables for configuration
global sendKeysToGame := true
global sendKeysToGameUseEnter := false
global CONFIG_LOAD_DELAY := 500  ; milliseconds to wait before loading configs
global configFile := "configs/config.json"

global buttonHotkeyEmote := unset
global buttonHotkey := unset
global isHidden := unset

LoadConfig() 

; Find and log all windows with CLASS:#32770
FindGameWindow()

;///////////////////////////////////////////////////////////////////////////////////////////

; Load Configuration
;///////////////////////////////////////////////////////////////////////////////////////////

LoadConfig() {
    global globalConfiguration, configFile, buttonHotkey, buttonHotkeyEmote, isHidden, sendKeysToGameUseEnter
    
    ; If config file exists, load it and update default values
    if (FileExist(configFile)) {
        try {
            fileContent := FileRead(configFile)
            loadedConfig := Jxon_Load(&fileContent)
            
            ; Update existing config values with loaded values
            for key, value in loadedConfig {
                if (globalConfiguration.Has(key)) {
                    if (key = "window" && value is Map) {
                        ; Handle nested window config
                        for stateKey, stateValue in value {
                            if (globalConfiguration["window"].Has(stateKey)) {
                                for posKey, posValue in stateValue {
                                    if (globalConfiguration["window"][stateKey].Has(posKey)) {
                                        globalConfiguration["window"][stateKey][posKey] := posValue
                                    }
                                }
                            }
                        }
                    } else {
                        globalConfiguration[key] := value
                    }
                }
            }
        } catch as err {
            OutputDebug("Error loading config: " err.Message "`r`n")
        }
    }

    buttonHotkey := globalConfiguration["buttonHotkey"]
    buttonHotkeyEmote := globalConfiguration["buttonHotkeyEmote"]
    isHidden := globalConfiguration["isHidden"]
    sendKeysToGameUseEnter := globalConfiguration["sendKeysToGameUseEnter"]
}

SaveConfig() {
    global globalConfiguration, isHidden, buttonHotkey, buttonHotkeyEmote

    ; Update the global configuration with current values
    globalConfiguration["isHidden"] := isHidden
    globalConfiguration["buttonHotkey"] := buttonHotkey
    globalConfiguration["buttonHotkeyEmote"] := buttonHotkeyEmote

    ; Get current window positions
    WinGetPos(&x, &y, &w, &h, "ahk_id " MyWindow.Hwnd)

    if (isHidden) {
        globalConfiguration["window"]["hidden"]["x"] := x
        globalConfiguration["window"]["hidden"]["y"] := y
        globalConfiguration["window"]["hidden"]["width"] := w
        globalConfiguration["window"]["hidden"]["height"] := h
    } else {
        globalConfiguration["window"]["show"]["x"] := x
        globalConfiguration["window"]["show"]["y"] := y
        globalConfiguration["window"]["show"]["width"] := w
        globalConfiguration["window"]["show"]["height"] := h
    }

    ; Create JSON content using Jxon
    try {
        content := Jxon_Dump(globalConfiguration, 2)  ; 2 spaces for indentation
        
        ; Write to file
        file := FileOpen("configs/config.json", "w", "UTF-8")
        file.Write(content)
        file.Close()
    } catch as err {
        OutputDebug("Error saving config: " err.Message "`r`n")
    }
}

;///////////////////////////////////////////////////////////////////////////////////////////

; Find Game Window
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
;///////////////////////////////////////////////////////////////////////////////////////////

; Create the WebViewGui
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
SendConfigs()
ShowWindowWithConfig()

SetTimer EnsureWebViewOnTop, 1000
;///////////////////////////////////////////////////////////////////////////////////////////

; Hotkeys
;///////////////////////////////////////////////////////////////////////////////////////////
#HotIf WinActive("ahk_group ScriptGroup")

#HotIf
;///////////////////////////////////////////////////////////////////////////////////////////

; Window Event Handlers
;///////////////////////////////////////////////////////////////////////////////////////////
WindowClose(*) {
    SaveConfig()
    ExitApp()
}

CheckWindowPosition() {
    global MyWindow, globalConfiguration, isHidden
    
    ; Get current window position using WinGetPos
    WinGetPos(&x, &y, &w, &h, "ahk_id " MyWindow.Hwnd)
    
    if (isHidden) {
        ; Update hidden position/size
        if (x != globalConfiguration["window"]["hidden"]["x"] || y != globalConfiguration["window"]["hidden"]["y"] || 
            w != globalConfiguration["window"]["hidden"]["width"] || h != globalConfiguration["window"]["hidden"]["height"]) {
            globalConfiguration["window"]["hidden"]["x"] := x
            globalConfiguration["window"]["hidden"]["y"] := y
            globalConfiguration["window"]["hidden"]["width"] := w
            globalConfiguration["window"]["hidden"]["height"] := h
            ; Save config immediately when window moves
            SaveConfig()
        }
    } else {
        ; Update normal position/size
        if (x != globalConfiguration["window"]["show"]["x"] || y != globalConfiguration["window"]["show"]["y"] || 
            w != globalConfiguration["window"]["show"]["width"] || h != globalConfiguration["window"]["show"]["height"]) {
            globalConfiguration["window"]["show"]["x"] := x
            globalConfiguration["window"]["show"]["y"] := y
            globalConfiguration["window"]["show"]["width"] := w
            globalConfiguration["window"]["show"]["height"] := h
            ; Save config immediately when window moves
            SaveConfig()
        }
    }
}
;///////////////////////////////////////////////////////////////////////////////////////////

; Window Config Functions
;///////////////////////////////////////////////////////////////////////////////////////////
ValidateWindowPosition() {
    global globalConfiguration
    
    ; Get primary monitor dimensions
    screenWidth := A_ScreenWidth
    screenHeight := A_ScreenHeight
    
    ; Ensure window is within bounds
    ; Validate show state window position
    showConfig := globalConfiguration["window"]["show"]
    showConfig["x"] := Max(0, Min(showConfig["x"], screenWidth - 100))
    showConfig["y"] := Max(0, Min(showConfig["y"], screenHeight - 100))
    showConfig["width"] := Max(100, Min(showConfig["width"], screenWidth))
    showConfig["height"] := Max(100, Min(showConfig["height"], screenHeight))
    
    ; Validate hidden state window position
    hiddenConfig := globalConfiguration["window"]["hidden"]
    hiddenConfig["x"] := Max(0, Min(hiddenConfig["x"], screenWidth - 50))
    hiddenConfig["y"] := Max(0, Min(hiddenConfig["y"], screenHeight - 50))
    hiddenConfig["width"] := Max(50, Min(hiddenConfig["width"], screenWidth))
    hiddenConfig["height"] := Max(30, Min(hiddenConfig["height"], screenHeight))
}

ShowWindowWithConfig() {
    global MyWindow, globalConfiguration, isHidden
    
    if (isHidden) {
        ; Show window in hidden state
        MyWindow.Style := "-Caption"
        hiddenConfig := globalConfiguration["window"]["hidden"]
        MyWindow.Move(hiddenConfig["x"], hiddenConfig["y"], hiddenConfig["width"], hiddenConfig["height"])
        
        ; Send hide command to web to update UI
        SetTimer SendHideCommand, -100
    } else {
        ; Show window in normal state
        MyWindow.Style := "+Resize -Caption"
        showConfig := globalConfiguration["window"]["show"]
        MyWindow.Move(showConfig["x"], showConfig["y"], showConfig["width"], showConfig["height"])
    }
    
    ; Load configs after window is shown
    SendConfigs()
}

SendHideCommand() {
    global MyWindow
    ; Send message to web to update UI to hidden state
    MyWindow.ExecuteScriptAsync("if (typeof togglePanel === 'function') togglePanel();")
}
;///////////////////////////////////////////////////////////////////////////////////////////

; Web Callback Functions
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
    if (biggestDialogHWND = 0) {
        MsgBox("No target window found to send hotkey to.")
        return
    }
    
    ; Focus the window using its HWND
    WinActivate("ahk_id " biggestDialogHWND)
    
    ; Wait for window to become active (with timeout)
    if (!WinWaitActive("ahk_id " biggestDialogHWND, , 1)) {
        OutputDebug("Timeout waiting for window to become active`r`n")
    }
    
    ; Check if we should send keys to the game
    if (!sendKeysToGame) {
        OutputDebug("SendInput skipped - sendKeysToGame is false`r`n")
        return
    }
    
    ; Copy command to clipboard and paste it
    if (command = "") {
        return
    }
    
    ; Save current clipboard
    oldClipboard := A_Clipboard
    A_Clipboard := command
    
    ; Wait for clipboard to be set
    if (!ClipWait(1)) {
        OutputDebug("Timeout waiting for clipboard`r`n")
    }
    
    ; Determine which hotkey to send based on emote flag
    hotkeyToSend := isEmote ? buttonHotkeyEmote : buttonHotkey
    
    ; Send the configured hotkey as raw key code
    SendRawKey(hotkeyToSend)
    Sleep(100) ; TODO Await dialog window
    
    ; Paste the command using Ctrl+V
    SendInput("^v")  ; Ctrl+V to paste
    OutputDebug("Sent command: " command "`r`n")
    OutputDebug("Hotkey used: " hotkeyToSend " (Emote: " (isEmote ? "true" : "false") ")`r`n")
    
    Sleep(50)
    if (sendKeysToGameUseEnter) {
        SendInput("{Enter}")
    }
    
    ; Restore clipboard after a short delay
    ; SetTimer () => A_Clipboard := oldClipboard, -500
    A_Clipboard := oldClipboard
    
    ; Ensure our WebView window stays on top
    WinSetAlwaysOnTop(1, "ahk_id " MyWindow.Hwnd)
}

WebPanelToggleEvent(action) {
    global isHidden, globalConfiguration, MyWindow
    
    ; Log the received action
    OutputDebug("PanelToggleEvent received: " action "`r`n")
    SetTimer () => ToolTip(), -2000  ; Clear tooltip after 2 seconds
    
    if (action = "hide") {
        isHidden := true
        ; Make window borderless and small when hidden
        MyWindow.Style := "-Caption"
        hiddenConfig := globalConfiguration["window"]["hidden"]
        ; Use explicit positioning to prevent growth
        MyWindow.Move(hiddenConfig["x"], hiddenConfig["y"], hiddenConfig["width"], hiddenConfig["height"])
        OutputDebug("Window hidden: " hiddenConfig["x"] "," hiddenConfig["y"] 
                   " " hiddenConfig["width"] "x" hiddenConfig["height"] "`r`n")
    } else if (action = "show") {
        isHidden := false
        ; Restore normal window with caption
        MyWindow.Style := "+Resize -Caption"
        ; Restore previous size from config
        showConfig := globalConfiguration["window"]["show"]
        ; Use explicit positioning to prevent growth
        MyWindow.Move(showConfig["x"], showConfig["y"], showConfig["width"], showConfig["height"])
        OutputDebug("Window shown: " showConfig["x"] "," showConfig["y"] 
                     " " showConfig["width"] "x" showConfig["height"] "`r`n")
    }
    
    ; Return a value to prevent promise rejection
    return "OK"
}

WebWindowMoveEvent(x, y) {
    global isHidden, globalConfiguration, MyWindow
    
    ; Move the window to the new position
    MyWindow.Move(Integer(x), Integer(y))
    OutputDebug("Window moved to: " x "," y "`r`n")
    
    ; Save position based on current state
    WinGetPos(&winX, &winY, &winW, &winH, "ahk_id " MyWindow.Hwnd)
    if (isHidden) {
        globalConfiguration["window"]["hidden"]["x"] := winX
        globalConfiguration["window"]["hidden"]["y"] := winY
    } else {
        globalConfiguration["window"]["show"]["x"] := winX
        globalConfiguration["window"]["show"]["y"] := winY
    }
    SaveConfig()  ; Save immediately
    return "OK"
}

;///////////////////////////////////////////////////////////////////////////////////////////

; Config Loading Functions
;///////////////////////////////////////////////////////////////////////////////////////////
SendConfigs() {
    global globalConfiguration, isHidden, buttonHotkey
    
    ; Validate window position
    ValidateWindowPosition()
    
    ; Send configs to web with a delay to ensure page is loaded
    SetTimer SendConfigData, -CONFIG_LOAD_DELAY
}

SendConfigData() {
    global MyWindow, CONFIG_LOAD_DELAY
    
    ; Load main config
    if (!FileExist("configs/config.json")) {
        return
    }
    
    try {
        configFile := FileOpen("configs/config.json", "r", "UTF-8")
        configContent := configFile.Read()
        configFile.Close()
        
        MyWindow.PostWebMessageAsString("{`"type`":`"config`",`"data`":" configContent "}")
    }
    
    ; Load and send character configs
    charConfigs := []
    loop files, "configs/*.json" {
        if (A_LoopFileName != "config.json") {
            try {
                file := FileOpen(A_LoopFilePath, "r", "UTF-8")
                content := file.Read()
                file.Close()
                charConfigs.Push(content)
            }
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

; Helpers
;///////////////////////////////////////////////////////////////////////////////////////////
SendRawKey(key) {
    ; Handle special keys
    static specialKeys := Map(
        "Enter", "{Blind}{vk0D}",
        "Space", "{Blind}{vk20}",
        "Tab", "{Blind}{vk09}",
        "Esc", "{Blind}{vk1B}",
        "Backspace", "{Blind}{vk08}"
    )
    
    if (specialKeys.Has(key)) {
        SendInput(specialKeys[key])
        return
    }
    
    ; Handle single character keys
    if (StrLen(key) = 1) {
        try {
            vk := GetKeyVK(key)
            if (vk) {
                SendInput("{Blind}{vk" Format("{:02X}", vk) "}")
            } else {
                SendInput("{Blind}" key)
            }
        } catch {
            SendInput("{Blind}" key)
        }
        return
    }
    
    ; For key combinations like ^t, !t, etc.
    SendInput("{Blind}" key)
}
;///////////////////////////////////////////////////////////////////////////////////////////

; Resources for Compiled Scripts
;///////////////////////////////////////////////////////////////////////////////////////////
;@Ahk2Exe-AddResource Lib\32bit\WebView2Loader.dll, 32bit\WebView2Loader.dll
;@Ahk2Exe-AddResource Lib\64bit\WebView2Loader.dll, 64bit\WebView2Loader.dll
;@Ahk2Exe-AddResource Pages\index.html, Pages\index.html
;@Ahk2Exe-AddResource Pages\Bootstrap\bootstrap.bundle.min.js, Pages\Bootstrap\bootstrap.bundle.min.js
;@Ahk2Exe-AddResource Pages\Bootstrap\bootstrap.min.css, Pages\Bootstrap\bootstrap.min.css
;@Ahk2Exe-AddResource Pages\Bootstrap\color-modes.js, Pages\Bootstrap\color-modes.js
;@Ahk2Exe-AddResource Pages\Bootstrap\sidebars.css, Pages\Bootstrap\sidebars.css
;@Ahk2Exe-AddResource Pages\Bootstrap\sidebars.js, Pages\Bootstrap\sidebars.js
;@Ahk2Exe-AddResource Pages\custom-colors.css, Pages\custom-colors.css
;@Ahk2Exe-AddResource Pages\Bootstrap\fonts\glyphicons-halflings-regular.ttf, Pages\Bootstrap\fonts\glyphicons-halflings-regular.ttf
;@Ahk2Exe-AddResource Pages\Bootstrap\fonts\glyphicons-halflings-regular.woff, Pages\Bootstrap\fonts\glyphicons-halflings-regular.woff
;@Ahk2Exe-AddResource Pages\Bootstrap\fonts\glyphicons-halflings-regular.woff2, Pages\Bootstrap\fonts\glyphicons-halflings-regular.woff2
;///////////////////////////////////////////////////////////////////////////////////////////