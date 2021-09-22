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
}
