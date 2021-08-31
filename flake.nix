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
  };
  outputs = { self, nixpkgs, nixos-configs }:
  let
    # TODO, also use callPackage
    mkSdImage = model: (mkImage model {
      imports = [
        ./sd-config.nix
        (nixpkgs + "/nixos/modules/installer/sd-card/sd-image.nix")
      ];
    }).config.system.build.sdImage;
    mkNetImage = model:
    let
      system = if (model >= 3) then "aarch64-linux" else "armv7l-linux";
      pkgs = import nixpkgs { inherit system; };
    in pkgs.callPackage ./netimage.nix { inherit model mkImage nixpkgs nixos-configs; };
    mkImage = model: extra:
    let
      system = if (model >= 3) then "aarch64-linux" else "armv7l-linux";
    in
    import (nixpkgs + "/nixos") {
      configuration = { config, pkgs, ... }: {
        imports = [
          extra
          ./base-config.nix
        ];
        boot.loader.raspberryPi.version = model;
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
