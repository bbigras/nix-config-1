{ lib, ... }: {
  imports = [
    <nixpkgs/nixos/modules/installer/cd-dvd/sd-image-raspberrypi4.nix>
    ../system/combo/core.nix
    ../system/hardware/rpi4.nix
  ];

  networking = {
    hostName = "nixos-rpi-installer";
    wireless.enable = lib.mkForce false; # we enable nm instead
  };

  services.openssh.permitRootLogin = lib.mkForce "yes";
}