#!/bin/sh

# Vars
# Do NOT change these, as they affect the update engine!
Revision="7"
VersionName="PwnedCast-13300-V1-R$Revision"

# Prefixed log messages are easier to distinguish
pLog() {
	log "$VersionName: $1"
}

# We now debug every step of the process so it's easier to debug problems
pLog "Imager.sh now running"

# Are we on the proper flashcast ver? Do a version check
if ! test -f "/etc/flasher-version" ; then
	fatal "$VersionName: Installation Cancelled, Please Update to Flashcast Version 1.1 or Later."
fi

# First we flash the kernel
pLog "Flashing Kernel..."
flash_mtd_partition 'kernel' ./images/boot.img

# Next we flash recovery
pLog "Flashing Recovery..."
flash_mtd_partition 'recovery' ./images/recovery.img

# Then we flash the system
pLog "Flashing System..."
flash_mtd_partition 'rootfs' ./images/system.img

# Before we start, delete the system and boot image
# so we have enough space to keep working
pLog "Deleting boot.img and system.img to free up space in /tmp so we can mount SquashFS"
rm ./images/{boot.img,system.img}

# Start file modification.
pLog "Mounting System Partition"
ROOTFS="$(begin_squashfs_edit 'rootfs')"

# Set build revision
pLog "Setting Build Revision"
echo "$Revision" > "${ROOTFS}/chrome/pwnedcast_ver"

# Replace boot animation
pLog "Replacing Boot Animation"
mv ./misc/boot-animation/* "${ROOTFS}/res/images/"

# Put in our own recovery
pLog "Replacing Recovery File in System Image"
rm "${ROOTFS}/boot/recovery.img"
mv ./images/recovery.img "${ROOTFS}/boot/"

# No updating for you, also setup custom OTA system
pLog "Disabling OTA Updates & Enabling PwnedCast OTA Updates"
rm "${ROOTFS}/chrome/update_engine"
mv ./bin/{update_engine,pwnedcast-update.sh} "${ROOTFS}/chrome/"

# Is a mod set to disable updates?
if has_mod_option 'DisablePwnedCastOTA' ; then
	pLog "Disabling PwnedCast OTA Updates per User Request"
	touch "${ROOTFS}/chrome/disable_ota"
fi

# Change Hard Coded DNS Servers
pLog "Modifying Chromecast to use DHCP DNS Servers"
rm "${ROOTFS}/etc/dhcpcd/dhcpcd-hooks/20-dns.conf"
mv ./misc/20-dns.conf "${ROOTFS}/etc/dhcpcd/dhcpcd-hooks/"

# Upload binaries
pLog "Adding BusyBox Tools, ADB, and SSH"
mv ./bin/{busybox,adbd,dropbear} "${ROOTFS}/bin/"

# Enable Telnet + ADB
pLog "Enabling Services at Startup"
mv "${ROOTFS}/bin/clear_crash_counter" "${ROOTFS}/bin/clear_crash_counter-orig"
mv ./bin/clear_crash_counter "${ROOTFS}/bin/"

# Mounting /data
pLog "Mounting UserData Partition"
DATA="$(mount_mtd_partition userdata)"

# Make folder for the keys, and copy them over
pLog "Copying Unique SSH Keys to System"
mkdir "${ROOTFS}/usr/share/sshkeys"
cp "${DATA}/flashcast/dropbear/"/* "${ROOTFS}/usr/share/sshkeys/"

# Unmount userdata
pLog "Unmounting UserData"
cleanup_mount "$DATA"

# Clean up and write the modified partition back
pLog "Done editing System, Writing Changes..."
end_squashfs_edit "$ROOTFS"

# One final goodbye
pLog "Script Finished!"
