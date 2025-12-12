#!/bin/bash

# ============================================
# Minimal Linux OS Builder Script
# Builds a custom Linux system with:
#   - Linux Kernel (minimal configuration)
#   - BusyBox (statically linked)
#   - System V init
# ============================================

set -e  # Exit immediately if any command fails

echo "=========================================="
echo "Starting Minimal Linux OS Build Process"
echo "=========================================="

# Clean up any previous builds
echo "[INFO] Cleaning previous build artifacts..."
rm -f bzImage ramfs.cpio.gz boot.iso 2>/dev/null || true
rm -rf fs/ iso/ 2>/dev/null || true

# ============================================
# 1. Clone and build Linux kernel
# ============================================
echo "[INFO] Cloning Linux kernel repository..."
if [ ! -d "linux" ]; then
    git clone https://github.com/torvalds/linux.git
else
    echo "[INFO] Linux directory already exists, skipping clone"
fi

cd linux

echo "[INFO] Creating minimal kernel configuration..."
make tinyconfig

# Enable essential kernel options
echo "[INFO] Configuring kernel options..."

# Enable 64-bit and x86_64 architecture
./scripts/config --enable CONFIG_64BIT --enable CONFIG_X86_64

# Enable binary format support
./scripts/config --enable CONFIG_BINFMT_ELF --enable CONFIG_BINFMT_SCRIPT

# Enable initrd and filesystem support
./scripts/config --enable CONFIG_BLK_DEV_INITRD --enable CONFIG_TMPFS --enable CONFIG_RD_GZIP

# Enable device and filesystem support
./scripts/config --enable CONFIG_DEVTMPFS --enable CONFIG_DEVTMPFS_MOUNT

# Enable console and terminal support
./scripts/config --enable CONFIG_TTY --enable CONFIG_VT --enable CONFIG_VT_CONSOLE
./scripts/config --enable CONFIG_SERIAL_8250 --enable CONFIG_SERIAL_8250_CONSOLE

# Enable system logging
./scripts/config --enable CONFIG_PRINTK --enable CONFIG_EARLY_PRINTK

# Enable proc and sys filesystems
./scripts/config --enable CONFIG_PROC_FS --enable CONFIG_SYSFS

# Disable modules for simplicity
./scripts/config --disable CONFIG_MODULES

# ============================================
# Network configuration
# ============================================
echo "[INFO] Configuring network support..."

# Basic network support
./scripts/config --enable CONFIG_NET --enable CONFIG_NETDEVICES --enable CONFIG_ETHERNET

# Intel network drivers (for QEMU)
./scripts/config --enable CONFIG_NET_VENDOR_INTEL --enable CONFIG_E1000 --enable CONFIG_E1000E

# PCI support for network cards
./scripts/config --enable CONFIG_PCI --enable CONFIG_PCI_MSI

# IP networking
./scripts/config --enable CONFIG_INET --enable CONFIG_IP_MULTICAST --enable CONFIG_IP_PNP --enable CONFIG_IP_PNP_DHCP

# Network tunneling
./scripts/config --enable CONFIG_NET_IPIP --enable CONFIG_NET_IPGRE_DEMUX --enable CONFIG_NET_UDP_TUNNEL

# Netfilter (firewall)
./scripts/config --enable CONFIG_NETFILTER --enable CONFIG_NETFILTER_ADVANCED
./scripts/config --enable CONFIG_NF_CONNTRACK --enable CONFIG_NF_CONNTRACK_IPV4
./scripts/config --enable CONFIG_IP_NF_IPTABLES --enable CONFIG_IP_NF_FILTER
./scripts/config --enable CONFIG_IP_NF_NAT --enable CONFIG_NF_NAT
./scripts/config --enable CONFIG_NF_NAT_IPV4 --enable CONFIG_NF_NAT_MASQUERADE_IPV4

# Network protocols
./scripts/config --enable CONFIG_PACKET --enable CONFIG_UNIX

# ============================================
# Additional system options
# ============================================
echo "[INFO] Configuring additional system options..."

# Disable block layer (simplified)
./scripts/config --disable CONFIG_BLOCK

# Enable multi-user and file locking
./scripts/config --enable CONFIG_MULTIUSER --enable CONFIG_FILE_LOCKING

# Disable unnecessary devices
./scripts/config --disable CONFIG_INPUT_MOUSE --disable CONFIG_RTC_CLASS

# UDP support
./scripts/config --enable CONFIG_INET_UDP --enable CONFIG_UDP_DIAG

# System calls and event handling
./scripts/config --enable CONFIG_FUTEX --enable CONFIG_FUTEX_PI --enable CONFIG_FUTEX_REQUEUE_PI
./scripts/config --enable CONFIG_EPOLL --enable CONFIG_EVENTFD --enable CONFIG_SIGNALFD --enable CONFIG_TIMERFD

