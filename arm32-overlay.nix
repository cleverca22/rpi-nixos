self: super: {
  #libunwind = super.libunwind.overrideAttrs (old: {
    #configureFlags = old.configureFlags or [] ++ [ "--target=armv7l-linux" ];
  #});
  llvmPackages = self.llvmPackages_9;
  llvmPackages_9 = super.llvmPackages_9.extend (llself: llsuper: {
    inherit llsuper;
    llvm = llsuper.llvm.overrideAttrs (old: {
      # Failing Tests (1): LLVM :: tools/gold/X86/split-dwarf.ll
      doCheck = false;
    });
  });
  libdrm = super.libdrm.override { withValgrind = false; };
  #librsvg = false;
  valgrind = super.valgrind.overrideAttrs (old: {
    patches = [ ./valgrind.patch ];
  });
  parole = super.bashInteractive;
  yavta = self.stdenv.mkDerivation {
    name = "yavta";
    src = self.fetchgit {
      url = "https://git.ideasonboard.org/git/yavta.git/";
      rev = "65f740aa1758531fd810339bc1b7d1d33666e28a";
      sha256 = "sha256-K4DqkK6Tv6eXJA+WghP/468Zbwo7vlXZBrHv2bNAvqE=";
    };
    installPhase = ''
      mkdir -pv $out/bin
      cp yavta $out/bin/
    '';
  };
  v4l-utils = super.v4l-utils.override { withGUI = false; };
}
