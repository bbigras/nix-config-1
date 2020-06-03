{ lib, pkgs, ... }: {
  imports = [
    (import ../users).bemeurer
    ../core

    ../dev
    ../dev/stcg-gcs.nix
    ../dev/stcg-cameras.nix
    ../dev/stcg-aarch64-builder.nix
    ../dev/qemu.nix
    ../dev/virt-manager.nix

    ../hardware/thinkpad-p1.nix

    ../sway
  ];

  boot.initrd.luks.devices.nixos = {
    allowDiscards = true;
    device = "/dev/disk/by-uuid/2d6ff3d0-cdfd-4b6e-a689-c43d21627279";
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/4e217a4b-40ae-4bde-b771-04eabfe2369d";
      fsType = "xfs";
      options = [ "defaults" "noatime" ];
    };
    "/boot" = {
      device = "/dev/disk/by-uuid/AD39-03D0";
      fsType = "vfat";
    };
  };

  hardware.u2f.enable = true;
  hardware.logitech.enable = true;

  networking = {
    hostName = "foucault";
    interfaces.enp0s31f6 = {
      useDHCP = true;
      mtu = 9000;
    };
    wireless.iwd.enable = true;
  };

  services.keybase.enable = false;

  swapDevices = [{
    device = "/dev/disk/by-uuid/ec8c101f-65fd-47c4-8e17-f1b5395b68c7";
  }];

  time.timeZone = "America/Los_Angeles";

  users.users.bemeurer.extraGroups = [ "kvm" "libvirtd" ];
}