echo "[INFO] Finalizing kernel configuration..."
make olddefconfig

echo "[INFO] Building kernel..."
make -j$(nproc)

echo "[INFO] Copying kernel image..."
cp arch/x86/boot/bzImage ..
cd ..

# ============================================
# 2. Clone and build BusyBox
# ============================================
echo "[INFO] Cloning BusyBox repository..."
if [ ! -d "busybox" ]; then
    git clone --depth 1 https://git.busybox.net/busybox
else
    echo "[INFO] BusyBox directory already exists, skipping clone"
fi

cd busybox

echo "[INFO] Configuring BusyBox..."
make defconfig

# Enable static linking and disable unnecessary features
sed -i 's/^# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config
sed -i 's/^CONFIG_TC=y/# CONFIG_TC is not set/' .config

echo "[INFO] Building BusyBox..."
make -j$(nproc)

cd ..

# ============================================
# 3. Create filesystem hierarchy
# ============================================
echo "[INFO] Creating filesystem hierarchy..."
mkdir -p fs
cd fs

# Create standard Unix directory structure
mkdir -pv {bin,sbin,lib,boot,dev,proc,sys,run,tmp,home,root,mnt,opt,srv}
mkdir -pv usr/{bin,sbin,lib,local,share} usr/local/{bin,sbin,lib}
mkdir -pv etc/{init.d,rc.d} etc/rc.d/{rc0.d,rc1.d,rc2.d,rc3.d,rc4.d,rc5.d,rc6.d,rcS.d}
mkdir -pv var/{log,spool,lock,lib,cache,tmp,mail}
mkdir -pv dev/pts
mkdir -pv media

# Set permissions for tmp directories
chmod 1777 tmp var/tmp

# Create and link run directories
rm -rf var/run var/lock 2>/dev/null || true
mkdir -p var/run var/lock
chmod 755 var/run var/lock
ln -sfn ../run var/run
ln -sfn ../run/lock var/lock

# Create lost+found directory
mkdir -pv lost+found
chmod 700 lost+found

# ============================================
# 4. Install BusyBox
# ============================================
echo "[INFO] Installing BusyBox..."
cp ../busybox/busybox bin/
chmod 4755 bin/busybox

# Create symlinks for all BusyBox applets
cd bin
echo "[INFO] Creating BusyBox symlinks..."

for app in $(./busybox --list); do
  case "$app" in
    init|halt|poweroff|reboot|shutdown|runlevel|telinit|*fsck*|mkfs*|mkswap|swapon|swapoff|mount|umount|losetup|fstrim|if*|ip*|arp*|route|nameif|brctl|vconfig|tunctl|udhcpc|udhcpd|inetd|syslogd|klogd|crond|getty|agetty|sulogin|start-stop-daemon|insmod|rmmod|modprobe|depmod|lsmod|modinfo|sysctl|hwclock|setconsole|setlogcons|watchdog|pivot_root|switch_root|chroot|mdev|fdisk|blkid|blockdev|mkdosfs|mke2fs|logread)
      # System administration tools go to sbin
      ln -sf ../bin/busybox ../sbin/$app
      ln -sf busybox $app
      ;;
    *)
      # Regular tools stay in bin
      ln -sf busybox $app
      ;;
  esac
done
cd ..

# ============================================
# 5. Create System V init configuration
# ============================================
echo "[INFO] Creating init configuration..."

# /etc/inittab - init process configuration
tee etc/inittab > /dev/null << 'EOF'
::sysinit:/etc/rc.d/rc.sysinit
::wait:/etc/rc.d/rc 3
::ctrlaltdel:/sbin/reboot
::shutdown:/etc/rc.d/rc 0
::restart:/sbin/init
tty1::respawn:/sbin/getty 38400 tty1
tty2::respawn:/sbin/getty 38400 tty2
ttyS0::respawn:/sbin/getty 115200 ttyS0
EOF

# init script - early userspace initialization
tee init > /dev/null << 'EOF'
#!/bin/sh
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev
mkdir -p /dev/pts
mkdir -p /dev/shm
mkdir -p /run
mount -t devpts devpts /dev/pts
mount -t tmpfs tmpfs /tmp
mount -t tmpfs tmpfs /run
mdev -s
chmod 666 /dev/null /dev/zero /dev/full /dev/random /dev/urandom
chmod 620 /dev/tty[0-9]* 2>/dev/null || true
chmod 666 /dev/ttyS0 /dev/ptmx
mount -o remount,rw / >/dev/null 2>&1 || true
exec /sbin/init
EOF

