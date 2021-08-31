{ config, pkgs, ... }:

{
  nixpkgs.overlays = [
    (self: super: {
      makeModulesClosure = x: super.makeModulesClosure (x // { allowMissing = true; });
    })
  ];
  documentation.enable = false;
  networking.firewall.allowedTCPPorts = [ 9100 9102 ];
  services.openssh = {
    enable = true;
    permitRootLogin = "yes";
  };
  boot = {
    kernelPackages = builtins.getAttr "linuxPackages_rpi${toString config.boot.loader.raspberryPi.version}" pkgs;
    kernelParams = [ "boot.shell_on_fail" "console=tty1" "console=serial0,115200" ];
    loader = {
      grub.enable = false;
      raspberryPi = {
        enable = true;
        uboot.enable = false;
      };
    };
  };
}
