; --- Globals ---
SnippetDir := A_ScriptDir "\snippets"
ShortcutsConfig := A_ScriptDir "\shortcuts.conf"
ShortcutsMap := Map()
SnippetsMenu := Menu()

; --- Utility Functions ---
TypeInstant(Text) {
    Send("{Text}" Text)
}

LoadSnippetFromPath(Path) {
    if FileExist(Path) {
        Snippet := FileRead(Path)
        A_Clipboard := Snippet
        TypeInstant(Snippet)
        TrayTip("Snippet Inserted", Path)
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

SnippetMenuHandler(path, *) {
    LoadSnippetFromPath(path)
}

ClipboardTyping(*) {
    Send("{Text}" A_Clipboard)
    TrayTip("Clipboard Inserted", "Text pasted from clipboard")
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
            Hotstring(key, () => LoadSnippetFromPath(val))
        } else {
            try {
                Hotkey(key, HotkeyHandler, "On")
            } catch {
                TrayTip("Invalid hotkey string", key)
            }
        }

        SnippetsMenu.Add(key " → " val, SnippetMenuHandler.Bind(val))
    }

    ; Tray menu setup with proper function objects
    A_TrayMenu.Delete()
    A_TrayMenu.Add("Reload Shortcuts", ReloadHandler)
    A_TrayMenu.Add("Edit Config", EditConfig)
    A_TrayMenu.Add("Snippets", SnippetsMenu)
    A_TrayMenu.Add("Exit Script", ExitHandler)
}

; --- Hotkeys ---
^!t:: ClipboardTyping()
^!r:: LoadDynamicShortcuts()
^!e:: EditConfig()

; --- Initial load ---
LoadDynamicShortcuts()