; Convert indexed/indexed.txt into shortcuts.conf (old format)
IndexedFile := A_ScriptDir "\indexed\index.txt"
ConfigFile  := A_ScriptDir "\shortcuts.conf"
SnippetDir  := A_ScriptDir "\indexed"

if !FileExist(IndexedFile) {
    MsgBox "indexed.txt not found!"
    ExitApp
}

Lines := StrSplit(FileRead(IndexedFile), "`n", "`r")
Output := ""

for line in Lines {
    line := Trim(line)
    if (line = "")
        continue

    ; Example line: 1,1: snippet_type - Copy.ahk -> ; --- Globals ---
    parts := StrSplit(line, "->")
    if parts.Length < 2
        continue

    left  := Trim(parts[1])
    right := Trim(parts[2])

    ; Extract the index (before the colon)
    tokens := StrSplit(left, ":")
    index  := Trim(tokens[1])

    ; Build hotstring and hotkey
    hs := "::" . index . "::"
    hk := "^!" . StrReplace(index, ",", "_")

    ; Build file path
    fileName := StrReplace(index, ",", "_") . ".txt"
    filePath := "indexed\" . fileName

    ; Write snippet text into file (overwrite safely)
    FileDelete(SnippetDir "\" fileName)
    FileAppend(right, SnippetDir "\" fileName, "UTF-8")

    ; Add entries to shortcuts.conf in OLD format
    Output .= "99,1=snippet_type - Copy.ahk:" . hs . "=" . filePath . "`n"
    Output .= "99,1=snippet_type - Copy.ahk:" . hk . "=" . filePath . "`n"
}

; Write shortcuts.conf
FileDelete(ConfigFile)
FileAppend(Output, ConfigFile, "UTF-8")

MsgBox "Conversion complete! Check shortcuts.conf and indexed folder."