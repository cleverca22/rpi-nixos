{ config, pkgs, rpi-open-firmware, lk-overlay, lib, ... }:

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
    echo $out
  '';
in
{
  options = {
    boot.loader.openpi = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
    };
  };
  config = lib.mkIf config.boot.loader.openpi.enable {
    system.boot.loader.id = "openpi";
    system.build.installBootLoader = pkgs.substituteAll {
      src = ./install-openpi.sh;
      name = "install-openpi.sh";
      isExecutable = true;
      crossShell = pkgs.runtimeShell;
      inherit dtb_files;
      lk_elf = "${lk-overlay.vc4.vc4.stage2}/lk.elf";
      kernel = ./zImage;
    };
  };
}
