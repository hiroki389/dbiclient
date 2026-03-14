Set Shell "bash"
Set Width 1200
Set Height 700
Set Theme "Dracula"
Set FontSize 14
Set Framerate 24
Set PlaybackSpeed 0.8
Output assets/demo.gif

Type "nvim -u assets/demo_vimrc.vim"
Enter
Sleep 3s
Type ":DBIConnDemo"
Enter
Sleep 5s

# table list -> employees
Type "/employees"
Enter
Sleep 1s
Enter
Sleep 4s

# WHERE panel -> employees.dept = 'Engineering'
Type "mw"
Sleep 1s
Type "/employees.dept"
Enter
Sleep 0.8s
Type "$"
Sleep 0.4s
Type "a 'Engineering'"
Escape
Sleep 0.8s
Enter
Sleep 4s

# edit one row and generate UPDATE into ScratchSQL with Visual + Ctrl+U
Type "/Alice Johnson"
Enter
Sleep 1s
Type "0"
Sleep 0.5s
Type "3f|wciw96000"
Escape
Sleep 1s
Type "V"
Sleep 0.5s
Ctrl+U
Sleep 3s

# execute generated UPDATE from ScratchSQL
Type "V"
Sleep 0.5s
Type ":DBIExecute"
Enter
Sleep 4s

# close execution result, go back to SELECT result, reload, rollback
Type "md"
Sleep 1.5s
Type "mr"
Sleep 4s
Type ":DBIRollback"
Enter
Sleep 4s

Sleep 1s
Type ":qa!"
Enter
