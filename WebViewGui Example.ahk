;Environment Controls
;///////////////////////////////////////////////////////////////////////////////////////////
#Requires AutoHotkey v2
#SingleInstance Force
#Include Lib\WebViewToo.ahk
GroupAdd("ScriptGroup", "ahk_pid" DllCall("GetCurrentProcessId"))

; Configuration
CONFIG_LOAD_DELAY := 500  ; milliseconds to wait before loading configs
;///////////////////////////////////////////////////////////////////////////////////////////

;Global variables for window state
windowConfig := Map("x", 100, "y", 100, "width", 800, "height", 600, "maximized", false)

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

; Load window config and show window
LoadAndSendConfigs()
ShowWindowWithConfig()
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
    global MyWindow, windowConfig
    
    ; Get current window position using WinGetPos
    WinGetPos(&x, &y, &w, &h, "ahk_id " MyWindow.Hwnd)
    if (x != windowConfig["x"] || y != windowConfig["y"] || 
        w != windowConfig["width"] || h != windowConfig["height"]) {
        ; Update config with new position/size
        windowConfig["x"] := x
        windowConfig["y"] := y
        windowConfig["width"] := w
        windowConfig["height"] := h
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
    global windowConfig
    
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
    
    ; Create clean JSON content
    content := "{`n"
    content .= "  `"buttonWidth`": " buttonWidth ",`n"
    content .= "  `"buttonHeight`": " buttonHeight ",`n"
    content .= "  `"buttonSpacing`": " buttonSpacing ",`n"
    content .= "  `"x`": " windowConfig["x"] ",`n"
    content .= "  `"y`": " windowConfig["y"] ",`n"
    content .= "  `"width`": " windowConfig["width"] ",`n"
    content .= "  `"height`": " windowConfig["height"] ",`n"
    content .= "  `"maximized`": " (windowConfig["maximized"] ? "true" : "false") "`n"
    content .= "}"
    
    ; Write to file
    file := FileOpen("configs/config.json", "w", "UTF-8")
    file.Write(content)
    file.Close()
}

ShowWindowWithConfig() {
    global MyWindow, windowConfig
    
    ; Show window with saved position and size
    MyWindow.Show("x" windowConfig["x"] " y" windowConfig["y"] " w" windowConfig["width"] " h" windowConfig["height"])
    
    ; Restore maximized state if needed
    if (windowConfig["maximized"])
        MyWindow.Maximize()
}
;///////////////////////////////////////////////////////////////////////////////////////////

;Web Callback Functions
;///////////////////////////////////////////////////////////////////////////////////////////
WebButtonClickEvent(button) {
	MsgBox(button)
}

;///////////////////////////////////////////////////////////////////////////////////////////

;Config Loading Functions
;///////////////////////////////////////////////////////////////////////////////////////////
LoadAndSendConfigs() {
    global windowConfig
    
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