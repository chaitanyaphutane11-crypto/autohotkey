; --- Globals ---
SnippetDir := A_ScriptDir "\snippets"
ShortcutsConfig := A_ScriptDir "\shortcuts.conf"
ShortcutsMap := Map()
SnippetsMenu := Menu() ; submenu for dynamic snippets

; --- Utility Functions ---
TypeInstant(Text) {
    Send("{Text}" Text)
}

LoadSnippetFromPath(Path) {
    if FileExist(Path) {
        Snippet := FileRead(Path)
        A_Clipboard := Snippet   ; copy to clipboard
        TypeInstant(Snippet)
        TrayTip("Snippet Inserted", Path)
    } else {
        TrayTip("Snippet Missing", Path)
    }
}

LoadDynamicShortcuts() {
    global ShortcutsMap, ShortcutsConfig, SnippetsMenu
    ShortcutsMap := Map()
    SnippetsMenu := Menu()

    if !FileExist(ShortcutsConfig) {
        Sample :=
        (
"; Shortcuts config for dynamic loading
; Hotstrings: ::.api::snippets/api.txt
; Hotkeys: ^!1=snippets/api.txt   (Ctrl+Alt+1)
::.api::snippets/api.txt
::.db::snippets/db.txt
^!1=snippets/api.txt
^!2=snippets/db.txt
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

        ; Register hotstring or hotkey
        if SubStr(key,1,2) = "::" {
            Hotstring(key, (*) => LoadSnippetFromPath(val))
        } else {
            Hotkey(key, (*) => LoadSnippetFromPath(val), "On")
        }

        ; Add to Snippets submenu using a lambda closure
        SnippetsMenu.Add(key " → " val, (*) => LoadSnippetFromPath(val))
    }

    ; Rebuild tray menu
    A_TrayMenu.Delete()
    A_TrayMenu.Add("Reload Shortcuts", (*) => LoadDynamicShortcuts())
    A_TrayMenu.Add("Edit Config", (*) => EditConfig())
    A_TrayMenu.Add("Snippets", SnippetsMenu)
    A_TrayMenu.Add("Exit Script", (*) => ExitApp())
}

ClipboardTyping() {
    clipboardText := A_Clipboard
    Send("{Text}" clipboardText)
    TrayTip("Clipboard Inserted", "Text pasted from clipboard")
}

EditConfig() {
    global ShortcutsConfig
    Run("notepad.exe " ShortcutsConfig, , "Max")
}

; --- Hotkeys ---
^!t:: ClipboardTyping()
^!r:: LoadDynamicShortcuts()
^!e:: EditConfig()

; --- Initial load ---
LoadDynamicShortcuts()