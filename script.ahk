; --- Globals ---
ShortcutsConfig := A_ScriptDir "\shortcuts.conf"
ShortcutsMap    := Map()
SnippetsMenu    := Menu()

; --- Utility Functions ---
LoadSnippetFromPath(Path) {
    if FileExist(Path) {
        Snippet := FileRead(Path)
        A_Clipboard := Snippet
        SendText Snippet
        TrayTip("Snippet Inserted", Path)
    } else {
        TrayTip("Snippet Missing", Path)
    }
}

; --- KeyReader ---
KeyReaderFromFile(FilePath) {
    ParsedEntries := Map()
    if !FileExist(FilePath) {
        return ParsedEntries
    }
    FileContent := FileRead(FilePath)
    for line in StrSplit(FileContent, "`n", "`r") {
        line := Trim(line)
        if (line = "" || SubStr(line,1,1) = ";" || SubStr(line,1,1) = "#")
            continue
        parts := StrSplit(line, "=")
        if parts.Length < 2
            continue
        RightPart := parts[2]
        subParts := StrSplit(RightPart, ":")
        if subParts.Length < 2
            continue
        FileName := Trim(subParts[1])
        Content  := Trim(subParts[2])
        words := StrSplit(Content, " ")
        if words.Length < 1
            continue
        KeyName := Trim(words[1])
        if !ParsedEntries.Has(FileName)
            ParsedEntries[FileName] := Map()
        ParsedEntries[FileName][KeyName] := Content
    }
    return ParsedEntries
}

; --- LoadDynamicShortcuts ---
LoadDynamicShortcuts() {
    global ShortcutsMap, ShortcutsConfig, SnippetsMenu
    ShortcutsMap := Map()
    SnippetsMenu := Menu()
    Parsed := KeyReaderFromFile(ShortcutsConfig)
    for file, dict in Parsed {
        for key, val in dict {
            ShortcutsMap[key] := val
            if SubStr(key,1,2) = "::" {
                Hotstring(key, (*) => LoadSnippetFromPath(val))
            } else {
                Hotkey(key, (*) => LoadSnippetFromPath(val), "On")
            }
            SnippetsMenu.Add(key " → " val, (*) => LoadSnippetFromPath(val))
        }
    }
    A_TrayMenu.Delete()
    A_TrayMenu.Add("Add Snippet", (*) => AddSnippetGUI())
    A_TrayMenu.Add("Browse Snippets", (*) => ShowSnippetsGUI())
    A_TrayMenu.Add("Reload Shortcuts", (*) => LoadDynamicShortcuts())
    A_TrayMenu.Add("Exit Script", (*) => ExitApp())
    A_TrayMenu.Add("Snippets", SnippetsMenu)
}

; --- Add Snippet GUI ---
AddSnippetGUI() {
    MyGui := Gui("+AlwaysOnTop", "Add New Snippet")
    MyGui.Add("Text",, "Hotstring/Hotkey (e.g. ::.new:: or ^!9)")
    MyGui.Add("Edit", "vKeyName w300")
    MyGui.Add("Text",, "Snippet File Path (e.g. snippets/new.txt)")
    MyGui.Add("Edit", "vFilePath w300")
    MyGui.Add("Button", "Default", "Save").OnEvent("Click", (*) => SaveSnippet(MyGui))
    MyGui.Add("Button",, "Cancel").OnEvent("Click", (*) => MyGui.Destroy())
    MyGui.Show()
}

SaveSnippet(MyGui) {
    values := MyGui.Submit()
    KeyName := values.KeyName
    FilePath := values.FilePath

    FileName := "snippet_type - Copy.ahk"
    NewLine := "99,1=" FileName ":" KeyName "=" FilePath "`n"
    FileAppend(NewLine, ShortcutsConfig)
    LoadDynamicShortcuts()
    TrayTip("Snippet Added", KeyName " → " FilePath)
    MyGui.Destroy()
}

; --- Snippet Browser GUI ---
ShowSnippetsGUI() {
    global ShortcutsMap
    MyGui := Gui("+AlwaysOnTop +Resize", "Snippet Browser")
    LV := MyGui.Add("ListView", "vSnippetList w400 h300", ["KeyName","Value"])
    for key, val in ShortcutsMap {
        LV.Add("", key, val)
    }
    MyGui.Add("Button", "Insert").OnEvent("Click", (*) => InsertSnippet(LV))
    MyGui.Add("Button", "Edit").OnEvent("Click", (*) => EditSnippet(LV))
    MyGui.Add("Button", "Delete").OnEvent("Click", (*) => DeleteSnippet(LV))
    MyGui.Add("Button", "Close").OnEvent("Click", (*) => MyGui.Destroy())
    MyGui.Show()
}

InsertSnippet(LV) {
    Row := LV.GetNext()
    if (Row = 0) {
        MsgBox("Select a snippet first.")
        return
    }
    KeyName := LV.GetText(Row, 1)
    Value   := LV.GetText(Row, 2)
    LoadSnippetFromPath(Value)
    TrayTip("Snippet Inserted", KeyName " → " Value)
}

EditSnippet(LV) {
    Row := LV.GetNext()
    if (Row = 0) {
        MsgBox("Select a snippet first.")
        return
    }
    KeyName := LV.GetText(Row, 1)
    Value   := LV.GetText(Row, 2)

    EditGui := Gui("+AlwaysOnTop", "Edit Snippet")
    EditGui.Add("Text",, "Hotstring/Hotkey")
    EditGui.Add("Edit", "vEditKeyName w300", KeyName)
    EditGui.Add("Text",, "Snippet File Path")
    EditGui.Add("Edit", "vEditFilePath w300", Value)
    EditGui.Add("Button", "Default", "Save").OnEvent("Click", (*) => SaveEditedSnippet(EditGui, KeyName, Value))
    EditGui.Add("Button",, "Cancel").OnEvent("Click", (*) => EditGui.Destroy())
    EditGui.Show()
}

SaveEditedSnippet(EditGui, OldKey, OldVal) {
    values := EditGui.Submit()
    EditKeyName := values.EditKeyName
    EditFilePath := values.EditFilePath

    FileContent := FileRead(ShortcutsConfig)
    NewContent := ""
    for line in StrSplit(FileContent, "`n", "`r") {
        if InStr(line, OldKey "=" OldVal) {
            NewLine := "99,1=snippet_type - Copy.ahk:" EditKeyName "=" EditFilePath
            NewContent .= NewLine "`n"
        } else {
            NewContent .= line "`n"
        }
    }
    FileDelete(ShortcutsConfig)
    FileAppend(NewContent, ShortcutsConfig)
    LoadDynamicShortcuts()
    TrayTip("Snippet Edited", EditKeyName " → " EditFilePath)
    EditGui.Destroy()
}

DeleteSnippet(LV) {
    Row := LV.GetNext()
    if (Row = 0) {
        MsgBox("Select a snippet first.")
        return
    }
    KeyName := LV.GetText(Row, 1)
    Value   := LV.GetText(Row, 2)
    FileContent := FileRead(ShortcutsConfig)
    NewContent := ""
    for line in StrSplit(FileContent, "`n", "`r") {
        if InStr(line, KeyName "=" Value)
            continue
        NewContent .= line "`n"
    }
    FileDelete(ShortcutsConfig)
    FileAppend(NewContent, ShortcutsConfig)
    LoadDynamicShortcuts()
    TrayTip("Snippet Deleted", KeyName)
}

; --- Initial load ---
LoadDynamicShortcuts()