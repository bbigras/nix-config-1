{ lib, pkgs, ... }: {
  imports = [
    ../../core
    ../../core/unbound.nix

    ../../dev

    ../../hardware/efi.nix
    ../../hardware/nouveau.nix
    ../../hardware/sound.nix
    ../../hardware/zfs.nix

    ../../users/bemeurer
  ];

  boot = {
    blacklistedKernelModules = [ "snd_hda_intel" "amd64_edac_mod" "sp5100_tco" "iwlwifi" ];
    initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "sd_mod" ];
    kernelModules = [ "kvm-amd" ];
    kernelPackages = pkgs.linuxPackages_latest;
    kernel.sysctl = {
      "net.core.rmem_default" = 31457280;
      "net.core.wmem_default" = 31457280;
      "net.core.rmem_max" = 2147483647;
      "net.core.wmem_max" = 2147483647;
    };
    zfs = {
      extraPools = [ "tank" ];
      requestEncryptionCredentials = false;
    };
  };

  console = {
    font = "ter-v14n";
    keyMap = "us";
    packages = with pkgs; [ terminus_font ];
  };

  environment.persistence."/nix/state" = {
    directories = [
      "/var/lib/grafana"
      "/var/lib/iwd"
      "/var/lib/nixus-secrets"
      "/var/lib/plex"
      "/var/lib/prometheus2"
      "/var/lib/roon-server"
      "/var/lib/tailscale"
      "/var/log"

      "/home/bemeurer/.cache/zsh"
      "/home/bemeurer/.local/share/bash"
      "/home/bemeurer/.local/share/nvim"
      "/home/bemeurer/.local/share/zsh"
      "/home/bemeurer/.ssh"
      "/home/bemeurer/src"
      "/home/bemeurer/tmp"
    ];
    files = [
      "/etc/machine-id"
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];
  };

  fileSystems = {
    "/" = {
      device = "tmpfs";
      fsType = "tmpfs";
      options = [ "defaults" "noatime" "size=20%" "mode=755" ];
    };
    "/boot" = {
      device = "/dev/disk/by-uuid/E954-11BC";
      fsType = "vfat";
    };
    "/nix" = {
      device = "/dev/disk/by-uuid/b192a21f-08ae-4ce9-ac41-053854fc52c9";
      fsType = "xfs";
      neededForBoot = true;
    };
  };

  hardware = {
    cpu.amd.updateMicrocode = true;
    enableRedistributableFirmware = true;
    pulseaudio.enable = lib.mkForce false;
  };

  home-manager.users.bemeurer.home.persistence."/nix/state/home/bemeurer".files = [
    ".gist"
    ".gist-vim"
    ".newsboat/cache.db"
    ".newsboat/history.search"
  ];

  networking = {
    firewall.allowedTCPPorts = [ 3000 9090 9091 ];
    hostName = "fourier";
    hostId = "80f4ef89";
    # wireless.iwd.enable = true;
    useNetworkd = lib.mkForce false;
    interfaces.eno1.useDHCP = true;
    # interfaces.wlan0.useDHCP = true;
  };

  nix = {
    gc = {
      automatic = true;
      options = "-d";
    };
    maxJobs = 16;
    systemFeatures = [ "benchmark" "nixos-test" "big-parallel" "kvm" ];
  };

  security.pam.loginLimits = [
    { domain = "*"; type = "-"; item = "memlock"; value = "unlimited"; }
    { domain = "*"; type = "-"; item = "nofile"; value = "1048576"; }
    { domain = "*"; type = "-"; item = "nproc"; value = "unlimited"; }
  ];

  services = {
    fstrim.enable = true;
    fwupd.enable = true;
    grafana = {
      enable = true;
      addr = "0.0.0.0";
      extraOptions.DASHBOARDS_MIN_REFRESH_INTERVAL = "1s";
    };
    iperf3 = {
      enable = true;
      openFirewall = true;
    };
    plex = {
      enable = true;
      openFirewall = true;
    };
    prometheus = {
      enable = true;
      extraFlags = [ "--storage.tsdb.retention.time=1y" ];
      scrapeConfigs = [{
        job_name = "node";
        scrape_interval = "2500ms";
        static_configs = [{ targets = [ "127.0.0.1:9091" ]; }];
      }
        {
          job_name = "prometheus";
          scrape_interval = "30s";
          static_configs = [{ targets = [ "127.0.0.1:9090" ]; }];
        }];
      exporters.node = {
        enable = true;
        listenAddress = "127.0.0.1";
        enabledCollectors = [ "systemd" "pressure" ];
        port = 9091;
      };
    };
    roon-server = {
      enable = true;
      group = "media";
      openFirewall = true;
    };
    smartd.enable = true;
    zfs.autoScrub.pools = [ "tank" ];
    zfs.autoSnapshot = {
      enable = true;
      flags = "-k -p --utc";
    };
  };

  sound.extraConfig = ''
    defaults.pcm.!card "Modius";
    defaults.ctl.!card "Modius";
  '';

  system.activationScripts.setIOScheduler = ''
    disks=(sda sdb sdc sdd nvme0n1)
    for disk in "''${disks[@]}"; do
      echo "none" > /sys/block/$disk/queue/scheduler
    done
  '';

  swapDevices = [{ device = "/dev/disk/by-uuid/6075a47d-006a-4dbb-9f86-671955132e2f"; }];

  time.timeZone = "America/Los_Angeles";

  users.groups.media.members = [ "bemeurer" "roon-server" "plex" ];
}
