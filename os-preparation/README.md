# OS preparation steps

This installation is based on **Debian 12** installed from ISO [https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12.10.0-amd64-netinst.iso](https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12.10.0-amd64-netinst.iso) Wihtout GUI and as a base system.


Traget hardware will be `Intel J4125` with `UHD 600 Graphics`

Here,
1. only **tty1** is activated with auto logged user **user**.
2. **user** will be automatically logged to tty1 and *x* will be started 
3. only a single desktop will be available user openbox

Make sure to create a user as **user** during the installation.


## Package installation and removal
Update and install required packages using,
```bash
apt update -y
apt install -y chromium openbox xbindkeys xdotool unclutter xorg xinit evtest python3 python3-evdev python3-cryptography network-manager iptables chrony \
 fonts-noto fonts-noto-extra fonts-noto-cjk fonts-noto-ui-core fonts-noto-ui-extra curl wget sudo vim jq rsyslog net-tools xterm yad wget \
 live-build squashfs-tools xorriso grub-pc-bin grub-efi-amd64-bin isolinux syslinux-common grub-common grub-efi \
 debian-installer debian-installer-launcher cdebconf chrony overlayroot xvfb \
 git make gcc libevdev-dev \
 xdotool wmctrl \
 mesa-utils mesa-utils-extra libgl1-mesa-dri libgl1-mesa-glx libglu1-mesa \
 firmware-misc-nonfree
```

Remova packages using,
```bash
apt remove -y firewalld
```

Disable services,
```bash
systemctl mask avahi-daemon;
systemctl stop avahi-daemon --now;
```

### Install OpenCPN
Enable backport repos and install OpenCPN 

```bash
cat <<EOF > /etc/apt/sources.list.d/backport.list
deb http://deb.debian.org/debian bookworm-backports main
EOF
# 
apt clean all ;
apt -y update ;
#
apt -y install opencpn
```


## Disable tty except tty1
Mask getty services and disable their **ExecStart**
```bash
for tty in {2..12}; do
    mkdir -p /etc/systemd/system/getty@tty$tty.service.d
    echo -e "[Service]\nExecStart=\nExecStart=-/bin/false" > "/etc/systemd/system/getty@tty$tty.service.d/override.conf"
    systemctl daemon-reload
    systemctl restart getty@tty$tty
    systemctl stop getty@tty$tty
    systemctl mask getty@tty$tty.service
    echo "TTY$tty disabled."
done
```

Configure GRUB to restrict TTY access to tty1
```bash
GRUB_FILE="/etc/default/grub"
if grep -q "GRUB_CMDLINE_LINUX_DEFAULT" "$GRUB_FILE"; then
    sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet vconsole.keymap=us no_console_suspend console=tty1 i915.enable_psr=0 i915.enable_fbc=0"/' "$GRUB_FILE"
else
    echo 'GRUB_CMDLINE_LINUX_DEFAULT="quiet vconsole.keymap=us no_console_suspend console=tty1 i915.enable_psr=0 i915.enable_fbc=0"' >> "$GRUB_FILE"
fi
```

OS prober settings configuration
```bash
GRUB_FILE="/etc/default/grub"
OS_PROBER_SETTING="GRUB_DISABLE_OS_PROBER=false"
# Check if GRUB_DISABLE_OS_PROBER exists in the file
if grep -q "^GRUB_DISABLE_OS_PROBER=" "$GRUB_FILE"; then
    # Replace existing setting
    sed -i 's/^GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' "$GRUB_FILE"
    echo "Updated existing GRUB_DISABLE_OS_PROBER setting."
else
    # Append to the file
    echo "$OS_PROBER_SETTING" >> "$GRUB_FILE"
    echo "Added GRUB_DISABLE_OS_PROBER setting."
fi
```

Configure grub timeout to **0**
```bash
GRUB_FILE="/etc/default/grub"
cp "$GRUB_FILE" "$GRUB_FILE.bak"
# Ensure settings exist, otherwise add them
grep -q "^GRUB_TIMEOUT=" "$GRUB_FILE" || echo "GRUB_TIMEOUT=0" >> "$GRUB_FILE"
grep -q "^GRUB_HIDDEN_TIMEOUT=" "$GRUB_FILE" || echo "GRUB_HIDDEN_TIMEOUT=0" >> "$GRUB_FILE"
grep -q "^GRUB_HIDDEN_TIMEOUT_QUIET=" "$GRUB_FILE" || echo "GRUB_HIDDEN_TIMEOUT_QUIET=true" >> "$GRUB_FILE"

# Modify existing values if present
sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=0/' "$GRUB_FILE"
sed -i 's/^GRUB_HIDDEN_TIMEOUT=.*/GRUB_HIDDEN_TIMEOUT=0/' "$GRUB_FILE"
sed -i 's/^GRUB_HIDDEN_TIMEOUT_QUIET=.*/GRUB_HIDDEN_TIMEOUT_QUIET=true/' "$GRUB_FILE"
```

