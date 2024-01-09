#!/bin/bash
apt install p7zip-full xorriso ipcalc -y

# Script must be started as root to allow iso mounting
if [ "$EUID" -ne 0 ] ; then echo "Please run as root or sudo" ;  exit 1 ;  fi
currentdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

if [[ -z $WORKINGDIR ]]; then
  WORKINGDIR="$(mktemp -d -t isobuilder-XXXX)"
fi


while [[ "$#" -gt 0 ]]; do
  case $1 in
    -i|--iso) BASEISO="$2"; shift ;;
    -u|--udata) KS="$2"; shift ;;
    -w|--working-dir) WORKINGDIR="$2"; shift ;;
    -a|--ip-address) KSIPADDRESS="$2"; shift ;;
    -m|--netmask) KSMASK="$2"; shift ;;
    -g|--gateway) KSGATEWAY="$2"; shift ;;
    -n|--hostname) KSHOSTNAME="$2"; shift ;;
    -d|--dns) KSNAMESERVER="$2"; shift ;;
    *) echo "Unknown parameter: $1"; exit 1 ;;
  esac
  shift
done

if [[ -z $BASEISO || -z $KS || -z $KSIPADDRESS || -z $KSGATEWAY || -z $KSHOSTNAME || -z $KSMASK || -z $KSNAMESERVER ]]; then
 echo 'Usage: ubuntu_custom_iso.sh -i ubuntu-22.04.3-live-server-amd64.iso -u user-data.template \'
 echo '                            -a 192.168.86.133 -m 255.255.255.0 -g 192.168.86.1 -n ubuntu-auto-server -d 192.168.86.1'
 echo 'Options:'
 echo "  -i, --iso          Base ISO File"
 echo '  -u, --udata        User Data File'
 echo '  -w, --working-dir  Working directory (Optional)'
 echo '  -a, --ip-address   Ubuntu IP Address'
 echo '  -m, --netmask      Ubuntu Netmask'
 echo '  -g, --gateway      Ubuntu Gateway'
 echo '  -n, --hostname     Ubuntu Hostname'
 echo '  -d, --dns          Ubuntu DNS Server'
 exit 1
fi

KPREFIX=$(ipcalc -nb 1.1.1.1 $KSMASK | sed -n '/Netmask/s/^.*=[ ]/\//p')

KIP=$(echo "$KSIPADDRESS""$KSMASK")

mkdir -p ${WORKINGDIR}/iso
cp -vr ${BASEISO} ${WORKINGDIR} -v
ISO_NAME=$(echo $BASEISO | sed "s/\.iso//")
cd ${WORKINGDIR}
7z -y x ${ISO_NAME}.iso -oiso
mv ${WORKINGDIR}/iso/'[BOOT]' ${WORKINGDIR}/BOOT -v
rm -f ${WORKINGDIR}/iso/boot/grub/grub.cfg -v
cp -vr ${currentdir}/grub.cfg ${WORKINGDIR}/iso/boot/grub/grub.cfg -v
mkdir ${WORKINGDIR}/iso/server -v
touch ${WORKINGDIR}/iso/server/meta-data
cp ${currentdir}/user-data.template ${WORKINGDIR}/iso/server/user-data -v

sed -i -e 's/KSIPADDRESS/'"$KSIP"'/g'  ${WORKINGDIR}/iso/server/user-data
sed -i -e 's/KSGATEWAY/'"$KSGATEWAY"'/g'  ${WORKINGDIR}/iso/server/user-data
sed -i -e 's/KSHOSTNAME/'"$KSHOSTNAME"'/g'  ${WORKINGDIR}/iso/server/user-data
sed -i -e 's/KSNAMESERVER/'"$KSNAMESERVER"'/g'  ${WORKINGDIR}/iso/server/user-data

bash -c "cd ${WORKINGDIR}/iso && xorriso -as mkisofs -r \
  -V \"${ISO_NAME}\" \
  -o ../${ISO_NAME}-auto.iso \
  --grub2-mbr ../BOOT/1-Boot-NoEmul.img \
  -partition_offset 16 \
  --mbr-force-bootable \
  -append_partition 2 28732ac11ff8d211ba4b00a0c93ec93b ../BOOT/2-Boot-NoEmul.img \
  -appended_part_as_gpt \
  -iso_mbr_part_type a2a0d0ebe5b9334487c068b6b72699c7 \
  -c '/boot.catalog' \
  -b '/boot/grub/i386-pc/eltorito.img' \
    -no-emul-boot -boot-load-size 4 -boot-info-table --grub2-boot-info \
  -eltorito-alt-boot \
  -e '--interval:appended_partition_2:::' \
  -no-emul-boot \
  ."

mv -v ${WORKINGDIR}/${ISO_NAME}-auto.iso ${currentdir}
rm -rf ${WORKINGDIR}
