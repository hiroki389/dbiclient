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

# Navigate to employees row
Type "j"
Sleep 0.3s
Type "j"
Sleep 0.3s

# SELECT employees
Enter
Sleep 3s

# Move cursor to a data row (below header + separator)
Type "j"
Sleep 0.3s
Type "j"
Sleep 0.4s

# Generate INSERT
Type "mi"
Sleep 2s

# Tab to ScratchSQL float
Type ""
Sleep 1s

# Tab back to result float
Type ""
Sleep 1s

# Generate UPDATE
Type "mu"
Sleep 2s

# Generate DELETE
Type "md"
Sleep 2s

Sleep 1s
Type ":qa!"
Enter