Update grub
```bash
update-grub
```


## Disable kernel modules for KVM
Disable kernel modules for KVM using,
```bash
echo -e "blacklist kvm\nblacklist kvm_intel\nblacklist kvm_amd" | sudo tee /etc/modprobe.d/disable-amt-virt.conf ;

echo "i915" >> /etc/initramfs-tools/modules ;

sudo update-initramfs -u ;
```


## X and Openbox
Xorg and openbox configurations as follows.

### Enforce to use Intel Graphics
Enforce to use Intel Graphics by Xorg using `modesetting` driver
```bash
# Create directory
sudo mkdir -p /etc/X11/xorg.conf.d
# Creating Intel Xorg configuration
sudo tee /etc/X11/xorg.conf.d/10-lvds.conf > /dev/null <<EOF
Section "Device"
    Identifier     "Intel Graphics"
    Driver         "modesetting"
EndSection
EOF

# Creating Intel Xorg configuration
#sudo tee /etc/X11/xorg.conf.d/10-lvds.conf > /dev/null <<EOF
#Section "Monitor"
#    Identifier     "LVDS1"
#    Modeline       "1920x1080_60.00"  173.00  1920 2048 2248 2576  1080 1083 1088 1120 -hsync +vsync
#    Option         "PreferredMode" "1920x1080_60.00"
#EndSection

#Section "Device"
#    Identifier     "Intel Graphics"
#    Driver         "modesetting"
#EndSection

#Section "Screen"
#    Identifier     "Screen0"
#   Device         "Intel Graphics"
#   Monitor        "LVDS1"
#    DefaultDepth   24
#    SubSection     "Display"
#        Depth      24
#        Modes      "1920x1080_60.00"
#    EndSubSection
#EndSection
EOF
```

### Enable auto login 
Enable auto login to user **user** on **tty1** using,
```bash
mkdir -p /etc/systemd/system/getty@tty1.service.d
echo -e "[Service]\nExecStart=\nExecStart=-/sbin/agetty --noclear --autologin user tty1" > /etc/systemd/system/getty@tty1.service.d/override.conf
systemctl daemon-reexec
systemctl restart getty@tty1
```

### X start and launching openbox
Create Xorg configurations for **user** and startx only if the tty is tty1
```bash
mkdir -p /home/user/.config/
chown user:user /home/user/.config/
su - user -c "touch ~/.Xauthority"
su - user -c "chmod 600 ~/.Xauthority"
mkdir -p /home/user/.local/share/xorg
chown -R user:user /home/user/.local/share/xorg
chmod -R 755 /home/user/.local/share/xorg
su - user -c "echo 'exec openbox-session' > ~/.xinitrc"
su - user -c "chmod +x ~/.xinitrc"
su - user -c "echo 'if [[ -z \$DISPLAY ]] && [[ \$(tty) == /dev/tty1 ]]; then startx; fi' >> ~/.bash_profile"
su - user -c "chmod +x ~/.bash_profile"
chown user:user /home/user/.config/
```


