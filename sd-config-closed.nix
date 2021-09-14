{ config, lib, ... }:
{
  imports = [
  ];
  options = {
    rpi-nixos.closedfirmware.enable = lib.mkEnableOption "boot using the official closed-source firmware";
  };
  config = lib.mkIf config.rpi-nixos.closedfirmware.enable {
    sdImage = {
      firmwareSize = 256;
      populateFirmwareCommands = ''
        ${config.system.build.installBootLoader} ${config.system.build.toplevel} -d firmware
      '';
      populateRootCommands = ''
      '';
    };
    fileSystems = {
      "/" = {
        device = "/dev/disk/by-label/NIXOS_SD";
        fsType = "ext4";
      };
      "/boot" = {
        device = "/dev/disk/by-label/FIRMWARE";
        fsType = "vfat";
      };
    };
  };
}
