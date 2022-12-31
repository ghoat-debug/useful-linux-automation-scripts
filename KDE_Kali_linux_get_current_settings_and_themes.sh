#thisgets your current settings and theme and saves it to a json which you can ise to reinstall your system preferences to save time.
#feel free to add to the script to make it more versatile

# Define a dictionary to store the system settings and themes
declare -A settings

# Get the current GTK theme
gtk_theme=$(gsettings get org.gnome.desktop.interface gtk-theme)
settings[gtk_theme]=$gtk_theme

# Get the current icon theme
icon_theme=$(gsettings get org.gnome.desktop.interface icon-theme)
settings[icon_theme]=$icon_theme

# Get the current cursor theme
cursor_theme=$(gsettings get org.gnome.desktop.interface cursor-theme)
settings[cursor_theme]=$cursor_theme

# Get the current wallpaper
wallpaper=$(gsettings get org.gnome.desktop.background picture-uri)
settings[wallpaper]=$wallpaper

# Get the current terminal color scheme
color_scheme=$(gsettings get org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$(gsettings get org.gnome.Terminal.ProfilesList default|awk -F\' \' '{print $2}'|awk -F\'\' '{print $1}')/ foreground-color)
settings[color_scheme]=$color_scheme

# Convert the dictionary to a JSON string
json=$(jq -n --argjson settings "$settings")

# Save the JSON string to a file
echo $json > settings.json

