{ model, pkgs, mkImage, configuration ? {}, nixpkgs, nixos-configs }:
let
  eval = mkImage {
    model = model;
    extra = {
      imports = [
        configuration
        ./net-config.nix
        "${nixos-configs}/iscsi-boot.nix"
      ];
      rpi-netboot.enable = true;
    };
    firmware = "closed";
  };
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
  baseFiles = pkgs.runCommand "netboot_root-pi${toString model}" {} ''
    mkdir $out
    ln -s ${bootdir} $out/boot
    ln -s ${boot_img} $out/boot.img.zstd
    ln -s ${root_img} $out/root.img.zst
  '';
# allows doing:
# nix build .#packages.aarch64-linux.net_image_pi4.system
# to get just the system, without building a new disk image
in
  baseFiles // { system = eval.system; }
