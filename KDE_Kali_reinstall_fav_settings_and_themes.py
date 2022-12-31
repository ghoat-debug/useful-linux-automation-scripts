#this script assumes you had a backup and a json file with your favourite themes and settings and attempts to reinstall them for you, however they should be from the kali store and not internet downloaded.
#if custom downloads you have to edit the script to include the url to fetch the themes and extract.
import json
import subprocess

# Load the system settings and themes from the JSON file
with open("settings.json", "r") as f:
  settings = json.load(f)

# Set the GTK theme
subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", "gtk-theme", settings["gtk_theme"]])

# Set the icon theme
subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", "icon-theme", settings["icon_theme"]])

# Set the cursor theme
subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", "cursor-theme", settings["cursor_theme"]])

# Set the wallpaper
subprocess.run(["gsettings", "set", "org.gnome.desktop.background", "picture-uri", settings["wallpaper"]])

# Set the terminal color scheme
subprocess.run(["gsettings", "set", "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$(gsettings get org.gnome.Terminal.ProfilesList default|awk -F\' \' '{print $2}'|awk -F\'\' '{print $1}')/", "foreground-color", settings["color_scheme"]])

