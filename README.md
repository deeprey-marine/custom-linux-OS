# Marine OS 

This will explain MarineOS building steps

This is based on Debian **debian-12.10.0** *(bookworm)*.

Refer preceed config in [https://www.debian.org/releases/stable/armel/apb.en.html](https://www.debian.org/releases/stable/armel/apb.en.html)

## Components 
| # | Component | Description | Directory |
| --- | --- | --- | --- |
| 1 | OS installation | OS preparation steps | [os-preparation](os-preparation) |
| 2 | Live OS build steps | Live boot capable ISO with squashfs building steps and script | [live-os-build](live-os-build) |


#### OpenGL verification keystrokes & Power operations
Use folowing keystrokes to verify OpenGL functionalities & manage power operations.

| Keystroke | Function |
| --- | --- |
| ALT+CTRL+K | Launch `glxgears` |
| ALT+CTRL+L | Kill `glxgears` |
| ALT+CTRL+G | Launch `glxinfo` in a `xterm` window |
| ALT+CTRL+H | Kill `glxinfo` and `xterm` |
| ALT+CTRL+U | System shutdown  |
| ALT+CTRL+R | System reboot |