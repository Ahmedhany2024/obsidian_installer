#!/bin/bash
set -e

# a7la salām 3ala elmostakhdem
cat ascii.txt
echo "Welcome to Obsidian OS"
echo "This installer script will ask you a few questions"

# Check for root
if [[ $EUID -ne 0 ]]; then
    echo "Please run this script using: sudo ./obsidian_installer.sh"
    exit 1
fi

# Partitioning choice
echo "Do you want to set your partitions manually or automatically?"
read -p "Choose 0 for manual partitioning, and 1 for automatic partitioning: " part_mode

# List available disks
echo "Available Disks:"
lsblk -d -e 7,11 -o NAME,SIZE,TYPE

read -p "Please choose the drive to install on (e.g. sda or nvme0n1): " choosen_disk
disk_path="/dev/$choosen_disk"

# Boot mode detection
if [[ -d /sys/firmware/efi ]]; then
    echo "System is UEFI"
    boot_mode="uefi"
else
    echo "System is BIOS-mode"
    boot_mode="bios"
fi

if [[ $part_mode -eq 0 ]]; then
    # Manual partitioning
    cfdisk "$disk_path"

    if [[ $boot_mode == "uefi" ]]; then
        efi_found=false
        parted -m "$disk_path" print | while IFS=: read -r num start end size fs type flags; do
            if [[ "$fs" == "fat32" && "$flags" == *"boot"* ]]; then
                efi_found=true
                break
            fi
        done

        if ! $efi_found; then
            echo "Please create and flag an EFI partition"
            exit 1
        fi

        lsblk
        read -p "Enter the EFI partition (e.g., sda1): " boot_part
        read -p "Enter the root partition (e.g., sda2): " root_part
        mount "/dev/$root_part" /mnt
        mount --mkdir "/dev/$boot_part" /mnt/boot

    else
        lsblk
        read -p "Enter the root partition (e.g., sda1): " root_part
        mkfs.ext4 "/dev/$root_part"
        mount "/dev/$root_part" /mnt
    fi

elif [[ $part_mode -eq 1 ]]; then
    echo "Automatic partitioning on $disk_path"

    if [[ $boot_mode == "bios" ]]; then
        parted "$disk_path" --script mklabel msdos
        parted "$disk_path" --script mkpart primary ext4 1MiB 100%
        mkfs.ext4 "${disk_path}1"
        mount "${disk_path}1" /mnt

    elif [[ $boot_mode == "uefi" ]]; then
        parted "$disk_path" --script mklabel gpt
        parted "$disk_path" --script mkpart ESP fat32 1MiB 513MiB
        parted "$disk_path" --script set 1 esp on
        parted "$disk_path" --script mkpart primary ext4 513MiB 100%

        boot_part="${disk_path}p1"
        root_part="${disk_path}p2"
        [[ "$disk_path" =~ sd ]] && boot_part="${disk_path}1" && root_part="${disk_path}2"

        mkfs.fat -F32 "$boot_part"
        mkfs.ext4 "$root_part"
        mount "$root_part" /mnt
        mount --mkdir "$boot_part" /mnt/boot
    fi

else
    echo "Invalid partitioning option."
    exit 1
fi

# Base file copy
echo "Copying system files..."
rsync -aAXv / --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found"} /mnt

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Timezone setup
echo "Available time zones are in /usr/share/zoneinfo"
read -p "Enter your time zone (e.g., Africa/Cairo): " zone

if [[ -f "/usr/share/zoneinfo/$zone" ]]; then
    ln -sf "/usr/share/zoneinfo/$zone" "/mnt/etc/localtime"
else
    echo "Invalid timezone path. Please double-check and try again."
    ls /usr/share/zoneinfo
    exit 1
fi

# Hostname and locale
read -p "Enter your desired hostname: " hostname
echo "$hostname" > /mnt/etc/hostname

cat <<EOF > /mnt/etc/locale.gen
en_US.UTF-8 UTF-8
EOF

cat <<EOF > /mnt/etc/locale.conf
LANG=en_US.UTF-8
EOF

# Prepare user in chroot
read -p "Enter your new username: " username

arch-chroot /mnt /bin/bash <<EOF
locale-gen
ln -sf "/usr/share/zoneinfo/$zone" /etc/localtime
hwclock --systohc
useradd -m -G wheel -s /bin/bash "$username"
echo "Set the password for user and root now:"
passwd
passwd $username
mkinitcpio -P

if [[ "$boot_mode" == "uefi" ]]; then
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=obsidian
else
    grub-install --target=i386-pc "$disk_path"
fi

grub-mkconfig -o /boot/grub/grub.cfg
EOF

# Finalizing
umount -R /mnt
echo "Installation complete."
echo "You can now reboot the system using: reboot"