### keyd installation and configurations
`keyd` is usually not in Debian repositories, so clone it from [https://github.com/rvaiya/keyd](https://github.com/rvaiya/keyd) and build it.

This will be implement keystroke blockages and run applications/commands based on key strokes

```bash
# Download keyd source
cd /usr/local/src
git clone https://github.com/rvaiya/keyd.git
cd keyd
# Build and install
make
make install
```

Configure `keyd` configurations file `/etc/keyd/default.conf`
```bash
cat <<EOF > /etc/keyd/default.conf
[ids]
*

# Control and Alt Layers
[main]
leftcontrol = layer(control)
rightcontrol = layer(control)
leftalt = layer(alt)
rightalt = layer(alt)

[main]
q = q

# Control Layer (only block unsafe keys)
[control:C]
q = q
w = w

# Launch and kill apps 
[control+alt]
l = command(/usr/bin/pkill glxgears)
k = command(sudo -u user DISPLAY=:0 /usr/bin/glxgears -fullscreen -info &)
h = command(/usr/bin/pkill xterm)
g = command(sudo -u user DISPLAY=:0 /usr/bin/xterm -e "/usr/bin/glxinfo | more" &)
r = command(init 6)
u = command(init 0)

# Alt Layer
[alt:A]
f4 = 4
tab = -
d = d
EOF
```

Enable keyd service on boot using,
```bash
systemctl enable keyd;
```

#### OpenGL verification keystrokes
Following are the OpenGL functionality verification & manage power operations keystrokes  manage by `keyd`

| Keystroke | Function |
| --- | --- |
| ALT+CTRL+K | Launch `glxgears` |
| ALT+CTRL+L | Kill `glxgears` |
| ALT+CTRL+G | Launch `glxinfo` in a `xterm` window |
| ALT+CTRL+H | Kill `glxinfo` and `xterm` |
| ALT+CTRL+U | System shutdown  |
| ALT+CTRL+R | System reboot |


#### Key stroke blockage
Following key strokes have been blocked / neutralized
| Keystroke | Function |
| --- | --- |
| ALT+F4 | Window/App close |
| ALT+Tab | Window/App switch |
| CTRL+W | Common closure  keystroke |
| CTRL+W | Common closure  keystroke |



### Display configuration
Create a bash script as **/usr/local/bin/marineos_displayconfig** to configure optimum display configurations, disable sleep modes and disable the screensaver using,
```bash
cat <<EOF > /usr/local/bin/marineos_displayconfig
#!/bin/bash

# Detect connected displays
CONNECTED_DISPLAYS=(\$(xrandr | grep " connected" | awk '{print \$1}'))

if [ \${#CONNECTED_DISPLAYS[@]} -eq 0 ]; then
    echo "No active display detected!"
    exit 1
fi

# Assign the first display as the primary one (Display 1)
PRIMARY_DISPLAY=\${CONNECTED_DISPLAYS[0]}

echo "Primary Display: \$PRIMARY_DISPLAY"

# Get the highest resolution for the primary display
MAX_RESOLUTION=\$(xrandr | grep -A1 "\$PRIMARY_DISPLAY connected" | tail -n 1 | awk '{print \$1}')

if [ -z "\$MAX_RESOLUTION" ]; then
    echo "Could not determine the maximum resolution for \$PRIMARY_DISPLAY."
    exit 1
fi

echo "Maximum Supported Resolution: \$MAX_RESOLUTION"

# Apply the maximum resolution to the primary display
echo "Setting resolution \$MAX_RESOLUTION on \$PRIMARY_DISPLAY..."
xrandr --output "\$PRIMARY_DISPLAY" --mode "\$MAX_RESOLUTION"

# Disable all other displays
for DISPLAY in "\${CONNECTED_DISPLAYS[@]}"; do
    if [ "\$DISPLAY" != "\$PRIMARY_DISPLAY" ]; then
        echo "Disabling display: \$DISPLAY"
        xrandr --output "\$DISPLAY" --off
    fi
done

# Make settings persistent after reboot by saving them to ~/.xprofile
XPROFILE="\$HOME/.xprofile"

# Clear previous xrandr and xset settings from ~/.xprofile
sed -i '/xrandr --output/d' "\$XPROFILE" 2>/dev/null
sed -i '/xset /d' "\$XPROFILE" 2>/dev/null

# Add new settings
echo "xrandr --output \$PRIMARY_DISPLAY --mode \$MAX_RESOLUTION" >> "\$XPROFILE"
for DISPLAY in "\${CONNECTED_DISPLAYS[@]}"; do
    if [ "\$DISPLAY" != "\$PRIMARY_DISPLAY" ]; then
        echo "xrandr --output \$DISPLAY --off" >> "\$XPROFILE"
    fi
done

# Disable DPMS & disable scrensaver
xset -display :0 s off
xset -display :0 -dpms
xset -display :0 s noblank

# Add screen disabling settings to ~/.xprofile
echo "xset -display :0 s off" >> "\$XPROFILE"
echo "xset -display :0 s noblank" >> "\$XPROFILE"
echo "xset -display :0 -dpms" >> "\$XPROFILE"

chmod +x "\$XPROFILE"
EOF
##########################
chmod +x /usr/local/bin/marineos_displayconfig
```

#### Auto start display configurations
Auto start display configurations to apply changes by calling **/usr/local/bin/marineos_displayconfig** using,
```bash
AUTOSTART_FILE="/home/user/.config/openbox/autostart"
# Create directory
mkdir -p "/home/user/.config/openbox"
# Create script
cat <<EOF > "$AUTOSTART_FILE"
#!/bin/bash

# Hide the mouse pointer after inactivity
# unclutter &

# Display config
export DISPLAY=:0
export XAUTHORITY=/home/user/.Xauthority

# Wait for X server
while true; do
    if xrandr &>/dev/null; then
        break
    else
        sleep 0.5
    fi
done

# Apply
# /usr/local/bin/marineos_displayconfig

# Start opencpn
opencpn --fullscreen &
EOF
# Make executable and ownership
chmod +x "$AUTOSTART_FILE"
chown user:user "$AUTOSTART_FILE"
```

### Openbox configurations
Lock openbox to a single desktop *(instead of default 4)*.
This will also remove configurations related to right click context menu too.
```bash
CONFIG_DIR="/home/user/.config/openbox"
CONFIG_FILE="$CONFIG_DIR/rc.xml"
# Create directories
mkdir -p "$CONFIG_DIR"
# Create XML
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Creating Openbox config file..."
    cat <<EOF > "$CONFIG_FILE"
<?xml version="1.0" encoding="UTF-8"?>
<openbox_config>
    <desktops>
        <number>1</number>
    </desktops>
</openbox_config>
EOF
else
    echo "Updating existing Openbox configuration..."
    sed -i 's|<number>[0-9]\+</number>|<number>1</number>|' "$CONFIG_FILE"
fi
# Set permissions
chown user:user /home/user/.config/
```

### Disable sleep, hybernate and  suspend
Update **/etc/systemd/logind.conf** to disable sleep, hybernate, suspend and power key press options
```bash
# Update logind.conf to disable system sleep/hibernate/etc.
echo "Disabling system sleep, suspend, hibernate, and lid close actions..."
LOGIND_CONF="/etc/systemd/logind.conf"
# Conf file process
sudo sed -i 's/^#\?\s*HandleSuspendKey=.*/HandleSuspendKey=ignore/' "$LOGIND_CONF"
sudo sed -i 's/^#\?\s*HandleLidSwitch=.*/HandleLidSwitch=ignore/' "$LOGIND_CONF"
sudo sed -i 's/^#\?\s*HandleLidSwitchDocked=.*/HandleLidSwitchDocked=ignore/' "$LOGIND_CONF"
sudo sed -i 's/^#\?\s*HandleHibernateKey=.*/HandleHibernateKey=ignore/' "$LOGIND_CONF"
sudo sed -i 's/^#\?\s*HandlePowerKey=.*/HandlePowerKey=ignore/' "$LOGIND_CONF"
sudo sed -i 's/^#\?\s*IdleAction=.*/IdleAction=ignore/' "$LOGIND_CONF"
# Ensure all entries exist if they were missing
for setting in \
    "HandleSuspendKey=ignore" \
    "HandleLidSwitch=ignore" \
    "HandleLidSwitchDocked=ignore" \
    "HandleHibernateKey=ignore" \
    "HandlePowerKey=ignore" \
    "IdleAction=ignore"
do
    grep -q "^$setting" "$LOGIND_CONF" || echo "$setting" | sudo tee -a "$LOGIND_CONF" >/dev/null
done
# Reload systemd-logind to apply changes
echo "Restarting systemd-logind..."
sudo systemctl restart systemd-logind
```

## Sudo configurations
Create a custom sudo configurations file as **/etc/sudoers.d/marinosuser** to allow passwordless super user privileges to selected commands/binaries/scripts using,
```bash
############# sudo config ###################
echo "user ALL=(ALL) NOPASSWD: /usr/bin/nmtui" > /etc/sudoers.d/marinosuser
chmod 0440 /etc/sudoers.d/marinosuser
```


## Networking
Disable default networking and enable NetworkManager to be default using,
```bash
sed -i 's/managed=false/managed=true/' /etc/NetworkManager/NetworkManager.conf
systemctl enable NetworkManager --now
# Disable networking
systemctl mask networking
systemctl disable networking
systemctl stop networking
systemctl disable systemd-networkd
systemctl mask systemd-networkd
systemctl stop systemd-networkd
# Disable wifi
systemctl disable wpa_supplicant
systemctl mask wpa_supplicant
systemctl stop wpa_supplicant
# Disable modem manager
systemctl disable ModemManager
systemctl mask ModemManager
systemctl stop ModemManager
```



## Overlaying filesystem
Since Live ISO is not intended to be installed Overlaying filesystem is not getting applied


These need to be executed before iso building too *([generate-live-iso.sh](live-os-build/generate-live-iso.sh))*