chmod +x init

# ============================================
# 6. Create System V init scripts
# ============================================

# rc.sysinit - system initialization
tee etc/rc.d/rc.sysinit > /dev/null << 'EOF'
#!/bin/sh
echo "Initializing..."
hostname localhost
echo 1 > /proc/sys/kernel/printk
mkdir -p /var/run /var/lock /var/log /run
chmod 755 /var/run /var/lock /var/log /run
touch /var/run/utmp
chmod 644 /var/run/utmp
echo "127.0.0.1 localhost" > /etc/hosts
sysctl -p /etc/sysctl.conf 2>/dev/null
/sbin/crond
echo "Setting up network..."
ip link set lo up
ip link set eth0 up
ip addr add 10.0.2.15/24 dev eth0
ip route add default via 10.0.2.2
echo "Network configured: 10.0.2.15/24, gateway 10.0.2.2"
echo "System initialization complete"
EOF

chmod +x etc/rc.d/rc.sysinit

# rc script - runlevel management
tee etc/rc.d/rc > /dev/null << 'EOF'
#!/bin/sh
runlevel=$1
echo "Changing to runlevel $runlevel"
for i in /etc/rc.d/rc$runlevel.d/K*; do
    [ -x "$i" ] && "$i" stop
done
for i in /etc/rc.d/rc$runlevel.d/S*; do
    [ -x "$i" ] && "$i" start
done
EOF

chmod +x etc/rc.d/rc

# ============================================
# 7. Create system configuration files
# ============================================

# Filesystem table
tee etc/fstab > /dev/null << 'EOF'
proc            /proc           proc    defaults        0 0
sysfs           /sys            sysfs   defaults        0 0
devtmpfs        /dev            devtmpfs defaults       0 0
tmpfs           /tmp            tmpfs   defaults        0 0
devpts          /dev/pts        devpts  gid=5,mode=620  0 0
EOF

# User and group files
tee etc/passwd > /dev/null << 'EOF'
root::0:0:root:/root:/bin/sh
daemon:x:1:1:daemon:/usr/sbin:/bin/false
sys:x:3:3:sys:/dev:/bin/false
nobody:x:65534:65534:nobody:/var:/bin/false
EOF

tee etc/shadow > /dev/null << 'EOF'
root::0:0:99999:7::: 
daemon:*:0:0:99999:7:::
sys:*:0:0:99999:7:::
nobody:*:0:0:99999:7:::
EOF

tee etc/group > /dev/null << 'EOF'
root:x:0:
daemon:x:1:
sys:x:3:
tty:x:5:
disk:x:6:
wheel:x:10:
nobody:x:65534:
EOF

chmod 644 etc/passwd etc/group
chmod 600 etc/shadow

# Shell environment
tee etc/profile > /dev/null << 'EOF'
export PS1='\u@\h:\w\$ '
export PATH=/bin:/sbin:/usr/bin:/usr/sbin
EOF

# System identification
tee etc/issue > /dev/null << 'EOF'
Linux + BusyBox + SysV
EOF

echo "localhost" > etc/hostname

# Create home directories
mkdir -p root home
touch root/.profile

# Kernel sysctl configuration
tee etc/sysctl.conf > /dev/null << 'EOF'
kernel.printk = 1 4 1 7
EOF

# Create cron directory
mkdir -p var/spool/cron/crontabs

# ============================================
# 8. Create init.d service scripts
# ============================================

# Halt service
tee etc/init.d/halt > /dev/null << 'EOF'
#!/bin/sh
case "$1" in
    stop)
        echo "System halting..."
        exec /sbin/poweroff -f
        ;;
esac
EOF

# Reboot service
tee etc/init.d/reboot > /dev/null << 'EOF'
#!/bin/sh
case "$1" in
    stop)
        echo "System rebooting..."
        /sbin/reboot
        ;;
esac
EOF

# Mount service
tee etc/init.d/mountall > /dev/null << 'EOF'
#!/bin/sh
case "$1" in
    start)
        mount -a
        ;;
    stop)
        umount -a
        ;;
esac
EOF

# Network service
tee etc/init.d/network > /dev/null << 'EOF'
#!/bin/sh
case "$1" in
    start|stop|restart)
        echo "Network service $1ed"
        ;;
esac
EOF

# Syslog service
tee etc/init.d/syslog > /dev/null << 'EOF'
#!/bin/sh
case "$1" in
    start)
        /sbin/syslogd -C -R 127.0.0.1
        /sbin/klogd
        ;;
    stop)
        killall syslogd klogd 2>/dev/null
        ;;
    restart)
        $0 stop
        $0 start
        ;;
esac
EOF

