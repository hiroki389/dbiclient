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

# Navigate down to first data row
Type "j"
Sleep 0.3s
Type "j"
Sleep 0.4s
Type "j"
Sleep 0.3s
Type "j"
Sleep 0.4s

# Count rows
Type "mc"
Sleep 2s

# Move to next table
Type "j"
Sleep 0.4s

# Filter by name
Type "mw"
Sleep 0.6s
Type "pro"
Enter
Sleep 2s

# Move to project row
Type "j"
Sleep 0.3s
Type "j"
Sleep 0.3s

# SELECT projects
Enter
Sleep 3s

Sleep 1s
Type ":qa!"
Enter
