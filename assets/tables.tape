Set Shell "bash"
Set Width 1200
Set Height 700
Set Theme "Dracula"
Set FontSize 14
Set Framerate 20
Set PlaybackSpeed 0.8

Type "nvim -u /tmp/dbiclient_demo_vimrc.vim"
Enter
Sleep 3s

Type ":DBIConnDemo"
Enter
Sleep 4s

# Browse table list
Sleep 1s
Type "j"
Sleep 0.4s
Type "j"
Sleep 0.4s

# Filter by name
Type "mw"
Sleep 0.6s
Type "pro"
Enter
Sleep 2s

# Reset
Type "mw"
Sleep 0.4s
Enter
Sleep 1.5s

# Filter by type
Type "mt"
Sleep 0.6s
Enter
Sleep 1.5s

# Count rows on employees
Type "mc"
Sleep 2s

Sleep 1s
Type ":qa!"
Enter
