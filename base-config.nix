{ config, pkgs, lib, ... }:

{
  imports = [
    ./openpi-bootloader.nix
  ];
  nixpkgs.overlays = [
    (self: super: {
      makeModulesClosure = x: super.makeModulesClosure (x // { allowMissing = true; });
    })
    (import ./arm32-overlay.nix) # fixes native arm32 builds on aarch64
  ];
  documentation.enable = false;
  networking.firewall.allowedTCPPorts = [ 9100 9102 ];
  environment.systemPackages = with pkgs; [
    usbutils
    dtc
    screen
    ethtool
    sysstat
    vnstat
    xorg.xeyes xorg.xclock
    scrot
  ];
  services = {
    openssh = {
      enable = true;
      permitRootLogin = "yes";
    };
    udisks2.enable = true;
    xserver.enable = true;
    xserver.videoDrivers = [ "fbdev" ];
    xserver.desktopManager.xterm.enable = true;
    xserver.desktopManager.xfce.enable = true;
  };
  security.polkit.enable = true;
  boot = {
    #consoleLogLevel = 7;
    kernelPackages = builtins.getAttr "linuxPackages_rpi${toString config.boot.loader.raspberryPi.version}" pkgs;
    kernelParams = [
      "boot.shell_on_fail"
      #"console=serial0,115200"
      "earlyprintk"
      "console=ttyAMA0,115200"
      "console=tty1"
      "root=/dev/mmcblk0p2"
      "rootdelay=10"
    ];
    loader.grub.enable = false;
    supportedFilesystems = lib.mkForce [];
  };
}
