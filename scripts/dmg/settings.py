# dmgbuild settings: run via scripts/make-dmg.sh (defines `app` and `background` with -D)
application = defines["app"]
background = defines["background"]
files = [application]
symlinks = {"Applications": "/Applications"}
format = "UDZO"
size = None
window_rect = ((200, 200), (660, 400))
icon_size = 128
text_size = 13
icon_locations = {"IPTVMac.app": (170, 200), "Applications": (490, 200)}
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
icon = defines.get("icon")   # volume icon shown for the mounted disk