# Cron service
tee etc/init.d/crond > /dev/null << 'EOF'
#!/bin/sh
case "$1" in
    start)
        echo "Starting crond"
        /sbin/crond
        ;;
    stop)
        echo "Stopping crond"
        killall crond 2>/dev/null
        ;;
    restart)
        $0 stop
        $0 start
        ;;
esac
EOF

# Make services executable
chmod +x etc/init.d/halt
chmod +x etc/init.d/reboot
chmod +x etc/init.d/mountall
chmod +x etc/init.d/network
chmod +x etc/init.d/syslog
chmod +x etc/init.d/crond

# ============================================
# 9. Create runlevel symlinks
# ============================================
ln -sf ../init.d/halt etc/rc.d/rc0.d/S00halt
ln -sf ../init.d/reboot etc/rc.d/rc6.d/S00reboot
ln -sf ../init.d/mountall etc/rc.d/rcS.d/S10mountall
ln -sf ../init.d/network etc/rc.d/rc3.d/S20network
ln -sf ../init.d/network etc/rc.d/rc0.d/K80network
ln -sf ../init.d/mountall etc/rc.d/rc0.d/K90mountall
ln -sf ../init.d/syslog etc/rc.d/rc3.d/S30syslog
ln -sf ../init.d/syslog etc/rc.d/rc0.d/K70syslog
ln -sf ../init.d/crond etc/rc.d/rc3.d/S40crond
ln -sf ../init.d/crond etc/rc.d/rc0.d/K60crond

# ============================================
# 10. Additional system configuration
# ============================================

# Mount table symlink
ln -sf /proc/mounts etc/mtab

# Network services
tee etc/services > /dev/null << 'EOF'
ssh         22/tcp
smtp        25/tcp
domain      53/tcp
domain      53/udp
http        80/tcp
https       443/tcp
EOF

# Network protocols
tee etc/protocols > /dev/null << 'EOF'
ip      0       IP
icmp    1       ICMP
tcp     6       TCP
udp     17      UDP
EOF

# Valid shells
tee etc/shells > /dev/null << 'EOF'
/bin/sh
/bin/ash
EOF

# Name service switch configuration
tee etc/nsswitch.conf > /dev/null << 'EOF'
passwd:      files
group:       files
shadow:      files
hosts:       files dns
networks:    files
protocols:   files
services:    files
EOF

# DHCP server configuration
tee etc/udhcpd.conf > /dev/null << 'EOF'
start 192.168.1.100
end 192.168.1.200
interface eth0
option subnet 255.255.255.0
option router 192.168.1.1
option dns 8.8.8.8 8.8.4.4
option lease 864000
EOF

# DNS resolver configuration
tee etc/resolv.conf > /dev/null << 'EOF'
nameserver 8.8.8.8
nameserver 1.1.1.1
nameserver 77.88.8.8
search localdomain
EOF

# Create log files
mkdir -p var/log
touch var/log/messages
touch var/log/syslog
chmod 644 var/log/messages var/log/syslog

# Set root ownership
sudo chown -R root:root .

# ============================================
# 11. Create initramfs
# ============================================
echo "[INFO] Creating initramfs..."
find . -print0 | cpio --null -ov --format=newc | gzip -9 > ../ramfs.cpio.gz
cd ..

# ============================================
# 12. Create bootable ISO
# ============================================
echo "[INFO] Creating bootable ISO..."

mkdir -p iso/boot/grub

# Copy kernel and initramfs
cp bzImage iso/boot/vmlinuz
cp ramfs.cpio.gz iso/boot/initrd.img

# Create GRUB configuration
cat > iso/boot/grub/grub.cfg << 'EOF'
set timeout=5
set default=0
menuentry "Linux + BusyBox + SysV" {
    linux /boot/vmlinuz console=tty0 console=ttyS0
    initrd /boot/initrd.img
}
EOF

# Create ISO image
grub-mkrescue -o boot.iso iso/

# Clean up ISO directory
rm -rf iso

echo "=========================================="
echo "Build completed successfully!"
echo "=========================================="
echo "Generated files:"
echo "  - bzImage: Linux kernel"
echo "  - ramfs.cpio.gz: Initramfs filesystem"
echo "  - boot.iso: Bootable ISO image"
echo ""
echo "To run the system:"
echo "  1. Direct kernel boot:"
echo "     qemu-system-x86_64 -kernel bzImage -initrd ramfs.cpio.gz -append \"console=ttyS0\" -nographic -m 512M -netdev user,id=net0 -device e1000,netdev=net0"
echo ""
echo "  2. Boot from ISO:"
echo "     qemu-system-x86_64 -cdrom boot.iso -m 512M -netdev user,id=net0 -device e1000,netdev=net0 -nographic"
echo "=========================================="