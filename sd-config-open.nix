{ pkgs, config, lib, lk-overlay, rpi-open-firmware, ... }:

let
  dtb_files = pkgs.runCommandCC "dtb_files" { nativeBuildInputs = [ pkgs.buildPackages.dtc ]; } ''
    mkdir $out
    cd $out
    builddtb() {
      $CC -x assembler-with-cpp -E $1 -o temp
      egrep -v '^#' < temp > temp2
      dtc temp2 -o $2
      rm temp temp2
    }
    builddtb ${rpi-open-firmware}/rpi1.dts rpi1.dtb
    builddtb ${rpi-open-firmware}/rpi2.dts rpi2.dtb
    builddtb ${rpi-open-firmware}/rpi3.dts rpi3.dtb
  '';
in
{
  options = {
  };
  config = lib.mkIf config.rpi-nixos.openfirmware.enable {
    boot.loader.openpi.enable = true;
    sdImage = {
      firmwareSize = 32;
      populateFirmwareCommands = ''
        mkdir -p firmware
        cp -v ${lk-overlay.vc4.vc4.stage1}/lk.bin firmware/bootcode.bin
      '';
      populateRootCommands = ''
        mkdir -p files/boot
        cp -v ${lk-overlay.vc4.vc4.stage2}/lk.elf files/boot/lk.elf
        cp -v ${./zImage} files/boot/zImage
        cp -v ${dtb_files}/*.dtb files/boot/
        echo "init=${config.system.build.toplevel}/init $(cat ${config.system.build.toplevel}/kernel-params)" > files/boot/cmdline.txt
      '';
    };
    users.users.root.initialPassword = "password";
  };
}
