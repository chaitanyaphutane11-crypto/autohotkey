#NoTrayIcon
; Press Ctrl + Alt + T to start "Human Typing" from your clipboard
^!t::
{
    clipboardText := A_Clipboard
    Loop parse, clipboardText
    {
        ; Random delay between 40ms and 120ms to mimic human speed
        RandomDelay := Random(40, 120)
        
        ; Occasionally add a longer "thinking" pause (1 in 20 chance)
        if (Random(1, 20) == 1)
            Sleep(Random(400, 800))

        SendText(A_LoopField)
        Sleep(RandomDelay)
        
        ; Press Escape to emergency stop the typing
        if GetKeyState("Esc", "P")
            break
    }
}
