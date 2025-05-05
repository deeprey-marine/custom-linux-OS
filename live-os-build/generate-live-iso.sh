#!/bin/bash
set -e

# Variables
# DIR
LIVE_DIR="/live-build"
CHROOT_DIR="$LIVE_DIR/chroot"
IMAGE_DIR="$LIVE_DIR/image"
EFI_DIR="$IMAGE_DIR/EFI/boot"
# User
USER_NAME="user"

# Remove DIRs
rm -rfR $LIVE_DIR

echo "🚀 Creating MarineOS Live ISO with BIOS + UEFI support..."

# Step 1: Create working directories
echo "📁 Setting up directories..."
mkdir -p "$CHROOT_DIR" "$IMAGE_DIR/live" "$IMAGE_DIR/isolinux" "$EFI_DIR"

# Step 2: Clone system
echo "📋 Copying current system..."
rm -rf /opt/chromium-started
sudo rsync -aAXv --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found","$LIVE_DIR/*","/opt/live-os-build/",,"/opt/netinstall-os-build/"} / "$CHROOT_DIR"
# Download GTK installer
# Flush all rules in all tables
iptables -F
iptables -t nat -F
iptables -t mangle -F
iptables -X
# Set default policies to ACCEPT (allow everything)
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
wget https://ftp.debian.org/debian/dists/stable/main/installer-amd64/current/images/netboot/gtk/debian-installer/amd64/initrd.gz -O $CHROOT_DIR/boot/gtk-vmlinuz


# Step 3: Preserve user
echo "👤 Preserving user '$USER_NAME'..."
sudo cp -a /home/$USER_NAME "$CHROOT_DIR/home/"
grep ^$USER_NAME: /etc/passwd | sudo tee -a "$CHROOT_DIR/etc/passwd"
grep ^$USER_NAME: /etc/shadow | sudo tee -a "$CHROOT_DIR/etc/shadow"
grep ^$USER_NAME: /etc/group | sudo tee -a "$CHROOT_DIR/etc/group"
grep ^$USER_NAME: /etc/gshadow | sudo tee -a "$CHROOT_DIR/etc/gshadow"
sudo chroot $CHROOT_DIR usermod -aG video,input,tty user

# Step 4: Copy kernel and initrd
echo "🧬 Copying kernel and initrd..."
KERNEL_VERSION=$(ls /boot/vmlinuz-* | sed 's/.*vmlinuz-//')
sudo cp "/boot/vmlinuz-$KERNEL_VERSION" "$IMAGE_DIR/live/vmlinuz"
sudo cp "/boot/initrd.img-$KERNEL_VERSION" "$IMAGE_DIR/live/initrd"

# Step 5: SSH and paasword removal
echo "🚫 Removing sshd from the live system..."
#sudo rm -rf "$CHROOT_DIR/etc/systemd/system/sshd.service"
#sudo rm -rf "$CHROOT_DIR/etc/ssh"
#sudo rm -rf "$CHROOT_DIR/var/run/sshd"

echo "🔓 Removing passwords for root and user..."
sudo sed -i 's|^root:[^:]*:|root::|' "$CHROOT_DIR/etc/shadow"
sudo sed -i 's|^user:[^:]*:|user::|' "$CHROOT_DIR/etc/shadow"


# Step 6: Lock to tty1
echo "🔧 Applying system customizations inside live environment..."

# Mount necessary virtual filesystems for chroot operations
sudo mount --bind /dev "$CHROOT_DIR/dev"
sudo mount --bind /proc "$CHROOT_DIR/proc"
sudo mount --bind /sys "$CHROOT_DIR/sys"

# Enter chroot and apply configurations
sudo chroot "$CHROOT_DIR" /bin/bash <<'EOF'

# ---- Disable TTYs except tty1 ----
echo "🚫 Disabling TTYs 2-12..."
for tty in {2..12}; do
    mkdir -p "/etc/systemd/system/getty@tty$tty.service.d"
    echo -e "[Service]\nExecStart=\nExecStart=-/bin/false" > "/etc/systemd/system/getty@tty$tty.service.d/override.conf"
    systemctl mask getty@tty$tty.service
done

# ---- Configure GRUB for tty1 only ----
echo "🧾 Configuring GRUB console to tty1 only..."
GRUB_FILE="/etc/default/grub"
if grep -q "GRUB_CMDLINE_LINUX_DEFAULT" "$GRUB_FILE"; then
    sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet vconsole.keymap=us no_console_suspend console=tty1"/' "$GRUB_FILE"
else
    echo 'GRUB_CMDLINE_LINUX_DEFAULT="quiet vconsole.keymap=us no_console_suspend console=tty1"' >> "$GRUB_FILE"
fi

# ---- Enable OS Prober ----
if grep -q "^GRUB_DISABLE_OS_PROBER=" "$GRUB_FILE"; then
    sed -i 's/^GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' "$GRUB_FILE"
else
    echo "GRUB_DISABLE_OS_PROBER=false" >> "$GRUB_FILE"
fi

# ---- Set GRUB Timeout to 0 ----
cp "$GRUB_FILE" "$GRUB_FILE.bak"
grep -q "^GRUB_TIMEOUT=" "$GRUB_FILE" || echo "GRUB_TIMEOUT=0" >> "$GRUB_FILE"
grep -q "^GRUB_HIDDEN_TIMEOUT=" "$GRUB_FILE" || echo "GRUB_HIDDEN_TIMEOUT=0" >> "$GRUB_FILE"
grep -q "^GRUB_HIDDEN_TIMEOUT_QUIET=" "$GRUB_FILE" || echo "GRUB_HIDDEN_TIMEOUT_QUIET=true" >> "$GRUB_FILE"

sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=0/' "$GRUB_FILE"
sed -i 's/^GRUB_HIDDEN_TIMEOUT=.*/GRUB_HIDDEN_TIMEOUT=0/' "$GRUB_FILE"
sed -i 's/^GRUB_HIDDEN_TIMEOUT_QUIET=.*/GRUB_HIDDEN_TIMEOUT_QUIET=true/' "$GRUB_FILE"

