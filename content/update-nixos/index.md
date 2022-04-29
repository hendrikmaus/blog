+++
title = "How to Update NixOS"
date = 2021-07-03T00:16:47+00:00
description = "A quick how-to on updating NixOS"

[taxonomies]
tags = ["Post", "Software", "Quick Tip"]

[extra]
author = "Hendrik Maus"
+++

I recently wrote a post called [How to Setup NixOS on a Raspberry Pi](@/setup-nixos-on-a-raspberry-pi/index.md) and haven't touched the system I setup there in a little while. Now I booted it back up and found that there has been a new release of NixOS in the meantime.

So here is a quick how-to on updating NixOS:

- Login as `root` user
- Replace the `nixos` channel with the newer version

  ```shell
  nix-channel --add https://nixos.org/channels/nixos-21.05 nixos
  ```
- Update the channel

  ```shell
  nix-channel --update nixos
  ```
- Rebuild the system

   ```shell
   nixos-rebuild --upgrade switch
   ```
If anything goes wrong, choose the previous version of the system using the bootloader.

