{
  inputs = {
    barebox.url = "github:cleverca22/barebox-nix";
    nixos-configs = {
      url = "github:cleverca22/nixos-configs";
      #url = "path:/home/clever/apps/nixos-configs";
      flake = false;
    };
    #nixpkgs = {
    #  url = "path:/home/clever/apps/rpi/rpi-nixos-nixpkgs";
    #};
    nixpkgs.url = "github:nixos/nixpkgs";
    # for an older gpg that can build
    nixpkgs-old.url = "github:nixos/nixpkgs?rev=1451a52a38f2dda459647a5c2628e7c28e17c4dc";
    nixpkgs-old.flake = false;
    #lk-overlay.url = "github:librerpi/lk-overlay";
    #lk-overlay2.url = "path:/home/clever/apps/rpi/lk-overlay";
    #lk-overlay2.flake = false;
    rpi-open-firmware.url = "github:librerpi/rpi-open-firmware";
    rpi-open-firmware.flake = false;
    rpi-tools.url = "github:librerpi/rpi-tools";
    rpi-tools.inputs.nixpkgs.follows = "nixpkgs";
    firmware.flake = false;
    firmware.url = "github:raspberrypi/firmware";
  };
  outputs = { self, barebox, nixpkgs, nixos-configs, nixpkgs-old, rpi-open-firmware, rpi-tools, firmware }:
  let
    hostPkgs = import nixpkgs { system = "x86_64-linux"; };
    # TODO, i had trouble building linux with the right cfg in nix
    # this is a temporary work-around, a linux build in a normal shell
    zImage = hostPkgs.fetchurl {
      url = "https://ext.earthtools.ca/private/rpi/zImage-2020-05-19";
      sha256 = "09kijy3rrwzf6zgrq3pbww9267b1dr0s9rippz7ygk354lr3g7c8";
    };
    lk-overlay-src = hostPkgs.fetchFromGitHub {
      owner = "librerpi";
      repo = "lk-overlay";
      rev = "c371503d8e300490882ee15c67f6beae7e9f6d23";
      fetchSubmodules = true;
      hash = "sha256-BhtlFtxwA16axt//DhOHzkfKRJr6Xj29A0mVDs+jLWA=";
    };
    lk-overlay = import lk-overlay-src {};
    # TODO, also use callPackage
    mkSdImage = { model, firmware }:
    let
      eval = mkImage {
        inherit model firmware;
        extra = {
          rpi-nixos.closedfirmware.enable = firmware == "closed";
          rpi-nixos.openfirmware.enable = firmware == "open";
          imports = [
            #(nixpkgs + "/nixos/modules/installer/sd-card/sd-image.nix")
            (nixpkgs + "/nixos/modules/installer/cd-dvd/sd-image.nix")
          ];
        };
      };
      sdImage = eval.config.system.build.sdImage;
      extra = {
        inherit eval;
      };
    in sdImage // extra;
    mkNetImage = model:
    let
      system = if (model >= 3) then "aarch64-linux" else "armv7l-linux";
      pkgs = import nixpkgs { inherit system; };
    in pkgs.callPackage ./netimage.nix { inherit model mkImage nixpkgs nixos-configs; };
    mkImage = { model,  extra, firmware }:
    let
      system = if (model >= 3) then "aarch64-linux" else "armv7l-linux";
      lib = (import nixpkgs { system = "x86_64-linux"; }).lib;
    in
    import (nixpkgs + "/nixos") {
      configuration = { config, pkgs, ... }: {
        imports = [
          extra
          ./base-config.nix
          ./sd-config-open.nix
          ./sd-config-closed.nix
          ./base-closed.nix
          ./all-options.nix
        ];
        boot.loader.raspberryPi.version = model;
        #nixpkgs.crossSystem.system = system;
        _module.args = {
          inherit lk-overlay rpi-open-firmware;
        };
        #nixpkgs.crossSystem.config = "armv7l-unknown-linux-gnueabihf";
        #nixpkgs.crossSystem = lib.systems.examples.armv7l-hf-multiplatform;
        #nixpkgs.pkgs = hostPkgs.pkgsCross.armv7l-hf-multiplatform;
        environment.systemPackages = [
          rpi-tools.packages.armv7l-linux.utils
          pkgs.i2c-tools
        ];
      };
      inherit system;
      #system = "x86_64-linux";
    };
    mkImageNostage1 = bootmode: system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
      eval = pkgs.nixos ({ ... }: {
        fileSystems."/".fsType = "tmpfs";
        boot.loader.grub.enable = false;
      });
      initrd = pkgs.makeInitrd {
        contents = [
          {
            symlink = "/init";
            object = "${eval.config.system.build.toplevel}/init";
          }
        ];
      };
      bootFolder = pkgs.runCommand "rpi-boot" {
        passthru.eval = eval;
        passAsFile = [ "configtxt" ];
        configtxt = ''
          kernel=${eval.config.system.boot.loader.kernelFile}
          initramfs initrd followkernel
        '';
      } ''
        mkdir $out
        cd $out
        cp ${initrd}/initrd initrd
        cp ${eval.config.system.build.kernel}/${eval.config.system.boot.loader.kernelFile} .
        cp -v ${firmware}/boot/{start4.elf,fixup4.dat} .
      '';
      bootImg = pkgs.vmTools.runInLinuxVM (pkgs.runCommand "bootImg" {
        preVM = ''
        '';
      } ''
        mtroo
      '');
    in
      bootFolder;
  in {
    packages = {
      x86_64-linux = {
        lk = hostPkgs.runCommand "lk" {} ''
          mkdir $out
          cp -v ${lk-overlay.vc4.vc4.stage1}/lk.bin $out/bootcode.bin
          cp -v ${lk-overlay.vc4.vc4.stage2}/lk.elf $out/
          ln -sv ${lk-overlay.vc4.vc4.stage1} $out/vc4-stage1
          ln -sv ${lk-overlay.vc4.vc4.stage2} $out/vc4-stage2
          ln -sv ${lk-overlay.arm.rpi2-test} $out/rpi2-test
          ln -sv ${lk-overlay.vc4.vc4.stage1-spi} $out/vc4-stage1-spi
          ln -sv ${lk-overlay.vc4.vc4.stage2-spi} $out/vc4-stage2-spi
        '';
        barebox-spi = hostPkgs.runCommand "barebox-spi" { nativeBuildInputs = [ lk-overlay.x86_64.mkimage ]; } ''
          ln -sv ${lk-overlay.vc4.vc4.stage1-spi} vc4-stage1-spi
          ln -sv ${lk-overlay.vc4.vc4.stage2-spi} vc4-stage2-spi
          mkimage ${./barebox.json} -I${barebox.packages.x86_64-linux.rpi}
          mkdir $out
          cp -v eeprom.bin $out/
        '';
        dist = hostPkgs.runCommandCC "dist" { buildInputs = [ hostPkgs.dtc ]; } ''
          mkdir -pv $out/boot/firmware/ $out/nix-support
          cp -v ${lk-overlay.vc4.vc4.stage1}/lk.bin $out/boot/firmware/bootcode.bin
          cp -v ${lk-overlay.vc4.vc4.stage2}/lk.elf $out/boot/lk.elf
          builddtb() {
            cc -x assembler-with-cpp -E $1 -o temp
            egrep -v '^#' < temp > temp2
            dtc temp2 -o $2
            rm temp temp2
          }
          builddtb ${rpi-open-firmware}/rpi2.dts $out/boot/rpi2.dtb
          builddtb ${rpi-open-firmware}/rpi3.dts $out/boot/rpi3.dtb
          echo root=/dev/mmcblk0p2 > $out/boot/cmdline.txt
          cp -v ${zImage} $out/boot/zImage

          cd $out
          tar --sort=name -cvf boot.tar boot/

          echo "file binary-dist $out/boot.tar" >> $out/nix-support/hydra-build-products
        '';
        dist_deb = hostPkgs.runCommandCC "dist_deb" { buildInputs = [ hostPkgs.dpkg ]; } ''
          cp -r ${./dpkg-input} input
          chmod -R 755 input
          mkdir -p $out/nix-support
          tar -C input -xvf ${self.packages.x86_64-linux.dist}/boot.tar
          dpkg-deb --build input $out/librepi-firmware.deb
          # 2022-04-09 00:50:12 < pabs> Architecture should be armhf for ARMv7/8 32-bit devices, armel for less than ARMv7 and arm64 for ARMv8 64-bit
          echo "file binary-dist $out/librepi-firmware.deb" >> $out/nix-support/hydra-build-products
        '';
      };
      armv7l-linux = {
        net_image_pi2 = mkNetImage 2;
        sd_image_open_pi2 = mkSdImage { model=2; firmware="open"; };
      };
      aarch64-linux = {
        sd_image_pi3 = mkSdImage { model = 3; firmware = "closed"; };
        sd_image_pi4 = mkSdImage { model = 4; firmware = "closed"; };
        net_image_pi4 = mkNetImage 4;

        pi4_closed_tftpboot_nostage1 = mkImageNostage1 "tftp" "aarch64-linux";
      };
    };
    hydraJobs.x86_64-linux = {
      sd_image_open_pi2 = self.packages.armv7l-linux.sd_image_open_pi2;
      dist = self.packages.x86_64-linux.dist;
      dist_deb = self.packages.x86_64-linux.dist_deb;
    };
  };
}
