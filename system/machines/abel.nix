{ config, lib, pkgs, ... }: {
  imports = [
    <nixpkgs/nixos/modules/installer/scan/not-detected.nix>
    ../combo/core.nix
    ../combo/dev.nix

    ../modules/intel.nix
    ../modules/nvidia.nix
    ../modules/zfs.nix

    ../modules/gdm.nix
    ../modules/openssh.nix
    ../modules/stcg-cachix.nix
    ../modules/stcg-cameras.nix
  ];

  boot = rec {
    initrd.availableKernelModules =
      [ "ahci" "xhci_pci" "ehci_pci" "usbhid" "sd_mod" ];
    kernelModules = [ "kvm-intel" ];
    kernelPackages = pkgs.linuxPackages_latest;
    loader = {
      efi.canTouchEfiVariables = true;
      grub = {
        enable = true;
        efiSupport = true;
        device = "nodev";
      };
    };
    supportedFilesystems = [ "zfs" ];
    tmpOnTmpfs = true;
  };

  console.earlySetup = true;

  fileSystems = {
    "/" = {
      device = "rpool/root/nixos";
      fsType = "zfs";
    };
    "/home" = {
      device = "rpool/home";
      fsType = "zfs";
    };
    "/boot" = {
      device = "/dev/disk/by-uuid/AA99-AC5F";
      fsType = "vfat";
    };
  };

  networking = {
    hostName = "abel";
    hostId = "9fc799ef";
    interfaces = {
      eno1.useDHCP = false;
      enp4s0f0 = {
        useDHCP = true;
        mtu = 9000;
      };
      enp4s0f1.useDHCP = false;
      enp4s0f2.useDHCP = false;
      enp4s0f3.useDHCP = false;
    };
    networkmanager.enable = lib.mkForce false;
    useDHCP = false;
  };

  nix.maxJobs = 12;

  services.xserver.displayManager.gdm.autoLogin = {
    enable = true;
    user = "clock";
  };
  services.xserver.desktopManager.gnome3.enable = true;

  time.timeZone = "America/Los_Angeles";

  users.users = {
    clock = {
      createHome = true;
      isNormalUser = true;
      hashedPassword = "$6$O3fiKzeie2Woy$DsVuPscv2q838lCt.NP9J0bWo0FrxGtHsJtVr5qp/EpbLvnD7B6ixbosWer2pf5YPao1yyf29ICbKTF8PrBe./";
    };
    tushar = {
      createHome = true;
      extraGroups = [ "lxd" ];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINH2jTl/COeeNZ6SXGsT0k/3fa1kgaSxgNGeg20s+OHV tushar@standard.ai"
      ];
      isNormalUser = true;
    };
  };
}
