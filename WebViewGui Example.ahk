;Environment Controls
;///////////////////////////////////////////////////////////////////////////////////////////
#Requires AutoHotkey v2
#SingleInstance Force
#Include Lib\WebViewToo.ahk
GroupAdd("ScriptGroup", "ahk_pid" DllCall("GetCurrentProcessId"))
;///////////////////////////////////////////////////////////////////////////////////////////

;Create the WebViewGui
;///////////////////////////////////////////////////////////////////////////////////////////
if (A_IsCompiled) {
	WebViewCtrl.CreateFileFromResource((A_PtrSize * 8) "bit\WebView2Loader.dll", WebViewCtrl.TempDir)
    WebViewSettings := {DllPath: WebViewCtrl.TempDir "\" (A_PtrSize * 8) "bit\WebView2Loader.dll"}
} else {
    WebViewSettings := {}
}

MyWindow := WebViewGui("+Resize -Caption",, WebViewSettings)
MyWindow.OnEvent("Close", (*) => ExitApp())
MyWindow.Navigate("Pages/index.html")
MyWindow.Debug()
MyWindow.AddHostObjectToScript("ButtonClick", {func: WebButtonClickEvent})
MyWindow.Show("w800 h600")
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

;Web Callback Functions
;///////////////////////////////////////////////////////////////////////////////////////////
WebButtonClickEvent(button) {
	MsgBox(button)
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
;@Ahk2Exe-AddResource Pages\Bootstrap\fonts\glyphicons-halflings-regular.ttf, Pages\Bootstrap\fonts\glyphicons-halflings-regular.ttf
;@Ahk2Exe-AddResource Pages\Bootstrap\fonts\glyphicons-halflings-regular.woff, Pages\Bootstrap\fonts\glyphicons-halflings-regular.woff
;@Ahk2Exe-AddResource Pages\Bootstrap\fonts\glyphicons-halflings-regular.woff2, Pages\Bootstrap\fonts\glyphicons-halflings-regular.woff2
;///////////////////////////////////////////////////////////////////////////////////////////
