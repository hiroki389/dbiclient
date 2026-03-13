Set Shell "bash"
Set Width 1200
Set Height 700
Set Theme "Dracula"
Set FontSize 14
Set Framerate 24
Set PlaybackSpeed 0.8

Type "nvim -u /tmp/dbiclient_demo_vimrc.vim"
Enter
Sleep 3s

Type ":DBIConnDemo"
Enter
Sleep 4s

# Table list opened - cursor on header, move to first data row
Type "j"
Sleep 0.3s
Type "j"
Sleep 0.3s

# Filter to employees only
Type "mw"
Sleep 0.6s
Type "emp"
Enter
Sleep 2s

# Now cursor is on header again - move to employees row
Type "j"
Sleep 0.3s
Type "j"
Sleep 0.3s

# SELECT employees
Enter
Sleep 3s

# Result float: WHERE filter
Type "mw"
Sleep 0.8s
Type "salary > 80000"
Enter
Sleep 2.5s

# ORDER BY salary DESC
Type "mo"
Sleep 0.8s
Type "salary DESC"
Enter
Sleep 2.5s

Sleep 1s
Type ":qa!"
Enter
