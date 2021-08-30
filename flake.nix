{
  inputs = {
    nixos-configs = {
      url = "github:cleverca22/nixos-configs";
      #url = "path:/home/clever/apps/nixos-configs";
      flake = false;
    };
    #firmware = {
      #flake = false;
      #url = "path:/home/clever/apps/rpi/firmware2";
      #url = "github:raspberrypi/firmware";
    #};
    #nixpkgs = {
    #  url = "path:/home/clever/apps/rpi/rpi-nixos-nixpkgs";
    #};
  };
  outputs = { self, nixpkgs, nixos-configs }:
  let
    sd_config = { config, ... }: {
      imports = [
        (nixpkgs + "/nixos/modules/installer/sd-card/sd-image.nix")
      ];
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
    net_config = { pkgs, config, ... }:
    {
      imports = [
        "${nixos-configs}/iscsi-boot.nix"
      ];
      fileSystems = {
        "/" = {
          device = "/dev/disk/by-label/NIXOS_SD";
          fsType = "ext4";
          iscsi = {
            enable = true;
            host = "nas.localnet";
            lun = "iqn.2021-08.com.example:pi400.img";
          };
        };
        "/boot" = {
          device = "/dev/disk/by-label/NIXOS_BOOT";
          fsType = "vfat";
        };
      };
      boot.initrd.network.enable = true;
      networking.useDHCP = true;
      boot.initrd.network.flushBeforeStage2 = false;
      boot.initrd.iscsi.initiatorName = "iqn.2021-08.com.example:123456";
      boot.postBootCommands = ''
        if [ -f /nix-path-registration ]; then
          rootPart=$(${pkgs.util-linux}/bin/findmnt -n -o SOURCE /)
          ${pkgs.e2fsprogs}/bin/resize2fs $rootPart
          ${config.nix.package.out}/bin/nix-store --load-db < /nix-path-registration
          rm -f /nix-path-registration
        fi
      '';
    };
    mkSdImage = model: (mkImage model false).config.system.build.sdImage;
    mkNetImage = model:
    let
      system = if (model >= 3) then "aarch64-linux" else "armv7l-linux";
      pkgs = import nixpkgs { inherit system; };
      eval = mkImage model true;
      bootdir = pkgs.runCommand "netboot_boot-pi${toString model}" {} ''
        ${eval.config.system.build.installBootLoader} ${eval.system} -d $out
        cp -r ${pkgs.raspberrypifw}/share/raspberrypi/boot/overlays/ $out/overlays
      '';
      boot_img = pkgs.runCommand "netboot_boot-pi${toString model}.img.zstd" { buildInputs = with pkgs; [ util-linux libfaketime dosfstools mtools zstd ]; } ''
        truncate boot.img -s 512m
        sfdisk boot.img <<EOF
          label: dos
          type=b
        EOF
        eval $(partx boot.img -o START,SECTORS --nr 1 --pairs)
        truncate fat32.img -s $(($SECTORS * 512))
        faketime "1970-01-01 00:00:00" mkfs.vfat -n NIXOS_BOOT fat32.img

        mcopy -psvm -i fat32.img ${bootdir}/* ::
        fsck.vfat -vn fat32.img
        dd conv=notrunc if=fat32.img of=boot.img seek=$START count=$SECTORS
        md5sum boot.img
        echo "Compressing image"
        zstd -v --no-progress boot.img -o $out
      '';
      root_img = pkgs.callPackage "${nixpkgs}/nixos/lib/make-ext4-fs.nix" {
        compressImage = true;
        volumeLabel = "NIXOS_SD";
        storePaths = [ eval.config.system.build.toplevel ];
        uuid = "14e19a7b-0ae0-484d-9d54-43bd6fdc20c8";
      };
    in pkgs.runCommand "netboot_root-pi${toString model}" {} ''
      mkdir $out
      ln -s ${bootdir} $out/boot
      ln -s ${boot_img} $out/boot.img.zstd
      ln -s ${root_img} $out/root.img.zst
    '';
    mkImage = model: network:
    let
      system = if (model >= 3) then "aarch64-linux" else "armv7l-linux";
    in
    import (nixpkgs + "/nixos") {
      configuration = { config, pkgs, ... }: {
        imports = (if network then [ net_config ] else [ sd_config ]) ++
          [
            "${nixos-configs}/auto-gc.nix"
          ];
        nixpkgs.overlays = [
          (self: super: {
            makeModulesClosure = x: super.makeModulesClosure (x // { allowMissing = true; });
            #raspberrypifw = super.raspberrypifw.overrideAttrs (old: {
            #  src = firmware;
            #});
          })
        ];
        environment.systemPackages = [ pkgs.screen ];
        documentation.enable = false;
        nix.min-free-collection = true;
        boot = {
          kernelPackages = builtins.getAttr "linuxPackages_rpi${toString model}" pkgs;
          kernelParams = [ "boot.shell_on_fail" "console=tty1" "console=serial0,115200" ];
          loader = {
            grub.enable = false;
            raspberryPi = {
              enable = true;
              version = model;
              uboot.enable = false;
              firmwareConfig = ''
                enable_uart=1
                uart_2ndstage=1
              '';
            };
          };
        };
        users.users.root.openssh.authorizedKeys.keys = [
          "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC34wZQFEOGkA5b0Z6maE3aKy/ix1MiK1D0Qmg4E9skAA57yKtWYzjA23r5OCF4Nhlj1CuYd6P1sEI/fMnxf+KkqqgW3ZoZ0+pQu4Bd8Ymi3OkkQX9kiq2coD3AFI6JytC6uBi6FaZQT5fG59DbXhxO5YpZlym8ps1obyCBX0hyKntD18RgHNaNM+jkQOhQ5OoxKsBEobxQOEdjIowl2QeEHb99n45sFr53NFqk3UCz0Y7ZMf1hSFQPuuEC/wExzBBJ1Wl7E1LlNA4p9O3qJUSadGZS4e5nSLqMnbQWv2icQS/7J8IwY0M8r1MsL8mdnlXHUofPlG1r4mtovQ2myzOx clever@nixos"
        ];
        services = {
          openssh = {
            enable = true;
            permitRootLogin = "yes";
          };
        };
      };
      inherit system;
    };
  in {
    packages = {
      armv7l-linux = {
        net_image_pi2 = mkNetImage 2;
      };
      aarch64-linux = {
        sd_image_pi3 = mkSdImage 3;
        sd_image_pi4 = mkSdImage 4;
        net_image_pi4 = mkNetImage 4;
      };
    };
  };
}
