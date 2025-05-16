#!/bin/bash

#setting time zone
echo "available time zones can be found in /usr/share/zoneinfo"
read -p "enter your time zone ,for example (Cairo): " zone

if [ -f "/mnt/usr/share/zoneinfo/$zone" ]
then
    ln -sf "/usr/share/zoneinfo/$zone" /etc/localtime
    hwclock --systohc
    echo "Timezone set to $zone"
  else
    echo "Invalid time zone: "
    ls /usr/share/zoneinfo
    read -p "please search for your timezone and type it correctly" zone
    ln -sf "/usr/share/zoneinfo/$zone" /etc/localtime
    hwclock --systohc
    echo "Timezone set to $zone"
fi
#generating locales
echo "generating locales..."
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

#host-name

read -p "please enter the hostname(what whould you like to name this pc" hostname

echo $hostname >> /etc/hostname


#add user

read -p "enter your name" username

useradd -m -G wheel -s /bin/bash $username

#mkinitcpio
mkinitcpio -P

if [[ $boot_mode == "uefi" ]]
then
        grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=obsidian

elif [[ $boot_mode == "bios" ]]
then
        grub-install --target=i386-pc $choosen_disk
else
        echo "bootloader installation failed"
        exit 1
fi

grub-mkconfig -o /boot/grub/grub.cfg

umount -R /mnt

echo "installation complete.."

echo "please set your user and root password before rebooting"

echo "(passwd root),for changing root password"

echo "(passwd $user_name),for changing user password"

echo "after setting your passwords, you can reboot by typing (reboot) in your terminal"

exit


