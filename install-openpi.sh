#! @crossShell@
# meant to be used as part of nixos, not ran manually

set -e

# temporary, just to enable init=/init
ln -svf $1/init /init

for file in rpi1.dtb rpi2.dtb rpi3.dtb; do
  cp -v @dtb_files@/$file /boot/
done
cp -vL @lk_elf@ /boot/lk.elf

cp -vL $1/initrd /boot/initrd
cp -vL @kernel@ /boot/zImage

echo "systemConfig=$1 init=$1/init $(cat $1/kernel-params)" > /boot/cmdline.txt

time sync
