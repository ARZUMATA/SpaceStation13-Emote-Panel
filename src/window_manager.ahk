#Requires AutoHotkey v2.0

; Load JSON library (include in same directory)
;#Include Json.ahk

; Create GUI
MyGui := Gui(, "Window Manager")
MyGui.Opt("+AlwaysOnTop +Resize")

; Load button configuration
config := LoadConfig()
CreateButtons(config)

; Show GUI
MyGui.Show("w400 h300")

; Handle GUI close
MyGui.OnEvent("Close", GuiClose)

; Load configuration from JSON file
LoadConfig() {
    try {
        file := FileOpen("config.json", "r")
        jsonStr := file.Read()
        file.Close()
        return JSON.Load(jsonStr)
    } catch as err {
        ; Default configuration if file not found
        return {
            buttons: [
                {text: "Notepad", row: 0, col: 0, target: "ahk_exe notepad.exe", keys: "Hello World!{Enter}"},
                {text: "Chrome", row: 0, col: 1, target: "ahk_exe chrome.exe", keys: "^t"},
                {text: "Explorer", row: 1, col: 0, target: "ahk_class CabinetWClass", keys: "^n"}
            ]
        }
    }
}

; Create buttons from configuration
CreateButtons(config) {
    global MyGui
    for btn in config.buttons {
        ; Create button with dynamic label
        guiBtn := MyGui.Add("Button", "w100 h30", btn.text)
        
        ; Position button in grid
        guiBtn.Move(btn.col * 110 + 10, btn.row * 40 + 10)
        
        ; Store button data in control's object
        guiBtn.btnData := btn
        
        ; Set click handler
        guiBtn.OnEvent("Click", ButtonClick)
    }
}

; Handle button clicks
ButtonClick(guiBtn, *) {
    btn := guiBtn.btnData
    try {
        ; Focus target window
        WinActivate(btn.target)
        WinWaitActive(btn.target, , 2)
        
        ; Send keys if specified
        if (btn.HasKey("keys") && btn.keys != "") {
            Send(btn.keys)
        }
    } catch as err {
        MsgBox("Error activating window: " . btn.target, "Error", "Iconx")
    }
}

; Clean up on exit
GuiClose(*) {
    ExitApp
}

; JSON library (simplified for this example)
class JSON {
    static Load(str) {
        ; In a real implementation, you'd use a proper JSON parser
        ; This is a simplified placeholder for demonstration
        return {
            buttons: [
                {text: "Notepad", row: 0, col: 0, target: "ahk_exe notepad.exe", keys: "Hello World!{Enter}"},
                {text: "Chrome", row: 0, col: 1, target: "ahk_exe chrome.exe", keys: "^t"},
                {text: "Explorer", row: 1, col: 0, target: "ahk_class CabinetWClass", keys: "^n"}
            ]
        }
    }
}