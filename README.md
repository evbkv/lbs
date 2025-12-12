# Minimal Linux + BusyBox + SysV System

A minimal, custom-built Linux operating system designed for educational purposes and lightweight deployment. This project demonstrates how to build a functional Linux system from scratch using the Linux kernel, BusyBox utilities, and System V init.

## Project Goals

* **Educational:** Understand the fundamentals of operating systems, Unix utilities, shell scripting, and networking
* **Minimal:** Create the smallest possible functional Linux system
* **Extensible:** Serve as a base for custom distributions, microservers, or embedded systems
* **Practical:** Learn system building, configuration, and deployment

## Features

* **Minimal Linux Kernel** (~2MB) with essential drivers
* **BusyBox** (statically linked) providing Unix utilities in a single binary
* **System V init** for traditional service management
* **Network stack** with Ethernet support (e1000 driver for virtualization)
* **Basic filesystem** with standard Unix directory hierarchy
* **Virtualization-ready** for QEMU and VirtualBox
* **Small footprint** (~15MB total) suitable for low-power hardware

## Use Cases

* **Learning OS internals** and Unix fundamentals
* **Embedded system development** base
* **Microservers** for lightweight services
* **Network testing** and debugging environment
* **Container base images** (minimal rootfs)
* **Custom distribution development**

## System Requirements

### Host System (for building)

* Ubuntu/Debian or compatible Linux distribution
* 2GB+ RAM, 10GB+ free disk space
* Internet connection for downloading source code

### Target System (for running)

* x86_64 architecture (can be adapted for ARM)
* 64MB+ RAM (512MB recommended)
* Virtualization support (QEMU, VirtualBox, KVM)

## Project Structure

```
lbs/
├── build-minimal-os.sh  # Main build script
├── README.md            # This file
├── bzImage              # Compiled kernel (after build)
├── ramfs.cpio.gz        # Initramfs filesystem (after build)
└── boot.iso             # Bootable ISO image (after build)
```

## Quick Start

### 1. Preparation

Install required dependencies on Ubuntu/Debian:

```bash
sudo apt update
sudo apt install build-essential libncurses-dev flex bison pkg-config bc kmod \
                 python3 fakeroot git zip unzip curl wget device-tree-compiler \
                 cpio qemu-system-x86 libelf-dev elfutils libssl-dev grub-pc-bin \
                 xorriso
```

For other distributions, install equivalent packages.

### 2. Building the System

Clone the repository and run the build script:

```bash
# Clone the project
git clone https://github.com/evbkv/lbs.git
cd lbs

# Make the script executable
chmod +x build-minimal-os.sh

# Run the build (takes 10-30 minutes depending on hardware)
./build-minimal-os.sh
```

The script will:

1. Download Linux kernel and BusyBox source code
2. Configure and compile a minimal Linux kernel
3. Build a static BusyBox binary
4. Create a complete filesystem hierarchy
5. Generate configuration files for System V init
6. Package everything into an initramfs
7. Create a bootable ISO image

### 3. Output Files

After successful build, you'll have:

* bzImage - Compiled Linux kernel (~2MB)
* ramfs.cpio.gz - Complete root filesystem (~13MB)
* boot.iso - Bootable ISO image (~15MB)

## Running the System

### Option 1: QEMU (Recommended for Development)

Direct kernel boot (fastest):

```bash
qemu-system-x86_64 -kernel bzImage -initrd ramfs.cpio.gz \
  -append "console=ttyS0" -nographic -m 512M \
  -netdev user,id=net0 -device e1000,netdev=net0
```

Boot from ISO:

```bash
qemu-system-x86_64 -cdrom boot.iso -m 512M -nographic \
  -netdev user,id=net0 -device e1000,netdev=net0
```

With display and networking:

```bash
qemu-system-x86_64 -cdrom boot.iso -m 512M -enable-kvm \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -device e1000,netdev=net0
```

### Option 2: VirtualBox

1. Open VirtualBox and click "New"
2. Set:
	* Name: Minimal Linux
	* Type: Linux
	* Version: Other Linux (64-bit)
3. Memory: 512 MB
4. Hard disk: Do not add a virtual hard disk
5. Click "Create"
6. Select the VM and click "Settings"
7. Go to "Storage" → "Empty" under Controller:IDE
8. Click the disk icon → "Choose a disk file"
9. Select boot.iso from your project directory
10. Go to "Network" → Adapter 1 → "Enable Network Adapter"
11. Set "Attached to:" to "NAT"
12. Click "OK" and start the VM

### Option 3: Real Hardware

1. Burn boot.iso to a USB drive:
```bash
sudo dd if=boot.iso of=/dev/sdX bs=4M status=progress
```
2. Boot from USB on target hardware
3. For permanent installation, copy files to a hard drive partition

## System Details

### Default Credentials

* Username: root
* Password: (none, press Enter)

### Network Configuration

* IP address: 10.0.2.15/24 (QEMU default)
* Gateway: 10.0.2.2
* DNS: Google DNS (8.8.8.8, 8.8.4.4)

### Available Services

* SSH server (port 22)
* DHCP client/server
* Cron scheduler
* Syslog daemon
* Network utilities (ping, ifconfig, route, etc.)

### Shell Environment

* Default shell: ash (BusyBox shell)
* Prompt: user@host:path$
* PATH: /bin:/sbin:/usr/bin:/usr/sbin

## Customization

### Adding Packages

1. Edit build-minimal-os.sh
2. Add package compilation in the BusyBox section
3. Update init scripts as needed

### Kernel Configuration

Modify kernel options in the script:

```bash
# Enable/disable specific features
./scripts/config --enable CONFIG_FEATURE_NAME
./scripts/config --disable CONFIG_UNNEEDED
```

### Filesystem Expansion

Add files to the fs/ directory before the find ... | cpio command.

### Service Management

Services are managed via System V init:

```bash
# List services
ls /etc/init.d/

# Start/stop services
/etc/init.d/service_name start
/etc/init.d/service_name stop
```

## Learning Resources

### What This Project Teaches

1. Kernel configuration and compilation
2. Init systems (System V)
3. Filesystem hierarchy (FHS)
4. Shell scripting and automation
5. Network configuration
6. Service management
7. Boot process (GRUB, initramfs)

### Next Steps for Learning

1. Add a package manager (like opkg)
2. Implement a simple web server
3. Add user management
4. Create custom kernel modules
5. Build for different architectures (ARM, RISC-V)
6. Add disk encryption
7. Implement container support

## Troubleshooting

### Build Issues

* "Command not found": Install missing dependencies
* Out of disk space: Clean up with make clean in linux/ and busybox/
* Kernel compile errors: Check kernel configuration options

### Runtime Issues

* No network: Check QEMU/VirtualBox network settings
* Black screen: Use -nographic flag in QEMU
* Slow boot: Reduce kernel features or use KVM acceleration

## QEMU Network Tips

```bash
# Test network connectivity
ping 8.8.8.8

# View network configuration
ip addr show
ip route show

# Manual configuration if needed
ip addr add 192.168.1.100/24 dev eth0
ip route add default via 192.168.1.1
```

## Author

[Evgenii Bykov](https://github.com/evbkv)

## License

GNU General Public License v3.0

This project uses components with their own licenses:

* Linux Kernel: GPL v2
* BusyBox: GPL v2

See individual component licenses for details.

