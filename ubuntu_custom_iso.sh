---
# tasks file for unattended_ubuntu

apt install p7zip-full mktemp xorriso -y

# Script must be started as root to allow iso mounting
if [ "$EUID" -ne 0 ] ; then echo "Please run as root or sudo" ;  exit 1 ;  fi
currentdir="$(pwd)"

if [[ -z $WORKINGDIR ]]; then
  WORKINGDIR="$(mktemp -d -t isobuilder-XXXX)"
fi

if [[ -z $BASEISO || -z $KS || -z $KSIPADDRESS || -z $KSGATEWAY || -z $KSHOSTNAME || -z $KSVLAN || -z $KSNAMESERVER ]]; then
 echo 'Usage: ubuntu_custom_iso.sh -i ubuntu-22.04.3-live-server-amd64.iso -u user-data.template \'
 echo '                            -a "192.168.86.133/24" -g 192.168.86.1 -n ubuntu-auto-server -v 0 -d 192.168.86.1'
 echo 'Options:'
 echo "  -i, --iso          Base ISO File"
 echo '  -u, --udata        User Data File'
 echo '  -w, --working-dir  Working directory (Optional)'
 echo '  -a, --ip-address   Ubuntu IP Address and Netmask'
 echo '  -g, --gateway      Ubuntu Gateway'
 echo '  -n, --hostname     Ubuntu Hostname'
 echo '  -d, --dns          Ubuntu DNS Server'
 exit 1
fi

while [[ "$#" -gt 0 ]]; do
  case $1 in
    -i|--iso) BASEISO="$2"; shift ;;
    -u|--udata) KS="$2"; shift ;;
    -w|--working-dir) WORKINGDIR="$2"; shift ;;
    -a|--ip-address) KSIPADDRESS="$2"; shift ;;
    -g|--gateway) KSGATEWAY="$2"; shift ;;
    -n|--hostname) KSHOSTNAME="$2"; shift ;;
    -d|--dns) KSNAMESERVER="$2"; shift ;;
    *) echo "Unknown parameter: $1"; exit 1 ;;
  esac
  shift
done

mkdir -p ${WORKINGDIR}/iso
cp -vr ${BASEISO} ${WORKINGDIR}
ISO_NAME=$(echo $BASEISO | sed "s/\.iso//")
7z -y x ${ISO_NAME}.iso -oiso
mv ${WORKINGDIR}/iso/'[BOOT]' ${WORKINGDIR}/BOOT
rm -f ${WORKINGDIR}/iso/boot/grub/grub.cfg
cp -vr grub.cfg ${WORKINGDIR}/iso/boot/grub/grub.cfg
mkdir ${WORKINGDIR}/iso/server
touch ${WORKINGDIR}/iso/server/meta-data
cp user-data.template ${WORKINGDIR}/iso/server/user-data

sed -i -e 's/KSIPADDRESS/'"$KSIPADDRESS"'/g'  ${WORKINGDIR}/iso/server/user-data
sed -i -e 's/KSGATEWAY/'"$KSGATEWAY"'/g'  ${WORKINGDIR}/iso/server/user-data
sed -i -e 's/KSHOSTNAME/'"$KSHOSTNAME"'/g'  ${WORKINGDIR}/iso/server/user-data
sed -i -e 's/KSNAMESERVER/'"$KSNAMESERVER"'/g'  ${WORKINGDIR}/iso/server/user-data

- name: copy xorriso.sh file
  copy:
    src: files/xorriso.sh
    dest: /tmp/xorriso.sh
    mode: '0755'

- name: generate ISO
  shell: "./xorriso.sh ${WORKINGDIR}/iso {{iso_autoinstall}} {{iso_autoinstall}}.iso"
  args:
    chdir: /tmp

- name: remove old ISO
  file:
    path: "/iso/{{iso_autoinstall}}.iso"
    state: absent

- name: copy new ISO to NFS folder
  copy:
    src: "${WORKINGDIR}/{{iso_autoinstall}}.iso"
    dest: /iso
  become: true
  become_method: sudo
