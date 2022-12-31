#this script takes your current system themes and settings and saves them to a json file so next time you reinstall your operating system you save time by automating
#also good if you wan't to deploy it to another system and wish to replicate your settings & themes
#tried it on my kali 2022
#feel free to add to it and add it to the list, just my main ones here.

import json
import subprocess

# Define a dictionary to store the system settings and themes
settings = {}

# Get the current GTK theme
gtk_theme = subprocess.run(["gsettings", "get", "org.gnome.desktop.interface", "gtk-theme"], capture_output=True).stdout.strip().decode("utf-8")
settings["gtk_theme"] = gtk_theme

# Get the current icon theme
icon_theme = subprocess.run(["gsettings", "get", "org.gnome.desktop.interface", "icon-theme"], capture_output=True).stdout.strip().decode("utf-8")
settings["icon_theme"] = icon_theme

# Get the current cursor theme
cursor_theme = subprocess.run(["gsettings", "get", "org.gnome.desktop.interface", "cursor-theme"], capture_output=True).stdout.strip().decode("utf-8")
settings["cursor_theme"] = cursor_theme

# Get the current wallpaper
wallpaper = subprocess.run(["gsettings", "get", "org.gnome.desktop.background", "picture-uri"], capture_output=True).stdout.strip().decode("utf-8")
settings["wallpaper"] = wallpaper

# Get the current terminal color scheme
color_scheme = subprocess.run(["gsettings", "get", "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$(gsettings get org.gnome.Terminal.ProfilesList default|awk -F\' \' '{print $2}'|awk -F\'\' '{print $1}')/", "foreground-color"], capture_output=True).stdout.strip().decode("utf-8")
settings["color_scheme"] = color_scheme

# Save the settings to a JSON file
with open("settings.json", "w") as f:
  json.dump(settings, f)


