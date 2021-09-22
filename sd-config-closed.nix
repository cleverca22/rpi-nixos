{ config, lib, ... }:
{
  imports = [
  ];
  options = {
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
