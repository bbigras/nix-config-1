{ pkgs, ... }: {
  services.xserver = {
    enable = true;
    desktopManager = {
      default = "none";
      xterm.enable = false;
    };
    windowManager.i3 = {
      enable = true;
      package = pkgs.i3-gaps;
      extraPackages = with pkgs; [
        alacritty
        scrot
        libinput-gestures
        light
        dunst
        feh
        i3lock
        i3status-rust
        xclip
        xsel
      ];
    };

    xautolock.locker =
      "${pkgs.i3lock}/bin/i3lock -i ~/pictures/walls/clouds.png -e -f";
  };
}
