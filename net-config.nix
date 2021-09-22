{ pkgs, config, lib, ... }:

let
  cfg = config.rpi-netboot;
in {
  options = {
    rpi-netboot = {
      enable = lib.mkEnableOption "enable rpi netboot";
      lun = lib.mkOption {
        type = lib.types.str;
        default = "iqn.2021-08.com.example:pi400.img";
        description = "the iscsi target LUN to mount as the rootfs";
      };
      host = lib.mkOption {
        type = lib.types.str;
        default = "nas.localnet";
        description = "the iscsi server for the rootfs";
      };
    };
  };
  config = lib.mkIf cfg.enable {
    fileSystems = {
      "/" = {
        device = "/dev/disk/by-label/NIXOS_SD";
        fsType = "ext4";
        iscsi = {
          enable = true;
          host = cfg.host;
          lun = cfg.lun;
        };
      };
      "/boot" = {
        device = "/dev/disk/by-label/NIXOS_BOOT";
        fsType = "vfat";
      };
    };
    networking = {
      useDHCP = true;
      dhcpcd.persistent = true;
    };
    boot = {
      initrd = {
        network = {
          enable = true;
          flushBeforeStage2 = false;
        };
        iscsi.initiatorName = "iqn.2021-08.com.example:123456";
      };
      postBootCommands = ''
        if [ -f /nix-path-registration ]; then
          rootPart=$(${pkgs.utillinux}/bin/findmnt -n -o SOURCE /)
          ${pkgs.e2fsprogs}/bin/resize2fs $rootPart
          ${config.nix.package.out}/bin/nix-store --load-db < /nix-path-registration
          rm -f /nix-path-registration
        fi
      '';
    };
  };
}
