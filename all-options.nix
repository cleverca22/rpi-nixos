{ lib, ... }:

{
  options = {
    rpi-nixos.closedfirmware.enable = lib.mkEnableOption "boot using the official closed-source firmware";
    rpi-nixos.openfirmware.enable = lib.mkEnableOption "boot using the open rpi firmware";
  };
}
