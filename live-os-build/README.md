# Live ISO building

Generate a Live ISO from the existing installation using following steps.

Copy this directory to **/opt** as `/opt/live-os-build`.

copy [../marineos.png](marineos.png) as `/opt/marineos.png`.


## Build ISO
Configure directory and default user variables as,
```bash
# Variables
# DIR
LIVE_DIR="/live-build"
CHROOT_DIR="$LIVE_DIR/chroot"
IMAGE_DIR="$LIVE_DIR/image"
EFI_DIR="$IMAGE_DIR/EFI/boot"
# User
USER_NAME="user"
```

Run script [generate-live-iso.sh](generate-live-iso.sh) as root,
```bash
./generate-live-iso.sh
```
Make sure to have an active internet connection while executing this script.

This will generate an ISO as **/live-build/MarineOS.iso**

### Copying generated ISO
Allow outbound traffic temporary and SCP of SFTP to another host.
```bash
sudo iptables -A OUTPUT -j ACCEPT
```



## Test
```bash
# Test suggestion
echo "🧪 Test BIOS: qemu-system-x86_64 -cdrom $LIVE_DIR/MarineOS.iso -m 2048"
echo "🧪 Test UEFI: qemu-system-x86_64 -cdrom $LIVE_DIR/MarineOS.iso -m 2048 -bios /usr/share/OVMF/OVMF_CODE.fd"
```