# ---- Set GRUB Password ----
echo "🔐 Configuring GRUB admin password..."
GRUB_PASSWORD='PA55W0rd'
GRUB_CUSTOM="/etc/grub.d/40_custom"
touch "$GRUB_CUSTOM"
if ! grep -q "password_pbkdf2" "$GRUB_CUSTOM"; then
    PASSWORD_HASH=$(echo -e "$GRUB_PASSWORD\n$GRUB_PASSWORD" | grub-mkpasswd-pbkdf2 | grep 'grub.pbkdf2' | awk '{print $NF}')
    cat <<EOG >> "$GRUB_CUSTOM"
# GRUB Superuser Configuration
set superusers="admin"
password_pbkdf2 admin $PASSWORD_HASH

for menuentry_id in \$(seq 0 \$((\${#menuentry[@]} - 1))); do
    set menuentry[\$menuentry_id] --users="admin"
done
EOG
fi

# ---- Disable Kernel Modules: KVM ----
echo -e "blacklist amtservice\nblacklist kvm\nblacklist kvm_intel\nblacklist kvm_amd" > /etc/modprobe.d/disable-amt-virt.conf
update-initramfs -u

# ---- X and Openbox Autologin to user on tty1 ----
echo "🔐 Enabling tty1 autologin to 'user'..."
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat <<EOT > /etc/systemd/system/getty@tty1.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --noclear --autologin user tty1
EOT

# Cleanup any SSH configs just in case
apt-get purge -y openssh-server openssh-client
rm -rf /etc/ssh /var/run/sshd

# Remove passwords
sed -i 's|^root:[^:]*:|root::|' /etc/shadow
sed -i 's|^user:[^:]*:|user::|' /etc/shadow

EOF

# Plymouth theme
sudo chroot "$CHROOT_DIR" apt install -y plymouth plymouth-themes
sudo chroot "$CHROOT_DIR" mkdir -p /usr/share/plymouth/themes/MarineOS
sudo chroot "$CHROOT_DIR" cp /opt/marineos.png /usr/share/plymouth/themes/MarineOS/background.png
sudo chroot "$CHROOT_DIR" tee /usr/share/plymouth/themes/MarineOS/MarineOS.plymouth > /dev/null <<EOF
[Plymouth Theme]
Name=MarineOS
Description=Custom MarineOS Boot Splash
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/MarineOS
ScriptFile=/usr/share/plymouth/themes/MarineOS/MarineOS.script
EOF
#
sudo chroot "$CHROOT_DIR" tee /usr/share/plymouth/themes/MarineOS/MarineOS.script > /dev/null <<'EOF'
screen_width = Window.GetWidth()
screen_height = Window.GetHeight()
img = Image("background.png")
img_width = img.GetWidth()
img_height = img.GetHeight()
Window.SetBackgroundTopColor(0.0, 0.0, 0.0) # Black
Window.SetBackgroundBottomColor(0.0, 0.0, 0.0) # Black
Window.SetImage(img, (screen_width-img_width)/2, (screen_height-img_height)/2, 255)
EOF
# Configure
sudo chroot "$CHROOT_DIR" plymouth-set-default-theme -R MarineOS

# Update GRUB outside chroot (optional — UEFI builds may not require it here)
sudo chroot "$CHROOT_DIR" update-grub || true

# Unmount bind mounts
sudo umount "$CHROOT_DIR/dev" || true
sudo umount "$CHROOT_DIR/proc" || true
sudo umount "$CHROOT_DIR/sys" || true

# Comment /etc/fstab
echo ""> $CHROOT_DIR/etc/fstab


# Step 7: Create squashfs
echo "📦 Creating squashfs..."
chroot $CHROOT_DIR apt install -y systemd-sysv
sudo chroot $CHROOT_DIR apt install -y live-boot
sudo chroot $CHROOT_DIR update-initramfs -u
sudo cp $CHROOT_DIR/boot/vmlinuz-* $IMAGE_DIR/live/vmlinuz
sudo cp $CHROOT_DIR/boot/gtk-vmlinuz $IMAGE_DIR/live/gtk-vmlinuz
sudo cp $CHROOT_DIR/boot/initrd.img-* $IMAGE_DIR/live/initrd
#sudo mksquashfs "$CHROOT_DIR" "$IMAGE_DIR/live/filesystem.squashfs" -e boot
#sudo mksquashfs "$CHROOT_DIR" "$IMAGE_DIR/live/filesystem.squashfs" -e boot -comp xz -Xbcj x86 -b 1M
sudo mksquashfs "$CHROOT_DIR" "$IMAGE_DIR/live/filesystem.squashfs" -e boot -comp zstd -b 1M

# Step 8: Hardening
sudo chroot $CHROOT_DIR  rm -rf /usr/bin/apt
sudo chroot $CHROOT_DIR  ln -s /sbin/nologin /usr/bin/apt
sudo chroot $CHROOT_DIR  rm -rf /usr/bin/apt-get
sudo chroot $CHROOT_DIR  ln -s /sbin/nologin /usr/bin/apt-get
sudo chroot $CHROOT_DIR  rm -rf /usr/bin/dpkg
sudo chroot $CHROOT_DIR  ln -s /sbin/nologin /usr/bin/dpkg
sudo chroot $CHROOT_DIR  rm -rf /usr/bin/xterm
sudo chroot $CHROOT_DIR  ln -s /sbin/nologin /usr/bin/xterm

# Step 9: Set up ISOLINUX (BIOS boot)
# Splash
echo "Converting splash"
apt install -y imagemagick
convert /opt/marineos.png -resize 640x480\! -colors 16 PNG8:/opt/marineos_splash.png
cp /opt/marineos_splash.png "$IMAGE_DIR/isolinux/splash.png"
##########################
echo "🧰 Setting up ISOLINUX for BIOS boot..."
cat <<EOF | sudo tee "$IMAGE_DIR/isolinux/isolinux.cfg"
UI menu.c32
MENU BACKGROUND splash.png
PROMPT 1
TIMEOUT 600
NOESCAPE 1

DEFAULT live

LABEL live
    MENU LABEL MarineOS - Live
    KERNEL /live/vmlinuz
    APPEND initrd=/live/initrd boot=live vconsole.keymap=us no_console_suspend console=tty1
EOF

sudo cp /usr/lib/ISOLINUX/isolinux.bin "$IMAGE_DIR/isolinux/"
sudo cp /usr/lib/syslinux/modules/bios/menu.c32 "$IMAGE_DIR/isolinux/"
sudo cp /usr/lib/ISOLINUX/isolinux.bin "$IMAGE_DIR/isolinux/"
sudo cp /usr/lib/syslinux/modules/bios/libutil.c32 "$IMAGE_DIR/isolinux/"
sudo cp /usr/lib/syslinux/modules/bios/menu.c32 "$IMAGE_DIR/isolinux/"
sudo cp /usr/lib/syslinux/modules/bios/ldlinux.c32 "$IMAGE_DIR/isolinux/"
sudo cp /usr/lib/ISOLINUX/isolinux.bin "$IMAGE_DIR/isolinux/"


# Step 10: Set up GRUB (UEFI boot)
mkdir -p "$IMAGE_DIR/EFI/boot"
mkdir -p "$IMAGE_DIR/boot/grub"
mkdir -p "$WORK_DIR/efi"
# Splash
cp /opt/marineos.png "$IMAGE_DIR/boot/grub/marineos.png"
# Generate
grub-mkimage -o "$WORK_DIR/efi/bootx64.efi" \
  -p /boot/grub \
  -O x86_64-efi \
  iso9660 fat part_gpt part_msdos normal efi_gop efi_uga configfile linux search search_label search_fs_uuid search_fs_file gfxterm gfxmenu
# Copy GRUB EFI binary to ISO location
cp "$WORK_DIR/efi/bootx64.efi" "$IMAGE_DIR/EFI/boot/bootx64.efi"
# Generate grub
cat <<EOF | tee "$IMAGE_DIR/boot/grub/grub.cfg"
set default=0
set timeout=0
set gfxmode=1024x768
set gfxpayload=keep
insmod gfxterm
insmod png
background_image /boot/grub/marineos.png

menuentry "MarineOS - Live" {
    linux /live/vmlinuz boot=live vconsole.keymap=us no_console_suspend console=tty1
    initrd /live/initrd
}
EOF



# Step 11: Create hybrid ISO
echo "💿 Building hybrid ISO image (BIOS)..."
xorriso -as mkisofs -o "$LIVE_DIR/MarineOS.iso" \
  -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
  -c isolinux/boot.cat -b isolinux/isolinux.bin \
  -no-emul-boot -boot-load-size 4 -boot-info-table \
  -eltorito-alt-boot \
  -e EFI/boot/bootx64.efi \
  -no-emul-boot \
  -isohybrid-gpt-basdat \
  "$IMAGE_DIR"


echo "✅ ISO built successfully: $LIVE_DIR/MarineOS.iso"

