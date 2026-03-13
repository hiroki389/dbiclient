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

# Navigate to employees row (header + separator = 2 lines)
Type "j"
Sleep 0.3s
Type "j"
Sleep 0.3s

# SELECT employees
Enter
Sleep 3s

# WHERE: Engineering only
Type "mw"
Sleep 0.8s
Type "dept = 'Engineering'"
Enter
Sleep 2.5s

# ORDER BY salary DESC
Type "mo"
Sleep 0.8s
Type "salary DESC"
Enter
Sleep 2.5s

# Change LIMIT to 3
Type "mll"
Sleep 0.8s
Type "3"
Enter
Sleep 2s

Sleep 1s
Type ":qa!"
Enter
