;#NoTrayIcon

; --- Globals ---
SourceDir := "C:\Users\Laxmikant\Documents\codefiles"
OutputDir := A_ScriptDir "\indexed"
MasterIndex := OutputDir "\index.txt"
KeyFile := OutputDir "\keys.txt"
LogFile := OutputDir "\debug.log"
AlphabeticalMode := false
LastIndexedCount := 0
LastIndexedTime := ""
SearchHotkey := "^!f"   ; Ctrl+Alt+F opens search prompt
Snippets := Map()

CurrentFileIndex := ""
CurrentDigits := ""
MaxFileIndex := 0

; --- Logging Helper ---
Log(msg) {
    global LogFile
    timestamp := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
    FileAppend("[" timestamp "] " msg "`n", LogFile)
}

; --- Paste Handler ---
PasteHandler(fileIndex, snippetIndex) {
    global Snippets
    key := fileIndex "," snippetIndex
    if Snippets.Has(key) {
        A_Clipboard := Snippets[key]
        Send("^v")
    } else {
        MsgBox "No snippet found for " key
    }
}

; --- Paste Snippet with Ctrl+P ---
^p::PasteSnippet()

PasteSnippet() {
    global CurrentFileIndex, CurrentDigits
    if (CurrentFileIndex = "" || CurrentDigits = "")
        return
    PasteHandler(CurrentFileIndex, CurrentDigits)
    TrayTip("Snippet Pasted", "File " CurrentFileIndex " | Snippet " CurrentDigits)
    CurrentFileIndex := ""
    CurrentDigits := ""
}

; --- Register hotkeys for every possible file index ---
RegisterFileIndexHotkeys() {
    global MaxFileIndex
    Loop MaxFileIndex {
        idx := A_Index
        Hotkey("^+" idx, (*) => SetFileIndex(idx))
    }
}

SetFileIndex(idx) {
    global CurrentFileIndex, CurrentDigits
    CurrentFileIndex := idx
    CurrentDigits := ""
    TrayTip("File Selected", "File: " idx " | Snippet: -")
}

; --- Individual digit handlers ---
~0::DigitHandler("0")
~1::DigitHandler("1")
~2::DigitHandler("2")
~3::DigitHandler("3")
~4::DigitHandler("4")
~5::DigitHandler("5")
~6::DigitHandler("6")
~7::DigitHandler("7")
~8::DigitHandler("8")
~9::DigitHandler("9")

DigitHandler(d) {
    global CurrentFileIndex, CurrentDigits
    CurrentDigits .= d
    TrayTip("Buffer", "File: " (CurrentFileIndex = "" ? "-" : CurrentFileIndex)
                  " | Snippet: " CurrentDigits)
}

; --- Search Handler ---
SearchHandler() {
    global MasterIndex, Snippets

    result := InputBox("Enter keyword to search:", "Search Code Snippets")
    keyword := result.Value
    if (keyword = "")
        return

    content := FileRead(MasterIndex)
    lines := StrSplit(content, "`n")

    matches := []
    for index, line in lines {
        if InStr(line, keyword) {
            matches.Push(line)
        }
    }

    if (matches.Length = 0) {
        MsgBox "No matches found for '" keyword "'"
        return
    }

    choice := ""
    for i, m in matches {
        choice .= i ": " m "`n"
    }

    selResult := InputBox("Choose index:`n" choice, "Select Match")
    sel := selResult.Value
    if (sel = "")
        return

    if RegExMatch(sel, "^\d+$") {
        idx := Integer(sel)
        if (idx >= 1 && idx <= matches.Length) {
            line := matches[idx]
            key := StrSplit(line, ":")[1]
            if Snippets.Has(key) {
                A_Clipboard := Snippets[key]
                Send("^v")
                TrayTip("Snippet Pasted", "Key " key)
            }
        }
    } else {
        if Snippets.Has(sel) {
            A_Clipboard := Snippets[sel]
            Send("^v")
            TrayTip("Snippet Pasted", "Key " sel)
        }
    }
}

; --- Indexing ---
ProcessFiles() {
    global SourceDir, OutputDir, MasterIndex, KeyFile, LogFile, AlphabeticalMode, LastIndexedCount, LastIndexedTime, Snippets, MaxFileIndex

    DirCreate(SourceDir)
    DirCreate(OutputDir)

    for f in [MasterIndex, KeyFile, LogFile] {
        if FileExist(f) {
            try FileDelete(f)
        }
    }

    fileIndex := 0
    Snippets.Clear()
    entries := []

    Log("Starting indexing in " SourceDir)

    Loop Files, SourceDir "\*.ahk"
    {
        fileIndex++
        file := A_LoopFileFullPath
        SplitPath(file, &filename)
        Log("Processing file: " file)

        snippetIndex := 1
        Loop Read, file
        {
            line := Trim(A_LoopReadLine)
            if (line = "")
                continue

            key := fileIndex . "," . snippetIndex
            Snippets[key] := line

            entries.Push({idx: key, name: filename, code: line})
            Log("Indexed " filename " -> " line)

            snippetIndex++
        }
    }

    MaxFileIndex := fileIndex
    LastIndexedCount := entries.Length
    LastIndexedTime := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")

    for entry in entries {
        FileAppend(entry.idx ": " entry.name " -> " entry.code "`n", MasterIndex)
    }
    Log("Master index written")

    for entry in entries {
        FileAppend(entry.idx "=" entry.name ":" entry.code "`n", KeyFile)
    }
    Log("Key file written")

    TrayTip("Done", "Master index + keys created")
    Log("Indexing complete")

    ; Register hotkeys for all file indices now that MaxFileIndex is known
    RegisterFileIndexHotkeys()
}

; --- Tray Menu Builder ---
UpdateTrayTitle() {
    global AlphabeticalMode, LastIndexedCount, LastIndexedTime
    mode := AlphabeticalMode ? "[Alphabetical]" : "[Original]"

    A_TrayMenu.Delete()
    A_TrayMenu.Add("Run Indexing " mode, (*) => ProcessFiles())
    A_TrayMenu.Add("Toggle Order Mode", (*) => ToggleOrderHandler())
    A_TrayMenu.Add("Exit Script", (*) => ExitApp())

    A_TrayMenu.Add("Last Indexed: " LastIndexedCount " lines", (*) => 0)
    A_TrayMenu.Disable("Last Indexed: " LastIndexedCount " lines")

    if (LastIndexedTime != "") {
        A_TrayMenu.Add("Last Run: " LastIndexedTime, (*) => 0)
        A_TrayMenu.Disable("Last Run: " LastIndexedTime)
    }

    TraySetIcon("shell32.dll", AlphabeticalMode ? 44 : 43)
    TrayTip("Indexer Mode", "Currently in " . mode)
}

; --- Order Toggle ---
ToggleOrderHandler() {
    global AlphabeticalMode
    AlphabeticalMode := !AlphabeticalMode
    UpdateTrayTitle()
    mode := AlphabeticalMode ? "Alphabetical Order" : "Original Order"
    TrayTip("Mode Toggled", "Now using " mode)
    Log("Order mode toggled -> " mode)
}

; --- Hotkeys for indexing ---
^!i::ProcessFiles()       ; Ctrl+Alt+I runs the indexing
^!o::ToggleOrderHandler() ; Ctrl+Alt+O toggles order mode
Hotkey(SearchHotkey, (*) => SearchHandler())

; --- Initial Tray Setup ---
UpdateTrayTitle()

; --- Run once at startup ---
ProcessFiles()