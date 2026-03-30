; --- Globals ---
ShortcutsConfig := A_ScriptDir "\shortcuts.conf"
SnippetDir      := A_ScriptDir "\snippets"
ShortcutsMap    := Map()
SnippetsMenu    := Menu()
BrowserGui := ""
LV := ""

KeyName := ""
FilePath := ""
EditKeyName := ""
EditFilePath := ""
EditOldKey := ""

; Ensure snippets folder exists
if !DirExist(SnippetDir) {
    DirCreate(SnippetDir)
}

; Ensure common log file exists
logFile := A_ScriptDir "\actions.log"
if !FileExist(logFile) {
    FileAppend("=== Actions Log Started " FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") " ===`n", logFile, "UTF-8")
}

; --- Logging helper ---
LogAction(action, details) {
    logFile := A_ScriptDir "\actions.log"
    entry := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") " - " action ": " details "`n"
    FileAppend(entry, logFile, "UTF-8")
}

; --- Utility Functions ---
LoadSnippetFromPath(Path) {
    if FileExist(Path) {
        Snippet := FileRead(Path)
        A_Clipboard := Snippet
        SendText(Snippet)
        TrayTip("Snippet Inserted", Path)
        LogAction("INSERT", "Used snippet from " Path)
    } else {
        TrayTip("Snippet Missing", Path)
    }
}

ReadConfig() {
    Parsed := Map()
    if !FileExist(ShortcutsConfig)
        return Parsed
    FileContent := FileRead(ShortcutsConfig)
    for line in StrSplit(FileContent, "`n", "`r") {
        line := Trim(line)
        if (line = "" || SubStr(line,1,1) = ";" || SubStr(line,1,1) = "#")
            continue

        pos := InStr(line, ":")
        if (pos = 0)
            continue
        triggerPart := SubStr(line, pos+1)

        kv := StrSplit(triggerPart, "=")
        if kv.Length != 2
            continue

        Key := Trim(kv[1])
        Path := Trim(kv[2])
        Parsed[Key] := Path
    }
    return Parsed
}

WriteConfig(MapObj) {
    NewContent := ""
    for key, val in MapObj {
        NewLine := "99,1=snippet_type - Copy.ahk:" . key . "=" . val
        NewContent .= NewLine "`n"
    }
    FileDelete(ShortcutsConfig)
    FileAppend(NewContent, ShortcutsConfig)
}

LoadDynamicShortcuts() {
    global ShortcutsMap, SnippetsMenu
    ShortcutsMap := ReadConfig()
    SnippetsMenu := Menu()
    for key, val in ShortcutsMap {
        if InStr(key, "::") {
            Hotstring(key, (*) => LoadSnippetFromPath(val))
        } else {
            try Hotkey(key, (*) => LoadSnippetFromPath(val), "On")
        }
        SnippetsMenu.Add(key " ? " val, (*) => LoadSnippetFromPath(val))
    }
    A_TrayMenu.Delete()
    A_TrayMenu.Add("Add Snippet", (*) => AddSnippetGUI())
    A_TrayMenu.Add("Show Snippets", (*) => ShowSnippetsGUI())
    A_TrayMenu.Add("Insert Snippet", SnippetsMenu)
    A_TrayMenu.Add("Reload Shortcuts", (*) => LoadDynamicShortcuts())
    A_TrayMenu.Add("Open Log File", OpenLogFile)
    A_TrayMenu.Add("Clear Log File", ClearLogFile)
    A_TrayMenu.Add("Exit Script", (*) => ExitApp())
}

ClearLogFile(*) {
    logFile := A_ScriptDir "\actions.log"
    FileDelete(logFile)
    FileAppend("=== Actions Log Cleared " FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") " ===`n", logFile, "UTF-8")
    TrayTip("Log Cleared", "actions.log has been reset")
}


OpenLogFile(*) {
    logFile := A_ScriptDir "\actions.log"
    if FileExist(logFile) {
        Run(logFile)
    } else {
        MsgBox "Log file not found. It will be created once you perform an action."
    }
}

; --- Add Snippet GUI ---
AddSnippetGUI() {
    global AddGui, KeyName, FilePath
    AddGui := Gui("+AlwaysOnTop", "Add New Snippet")
    AddGui.Add("Text",, "Hotstring/Hotkey (e.g. ::.new:: or ^!9)")
    AddGui.Add("Edit", "vKeyName w300", KeyName)
    AddGui.Add("Text",, "Snippet File Path (e.g. snippets/new.txt)")
    AddGui.Add("Edit", "vFilePath w300", FilePath)
    AddGui.Add("Button",, "Save").OnEvent("Click", SaveSnippet)
    AddGui.Add("Button",, "Cancel").OnEvent("Click", CancelSnippet)
    AddGui.Show()
}

SaveSnippet(*) {
    global KeyName, FilePath, ShortcutsMap, AddGui
    AddGui.Submit()
    if (KeyName = "" || FilePath = "") {
        MsgBox "Both fields must be filled."
        return
    }
    ShortcutsMap[KeyName] := FilePath
    WriteConfig(ShortcutsMap)
    LoadDynamicShortcuts()
    TrayTip("Snippet Added", KeyName " ? " FilePath)
    LogAction("ADD", KeyName " ? " FilePath)
    AddGui.Destroy()
}

CancelSnippet(*) {
    global AddGui
    AddGui.Destroy()
}

; --- Snippet Browser GUI with Search + DoubleClick ---
ShowSnippetsGUI(*) {
    global BrowserGui, ShortcutsMap, LV, SearchBox
    BrowserGui := Gui("+AlwaysOnTop +Resize", "Snippet Browser")

    BrowserGui.Add("Text",, "Loaded " ShortcutsMap.Count " snippets")
    BrowserGui.Add("Text",, "Search:")
    SearchBox := BrowserGui.Add("Edit", "vSearchBox w300")
    BrowserGui.Add("Button",, "Filter").OnEvent("Click", DoSearch)

    LV := BrowserGui.Add("ListView", "w400 h300", ["KeyName","Value"])
    for key, val in ShortcutsMap {
        LV.Add("", key, val)
    }
    LV.OnEvent("DoubleClick", InsertSnippet)

    BrowserGui.Add("Button",, "Insert").OnEvent("Click", InsertSnippet)
    BrowserGui.Add("Button",, "Edit").OnEvent("Click", EditSnippet)
    BrowserGui.Add("Button",, "Delete").OnEvent("Click", DeleteSnippet)
    BrowserGui.Add("Button",, "Close").OnEvent("Click", CloseSnippetGUI)

    BrowserGui.OnEvent("Escape", (*) => CloseSnippetGUI())
    BrowserGui.Show()
}

DoSearch(*) {
    global LV, SearchBox, ShortcutsMap
    term := Trim(SearchBox.Text)
    LV.Delete()
    for key, val in ShortcutsMap {
        if (term = "" || InStr(key, term) || InStr(val, term)) {
            LV.Add("", key, val)
        }
    }
}

InsertSnippet(*) {
    global LV, SnippetDir
    Row := LV.GetNext()
    if (Row = 0) {
        MsgBox "Select a snippet first."
        return
    }
    KeyName := LV.GetText(Row, 1)
    FilePath := LV.GetText(Row, 2)

    if FileExist(FilePath) {
        Snippet := FileRead(FilePath)
        A_Clipboard := Snippet
        SendText(Snippet)
        TrayTip("Snippet Inserted", KeyName " ? " FilePath)

        ; Safe filename for storage
        safeFileName := StrReplace(StrReplace(StrReplace(KeyName,":","_"),"^","CTRLALT_"),"!","ALT_")
        fullPath := SnippetDir "\" safeFileName ".txt"

        ; Only delete if file exists
        if FileExist(fullPath) {
            FileDelete(fullPath)
        }
        FileAppend(Snippet, fullPath, "UTF-8")

        ; Log insertion
        LogAction("INSERT", KeyName " ? " fullPath)
    } else {
        TrayTip("Snippet Missing", FilePath)
    }
}

EditSnippet(*) {
    global LV, EditGui, EditOldKey
    Row := LV.GetNext()
    if (Row = 0) {
        MsgBox "Select a snippet first."
        return
    }
    KeyName := LV.GetText(Row, 1)
    FilePath := LV.GetText(Row, 2)

    EditGui := Gui("+AlwaysOnTop", "Edit Snippet")
    EditGui.Add("Text",, "Hotstring/Hotkey")
    EditGui.Add("Edit", "vEditKeyName w300", KeyName)
    EditGui.Add("Text",, "Snippet File Path")
    EditGui.Add("Edit", "vEditFilePath w300", FilePath)
    EditGui.Add("Button",, "Save").OnEvent("Click", SaveEditedSnippet)
    EditGui.Add("Button",, "Cancel").OnEvent("Click", CancelEditSnippet)
    EditGui.Show()

    EditOldKey := KeyName
}

SaveEditedSnippet(*) {
    global EditOldKey, ShortcutsMap, EditGui, SnippetDir
    EditGui.Submit()
    EditKeyName  := EditGui["EditKeyName"].Text
    EditFilePath := EditGui["EditFilePath"].Text

    if (EditKeyName = "" || EditFilePath = "") {
        MsgBox "Both fields must be filled."
        return
    }

    ; Update map
    ShortcutsMap.Delete(EditOldKey)
    ShortcutsMap[EditKeyName] := EditFilePath

    ; --- Create file if it doesn’t exist ---
    if !FileExist(EditFilePath) {
        folder := StrSplit(EditFilePath, "\")[1]
        if !DirExist(folder) {
            DirCreate(folder)
        }
        FileAppend("New snippet for " EditKeyName, EditFilePath, "UTF-8")
    }

    ; Write back to config and reload
    WriteConfig(ShortcutsMap)
    LoadDynamicShortcuts()

    TrayTip("Snippet Edited", EditKeyName " ? " EditFilePath)
    LogAction("EDIT", EditOldKey " ? " EditKeyName " ? " EditFilePath)
    EditGui.Destroy()
}

CancelEditSnippet(*) {
    global EditGui
    EditGui.Destroy()
}

DeleteSnippet(*) {
    global LV, ShortcutsMap, BrowserGui, SnippetDir
    Row := LV.GetNext()
    if (Row = 0) {
        MsgBox "Select a snippet first."
        return
    }
    KeyName := LV.GetText(Row, 1)
    FilePath := LV.GetText(Row, 2)

    result := MsgBox("Are you sure you want to delete '" KeyName "'?", "Confirm Delete", 4)
    if (result = "No") {
        return
    }

    ShortcutsMap.Delete(KeyName)
    WriteConfig(ShortcutsMap)
    LoadDynamicShortcuts()

    ; Delete files
    deletedFiles := ""
    if FileExist(FilePath) {
        FileDelete(FilePath)
        deletedFiles .= FilePath "`n"
    }
    safeFileName := StrReplace(StrReplace(StrReplace(KeyName,":","_"),"^","CTRLALT_"),"!","ALT_")
    fullPathSnippets := SnippetDir "\" safeFileName ".txt"
    if FileExist(fullPathSnippets) {
        FileDelete(fullPathSnippets)
        deletedFiles .= fullPathSnippets "`n"
    }
    fullPathIndexed := A_ScriptDir "\indexed\" safeFileName ".txt"
    if FileExist(fullPathIndexed) {
        FileDelete(fullPathIndexed)
        deletedFiles .= fullPathIndexed "`n"
    }

    TrayTip("Snippet Deleted", KeyName)
    MsgBox "Deleted snippet '" KeyName "' and files:`n" deletedFiles, "Deletion Log"
    LogAction("DELETE", KeyName " ? " deletedFiles)
    BrowserGui.Destroy()
}

CloseSnippetGUI(*) {
    global BrowserGui
    BrowserGui.Destroy()
}

; --- Scoped Hotkeys for GUI ---
#HotIf WinActive("Snippet Browser")
Enter::InsertSnippet()
Delete::DeleteSnippet()
^e::EditSnippet()
Esc::CloseSnippetGUI()
#HotIf

; --- Initial load (auto-execute section) ---
LoadDynamicShortcuts()