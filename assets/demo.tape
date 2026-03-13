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

# Table list is open - filter by emp
Type "mw"
Sleep 0.8s
Type "emp"
Enter
Sleep 2s

# Reset filter
Type "mw"
Sleep 0.4s
Enter
Sleep 1.5s

# Press CR to SELECT employees
Enter
Sleep 3s

# WHERE edit - filter high earners
Type "mw"
Sleep 0.8s
Type "salary > 80000"
Enter
Sleep 2.5s

# ORDER BY salary
Type "mo"
Sleep 0.8s
Type "salary DESC"
Enter
Sleep 2.5s

Sleep 1s
Type ":qa!"
Enter
