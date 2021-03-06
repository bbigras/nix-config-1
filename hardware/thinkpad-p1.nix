{ pkgs, ... }: {
  imports = [
    ./bluetooth.nix
    ./efi.nix
    ./intel.nix
    ./nouveau.nix
    ./sound.nix
  ];

  boot = rec {
    extraModulePackages = with kernelPackages; [ ddcci-driver ];
    initrd.availableKernelModules = [ "xhci_pci" "nvme" "usb_storage" "usbhid" "sd_mod" ];
    kernel.sysctl = { "vm.swappiness" = 1; };
    kernelModules = [ "kvm-intel" "i2c_dev" "ddcci-backlight" "tcp_bbr" ];
    kernelPackages = pkgs.linuxPackages_latest;
    # kernelParams = [ "psmouse.synaptics_intertouch=1" ];
  };

  console = {
    font = "ter-v28n";
    keyMap = "us";
    packages = with pkgs; [ terminus_font ];
  };

  environment.systemPackages = with pkgs; [ powertop ];

  hardware = {
    brillo.enable = true;
    enableRedistributableFirmware = true;
    enableAllFirmware = true;
  };

  nix = {
    maxJobs = 12;
    systemFeatures = [ "benchmark" "nixos-test" "big-parallel" "kvm" "gccarch-skylake" ];
  };

  nixpkgs.localSystem.system = "x86_64-linux";

  services = {
    fstrim.enable = true;
    fwupd.enable = true;
    hardware.bolt.enable = true;
    tlp = {
      enable = true;
      settings = {
        CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
        CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
        CPU_MAX_PERF_ON_AC = 100;
        CPU_MAX_PERF_ON_BAT = 50;
        CPU_SCALING_GOVERNOR_ON_AC = "performance";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

        DEVICES_TO_DISABLE_ON_BAT_NOT_IN_USE = "bluetooth wifi";
        DEVICES_TO_ENABLE_ON_AC = "bluetooth wifi";

        DISK_APM_LEVEL_ON_AC = "255 254";
        DISK_APM_LEVEL_ON_BAT = "128 1";
        DISK_DEVICES = "nvme0n1 sda";
        DISK_IOSCHED = "none bfq";

        MAX_LOST_WORK_SECS_ON_AC = 15;
        MAX_LOST_WORK_SECS_ON_BAT = 15;

        RUNTIME_PM_ON_AC = "auto";
        RUNTIME_PM_ON_BAT = "auto";
        RUNTIME_PM_DRIVER_BLACKLIST = "nvidia";

        SOUND_POWER_SAVE_ON_AC = "1";
        SOUND_POWER_SAVE_ON_BAT = "1";
        SOUND_POWER_SAVE_CONTROLLER = "Y";

        #                sd-card   yubikey   wacom
        USB_WHITELIST = "0bda:0328 1050:0407 056a:5193";
      };
    };

    # block my dumb sd-card reader that chugs power from coming on
    # udev.extraRules = ''
    #   SUBSYSTEM=="usb", ATTRS{idVendor}=="0bda", ATTRS{idProduct}=="0328", ATTR{authorized}="0"
    # '';
    xserver.dpi = 96;
  };

  sound.extraConfig = ''
    options snd-hda-intel model=generic
  '';
}
