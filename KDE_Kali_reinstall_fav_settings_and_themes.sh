#same script like the python one but in bash
#feel free to add to it and make it better
#this retrieves your settings from the settings.json file created earlier and applies them to your new system
#it assumes all your settings are from the official community store provided by kali

# Load the JSON string from the file
json=$(<settings.json)

# Convert the JSON string to a Bash associative array
eval "$(jq -r 'to_entries|map("settings[\(.key)]=\(.value|tostring)")|.[]' <<< "$json")"

# Set the GTK theme
gsettings set org.gnome.desktop.interface gtk-theme "${settings[gtk_theme]}"

# Set the icon theme
gsettings set org.gnome.desktop.interface icon-theme "${settings[icon_theme]}"

# Set the cursor theme
gsettings set org.gnome.desktop.interface cursor-theme "${settings[cursor_theme]}"

# Set the wallpaper
gsettings set org.gnome.desktop.background picture-uri "${settings[wallpaper]}"

# Set the terminal color scheme
gsettings set org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$(gsettings get org.gnome.Terminal.ProfilesList default|awk -F\' \' '{print $2}'|awk -F\'\' '{print $1}')/ foreground-color "${settings[color_scheme]}"

