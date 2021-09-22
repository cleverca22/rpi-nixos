{
  inputs = {
    nixos-configs = {
      url = "github:cleverca22/nixos-configs";
      #url = "path:/home/clever/apps/nixos-configs";
      flake = false;
    };
    #nixpkgs = {
    #  url = "path:/home/clever/apps/rpi/rpi-nixos-nixpkgs";
    #};
    nixpkgs.url = "github:nixos/nixpkgs?rev=c32264ef79ffeb807015b66fd6c5c893ba1c8ee9";
    # for an older gpg that can build
    nixpkgs-old.url = "github:nixos/nixpkgs?rev=1451a52a38f2dda459647a5c2628e7c28e17c4dc";
    nixpkgs-old.flake = false;
    #lk-overlay.url = "github:librerpi/lk-overlay";
    #lk-overlay2.url = "path:/home/clever/apps/rpi/lk-overlay";
    #lk-overlay2.flake = false;
    rpi-open-firmware.url = "github:librerpi/rpi-open-firmware";
    rpi-open-firmware.flake = false;
  };
  outputs = { self, nixpkgs, nixos-configs, nixpkgs-old, rpi-open-firmware }:
  let
    hostPkgs = import nixpkgs { system = "x86_64-linux"; };
    lk-overlay-src = hostPkgs.fetchFromGitHub {
      owner = "librerpi";
      repo = "lk-overlay";
      rev = "afe1c73e18ce174dd12e3a35fd01843838e35d02";
      fetchSubmodules = true;
      sha256 = "sha256-HgI/B5XRYsFeTvlPZClCXWY/KTh2ah1qSCDQOXnXAHY=";
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
      };
      inherit system;
      #system = "x86_64-linux";
    };
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
      };
    };
    hydraJobs.x86_64-linux = {
      sd_image_open_pi2 = self.packages.armv7l-linux.sd_image_open_pi2;
    };
  };
}
