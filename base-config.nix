{ config, pkgs, lib, ... }:

{
  nixpkgs.overlays = [
    (self: super: {
      makeModulesClosure = x: super.makeModulesClosure (x // { allowMissing = true; });
    })
  ];
  documentation.enable = false;
  networking.firewall.allowedTCPPorts = [ 9100 9102 ];
  environment.systemPackages = with pkgs; [
    usbutils
    dtc
    screen
  ];
  services = {
    openssh = {
      enable = true;
      permitRootLogin = "yes";
    };
    udisks2.enable = false;
    xserver.enable = false;
  };
  security.polkit.enable = false;
  boot = {
    consoleLogLevel = 7;
    kernelPackages = builtins.getAttr "linuxPackages_rpi${toString config.boot.loader.raspberryPi.version}" pkgs;
    kernelParams = [ "boot.shell_on_fail" "console=tty1" "console=serial0,115200" "console=ttyAMA0,115200" "earlyprintk" "root=/dev/mmcblk0p2" "rootdelay=10" ];
    loader.grub.enable = false;
    supportedFilesystems = lib.mkForce [];
  };
}
