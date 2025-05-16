#!/bin/bash
#a7la samlam 3la elmostakhdem
cat ascii.txt
echo "welcome to obsidian os"
echo "this installer script will ask you few questions"

#check for root
if [[ $((EUID)) -ne 0 ]] 
then 
	echo "please run this script using "sudo obsidian_installer""
	exit

fi

#partitioning
echo "do you like to set your partitions manually or automatically?"
read -p "choose 0 for manual partitioning ,and 1 for automatic partition: " part_mode

if [[ $part_mode -eq 0 ]]
then
 
	echo $(lsblk -d -e 7,11 -o NAME,SIZE,TYPE | awk '$3=="disk" {print $1}')
	echo $(lsblk -d -e 7,11 -o NAME,SIZE,TYPE | awk '$3=="disk" {print $2}')
        echo "/dev/sda or /dev/sdb means hdd or sata ssd or usb_drive"
        echo "/dev/nvme means nvme ssd"
	read -p "please choose the drive to work with:" choosen_disk
sudo cfdisk /dev/$choosen_disk

elif [[ $part_mode -eq 1 ]]
then

        echo $(lsblk -d -e 7,11 -o NAME,SIZE,TYPE | awk '$3=="disk" {print $1}')
        echo $(lsblk -d -e 7,11 -o NAME,SIZE,TYPE | awk '$3=="disk" {print $2}')
        read -p "choose the device to install on : " choosen_disk 
        choosen_disk_auto=/dev/$choosen_disk
        echo $choosen_disk

else
echo "wrong option"

fi

#check for boot mode if bios or UEFI
if [[ -d /sys/firmware/efi ]] 
then
echo "system is uefi"
boot_mode = "uefi"

else
echo "system is bios-mode"
boot_mode = "bios"

fi

#partioning for automatic mode
if [[ $part_mode -eq 1 ]] && [[ $boot_mode == "bios" ]]
then 
parted $choosen_disk --script mklabel msdos
parted $choosen_disk --script mkpart primary ext4 1MiB 100%
mkfs.ext4 $choosen_disk
mount $choosen_disk /mnt

elif [[ $boot_mode == "uefi" ]]
then
	parted --script $choosen_disk mkpart ESP fat32 1MiB 513MiB
        parted --script $choosen_disk set 1 esp on
        parted --script $choosen_disk mkpart primary ext4 513MiB 100%
	#formating efi partition
	mkfs.fat -F32 "$choosen_disk"1 
        #formating root partition
	mkfs.ext4 "$choosen_disk"2
	mount "$choosen_disk"2 /mnt
	mount --mkdir "$choosen_disk"1 /mnt/boot


fi

#partioting for offline installer
if [[ $part_mode -eq 0 ]] && [[ $boot_mode == "uefi" ]]
efi_found=false

parted -m "choosen_disk" print | while IFS=: read -r num start end size fs type flags; do
    if [[ "$fs" == "fat32" && "$flags" == "boot" ]]; then
        efi_found=true
        break
    fi
done

if ! $efi_found
then
	echo "please create or flag the boot partition"
	exit 1
fi

lsblk

read -p "what partition did you used for boot?? ,pls type its name" boot_part
read -p "what partition did you used for root?? ,pls type its name" root_part

mount $root_part /mnt/
mount --mkdir  $boot_part /mnt/boot/

elif [[ $boot_mode == "bios" ]]
then
	lsblk
	read -p "what partition did you use for root" root_part
	mkfs.ext4 $root_part
	mount $root_part /mnt

fi

#finally i have finished the partitioning

#copying the root files

rsync -aAXv / --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found"} /mnt

genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt 'chmod +x /usr/local/bin/*'
arch-chroot /mnt '/usr/local/bin/after_chroot.sh'





