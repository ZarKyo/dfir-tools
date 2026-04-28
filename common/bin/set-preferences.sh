#!/bin/bash
# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

# Set GNOME Shell dock favorite applications
gsettings set org.gnome.shell favorite-apps "[
    'org.gnome.Nautilus.desktop',
    'org.gnome.Terminal.desktop',
    'firefox_firefox.desktop',
    'org.wireshark.Wireshark.desktop'
]"

# Set clock to 24-hour format
gsettings set org.gnome.desktop.interface clock-format '24h'

# Prefer dark theme (apps that support it)
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'

# Enable Ubuntu AppIndicators (system tray icons)
gnome-extensions enable ubuntu-appindicators@ubuntu.com
# Enable Ubuntu Dock extension
gnome-extensions enable ubuntu-dock@ubuntu.com

# Dash-to-Dock GNOME extension schema
SCHEMA="org.gnome.shell.extensions.dash-to-dock"

gsettings set $SCHEMA activate-single-window true
gsettings set $SCHEMA always-center-icons true
gsettings set $SCHEMA animate-show-apps true
gsettings set $SCHEMA animation-time 0.2
gsettings set $SCHEMA apply-custom-theme true
gsettings set $SCHEMA apply-glossy-effect true
gsettings set $SCHEMA custom-theme-shrink true
gsettings set $SCHEMA autohide false
gsettings set $SCHEMA autohide-in-fullscreen false
gsettings set $SCHEMA dash-max-icon-size 32
gsettings set $SCHEMA dock-fixed true
gsettings set $SCHEMA dock-position "'BOTTOM'"
gsettings set $SCHEMA extend-height true
gsettings set $SCHEMA force-straight-corner false
gsettings set $SCHEMA hide-tooltip false
gsettings set $SCHEMA icon-size-fixed false
gsettings set $SCHEMA intellihide true
gsettings set $SCHEMA intellihide-mode "'FOCUS_APPLICATION_WINDOWS'"
gsettings set $SCHEMA isolate-locations true
gsettings set $SCHEMA isolate-monitors false
gsettings set $SCHEMA isolate-workspaces false
gsettings set $SCHEMA multi-monitor true
gsettings set $SCHEMA show-apps-always-in-the-edge true
gsettings set $SCHEMA show-apps-at-top true
gsettings set $SCHEMA show-favorites true
gsettings set $SCHEMA show-icons-emblems true
gsettings set $SCHEMA show-mounts true
gsettings set $SCHEMA show-mounts-network false
gsettings set $SCHEMA show-mounts-only-mounted true
gsettings set $SCHEMA show-running true
gsettings set $SCHEMA show-show-apps-button true
gsettings set $SCHEMA show-trash false
