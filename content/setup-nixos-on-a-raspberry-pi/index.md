+++
title = "How to Setup NixOS on a Raspberry Pi"
date = 2021-05-24T18:46:00+01:00
description = "Install NixOS on your Raspberry Pi and manage its packages and services in a declarative format which allows for creating reliable and reproducible setups."

[taxonomies]
tags = ["Post", "Hardware"]

[extra]
author = "***REMOVED***"
+++

This article will walk through the steps of installing NixOS 20.09 on a Raspberry Pi Model 3 B+. At the time of this writing (May 2021) NixOS officially supports running on said board using the `aarch64-linux` build. Many more boards are provided with community support though.

## What is NixOS?

NixOS is built on top of the [Nix](https://nixos.org) _purely functional package manager_. The underlying package manager of this operating system allows to create multiple versions of the **entire system** next to, and completely independent from, each other. For example, you could install multiple versions of the Linux kernel and switch back and forth between them. If something goes south, just rollback. And this is true for anything built by Nix on the system.

It builds the entire dependency tree of each package, so you can run tools that require different versions of the same shared libabry right next to each other without fear. And if you want to uninstall something, don't worry about all the garbage, Nix takes care of collecting it for you.

You get to configure this system with a simple configuration file written in a functional scripting language, which is also called Nix.

There is much more to be discovered both about Nix and NixOS. I am really excited to dig deeper. Let's get started in the homelab and provision a single board computer.

## Bill of Materials

- Raspberry Pi Model 3 B+
- Suitable power supply (this is **important** to avoid weirdness)
- Micro SD Card, min 8GB
- Ethernet cable
- Keyboard
- HDMI cacble
- Monitor

_I did not find a headless installation guide, so the monitor and keyboard will only be required once to set a password for the `nixos` and/or `root` user. The system comes with an ssh daemon running to login remotely after setting the password._

## Download NixOS And Flash Your SD Card

Open the [NixOS on ARM](https://nixos.wiki/wiki/NixOS_on_ARM) documentation in your browser and find the section [Getting the installer](https://nixos.wiki/wiki/NixOS_on_ARM#Getting_the_installer). I chose `20.09 (LTS)` at this time, however you might encounter a newer version when reading this.

Clicking the release of choice will take you to the NixOS build system; click on the latest build and download the `sd-image` build product.

I aquired an `sd-image` named `nixos-sd-image-20.09.4172.7cbe8443688-aarch64-linux.img.zst`. The `.zst` extension indicates that this image is compressed and we'll have to decompress it in order to write it to an SD card using `dd`.

_Aside: install `nix` on your host system and run `nix-shell -p zstd --run "unzstd <img-name>.img.zstm"` to get a peek of what you can use the Nix package manager in your daily environment for.__

I'll decompress the image by running:

```shell
unzstd nixos-sd-image-20.09.4172.7cbe8443688-aarch64-linux.img.zst
```

To flash the image to the SD card, discover the device using `lsblk -p`, it'll be `/dev/sdb` for me.

Then flash the decrompressed image to the card using `dd`:

```shell
sudo dd if=nixos-sd-image-20.09.4172.7cbe8443688-aarch64-linux.img of=/dev/sdb status=progress bs=4M conv=fsync
```

This will take several minutes to complete, but `dd` will keep you posted in the terminal.

## Installing NixOS

With your SD card ready, connect all the appliances, power on your monitor, insert the card and provide power to the board.

The board will take a moment to boot and will bring you into a pre-logged-in shell as `nixos` user.

For this article, we'll be dealing with the `root` user, so switch using `sudo -i` and set a password with `passwd`.

Last but not least, run `ifconfig` to determine the IP address of your board.

Now you can login via SSH from another machine to continue the setup remotely; monitor and keyboard can be stashed away again.

> If you know a way to achieve this setup headlessly, please leave a commnt.

## Initial Configuration

Login to your system `ssh root@<ip>`

```shell
vim /etc/nixos/configuration.nix
```

Here is the minimal configuration to apply:

```nix
{ config, pkgs, lib, ... }:
{
  # NixOS wants to enable GRUB by default
  boot.loader.grub.enable = false;

  # Enables the generation of /boot/extlinux/extlinux.conf
  boot.loader.generic-extlinux-compatible.enable = true;

  # Installs Linux 5.4 kernel (May 2021) where latest would go for 5.11 and not boot anymore
  boot.kernelPackages = pkgs.linuxPackages_5_4;

  # File systems configuration for using the installer's partition layout
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
    };
  };

  # Adding a swap file is optional, but strongly recommended
  swapDevices = [ { device = "/swapfile"; size = 1024; } ];

  # set a hostname
  networking.hostName = "cartman"

  # ssh access
  services.openssh.enable = true;

  users.users.root.openssh.authorizedKeys.keys = [
    "your public key here"
  ];

  # packages can be searched at https://search.nixos.org/packages
  environment.systemPackages = [
    pkgs.vim
  ];
}
```

Replace the value of `networking.hostname` with a value of your liking and make sure to add your SSH public key in the `ssh access` section.

Before making this configuration permanent, test it:

```shell
nixos-rebuild test
```

If everything seems to be in order, make the configuration permanent:

> How do you determine if everything is in order? Try `which vim`, `cat /etc/hostname` and try to connect an additional SSH session as `root` user and mind that you'll be using key-based authentication now (do not terminate your open session, yet)

```shell
nixos-rebuild switch
```

If you would want to rollback, you might have bricked the setup, the bootloader will offer the previous configurations to boot into.

_See: [Changing the configuration](https://nixos.org/manual/nixos/stable/#sec-changing-config)_

That is it. A very simple, but entirely reproducible, system built using NixOS. Now you can go ahead and play with it. How about installing [Nginx](https://nixos.wiki/wiki/Nginx)?

## Conclusion

NixOS is readily available on the Raspberry Pi. The project offers official support for the Pi 3, however the community provides access to an impressive [list of single board computers](https://nixos.wiki/wiki/NixOS_on_ARM#Community_supported_devices) to install NixOS onto.

I am very pleased with how easy this process was and am excited to start tinkering with this in the homelab.

---

## Updates

- `2021-07-03` I published [How to Update NixOS](@/update-nixos/index.md) and found out that it broke the setup on Raspberry Pi, if the kernel is not pinned to 5.4; I updated the above `/etc/nixos/configuration.nix` to reflect the change for kernel pinning

