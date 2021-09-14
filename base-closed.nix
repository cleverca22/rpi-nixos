{ config, lib, pkgs, ... }:

{
  config = lib.mkIf config.rpi-nixos.closedfirmware.enable {
    boot = {
      loader = {
        grub.enable = false;
        raspberryPi = {
          enable = true;
          uboot.enable = false;
        };
      };
    };
    hardware.firmware = with pkgs; [ firmwareLinuxNonfree ]; # wifi support needs brcmfmac43455-sdio
  };
}
