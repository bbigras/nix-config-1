{ pkgs, ... }: {
  imports = [
    ./nixos-aarch64-builder.nix
    ./bluetooth.nix
  ];

  boot = {
    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };
    kernelPackages = pkgs.linuxPackages_rpi4;
  };

  console.keyMap = "us";

  fileSystems = {
    "/boot/firmware" = {
      device = "/dev/disk/by-label/FIRMWARE";
      fsType = "vfat";
    };
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
    };
  };

  hardware = {
    enableAllFirmware = true;
    opengl = {
      setLdLibraryPath = true;
      package = pkgs.mesa_drivers;
    };
    deviceTree.enable = true;
  };

  nix.maxJobs = 4;

  nixpkgs.localSystem.system = "aarch64-linux";

  services = {
    fstrim.enable = true;
    xserver.videoDrivers = [ "modesetting" ];
  };

  swapDevices = [
    {
      device = "/swap";
      size = 2048;
    }
  ];
}
