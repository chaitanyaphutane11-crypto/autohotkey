#NoTrayIcon

; --- Globals ---
SnippetDir := A_ScriptDir "\snippets"
ShortcutsConfig := A_ScriptDir "\shortcuts.conf"
ShortcutsMap := Map()
SnippetsMenu := Menu()
GlobalPasteMode := false   ; default: copy only

; --- Utility Functions ---
LoadSnippetFromPath(Path) {
    global GlobalPasteMode
    if FileExist(Path) {
        Snippet := FileRead(Path)
        A_Clipboard := Snippet
        if GlobalPasteMode {
            SendText(Snippet)
            TrayTip("Snippet Pasted", Path)
        } else {
            TrayTip("Snippet Copied", Path)
        }
    } else {
        TrayTip("Snippet Missing", Path)
    }
}

HotkeyHandler(*) {
    global ShortcutsMap
    if ShortcutsMap.Has(A_ThisHotkey) {
        LoadSnippetFromPath(ShortcutsMap[A_ThisHotkey])
    }
}

SnippetMenuHandler(path, paste := false, *) {
    if paste {
        SendText(FileRead(path))
        TrayTip("Snippet Pasted", path)
    } else {
        A_Clipboard := FileRead(path)
        TrayTip("Snippet Copied", path)
    }
}

ClipboardTyping(*) {
    global GlobalPasteMode
    if GlobalPasteMode {
        SendText(A_Clipboard)
        TrayTip("Clipboard Pasted", "Text pasted from clipboard")
    } else {
        TrayTip("Clipboard Copied", "Clipboard left unchanged")
    }
}

EditConfig(*) {
    Run("notepad.exe " ShortcutsConfig, , "Max")
}

; --- Menu Handlers ---
ReloadHandler(*) {
    LoadDynamicShortcuts()
}
ExitHandler(*) {
    ExitApp()
}

TogglePasteMode(*) {
    global GlobalPasteMode
    GlobalPasteMode := !GlobalPasteMode
    mode := GlobalPasteMode ? "Paste Mode" : "Copy Mode"
    TrayTip("Mode Toggled", "Now in " mode)
}

; --- Loader ---
LoadDynamicShortcuts() {
    global ShortcutsMap, ShortcutsConfig, SnippetsMenu
    ShortcutsMap := Map()
    SnippetsMenu := Menu()

    if !FileExist(ShortcutsConfig) {
        Sample :=
        (
"; Example config
::.api::snippets/api.txt
::.db::snippets/db.txt
^!1=snippets/api.txt
^!2=snippets/db.txt
^!Numpad1=snippets/api.txt
^!Numpad2=snippets/db.txt
"
        )
        FileAppend(Sample, ShortcutsConfig)
        return
    }

    Config := FileRead(ShortcutsConfig)
    for line in StrSplit(Config, "`n", "`r") {
        line := Trim(line)
        if (line = "" || SubStr(line,1,1) = ";" || SubStr(line,1,1) = "#")
            continue
        pos := InStr(line, "=")
        if pos <= 0
            continue
        key := Trim(SubStr(line, 1, pos - 1))
        val := Trim(SubStr(line, pos + 1))
        if (key = "" || val = "")
            continue

        ShortcutsMap[key] := val

        if SubStr(key,1,2) = "::" {
            Hotstring(key, (*) => LoadSnippetFromPath(val))
        } else {
            try {
                Hotkey(key, HotkeyHandler, "On")
            } catch {
                TrayTip("Invalid hotkey string", key)
            }
        }

        ; Add both copy and paste options to the Snippets menu
        SnippetsMenu.Add(key " → Copy", SnippetMenuHandler.Bind(val, false))
        SnippetsMenu.Add(key " → Paste", SnippetMenuHandler.Bind(val, true))
    }

    ; Tray menu setup
    A_TrayMenu.Delete()
    A_TrayMenu.Add("Reload Shortcuts", ReloadHandler)
    A_TrayMenu.Add("Edit Config", EditConfig)
    A_TrayMenu.Add("Snippets", SnippetsMenu)
    A_TrayMenu.Add("Toggle Mode (Copy/Paste)", TogglePasteMode)
    A_TrayMenu.Add("Exit Script", ExitHandler)
}

; --- Hotkeys ---
^!t:: ClipboardTyping()
^!r:: LoadDynamicShortcuts()
^!e:: EditConfig()
^!p:: TogglePasteMode()   ; global toggle hotkey

; --- Initial load ---
LoadDynamicShortcuts()