#!/bin/bash
# Arch Linux LVM + btrfs installer, run from the live ISO as root.
# Usage:  arch-install.sh            # interactive install
#         arch-install.sh extend /dev/sdX [vg] [lv]   # add disk to existing VG
set -euo pipefail
trap 'echo "!! failed at line $LINENO (exit $?)" >&2' ERR

# ---------- helpers ----------
die() { echo "!! $*" >&2; exit 1; }

ask() { # ask VAR "prompt" default
  local __v=$1 __p=$2 __d=${3-} __in
  read -rp "$__p [$__d]: " __in || true
  printf -v "$__v" '%s' "${__in:-$__d}"
}

ask_pw() { # ask_pw VAR "label"
  local __v=$1 __p=$2 __a __b
  while :; do
    read -rsp "$__p: " __a; echo >&2
    read -rsp "$__p (again): " __b; echo >&2
    [[ -n $__a && $__a == "$__b" ]] && break
    echo "   empty or mismatch, retry" >&2
  done
  printf -v "$__v" '%s' "$__a"
}

part() { # part /dev/sda 1 -> /dev/sda1 ; /dev/nvme0n1 1 -> /dev/nvme0n1p1
  if [[ $1 =~ [0-9]$ ]]; then echo "${1}p${2}"; else echo "${1}${2}"; fi
}

wipe() { # wipe signatures on a disk and its children, children first
  lsblk -nrpo NAME "$1" | tac | xargs -rn1 wipefs -af
}

# ---------- extend subcommand (run on an installed system) ----------
if [[ ${1-} == extend ]]; then
  disk=${2-} vg=${3-} lv=${4-}
  [[ -n $disk ]] || die "usage: $0 extend /dev/sdX [vg] [lv]"
  [[ $EUID -eq 0 ]] || die "must be root"
  [[ -b $disk ]] || die "not a block device: $disk"
  src=$(findmnt -no SOURCE /); src=${src%%\[*}
  [[ -n $vg ]] || vg=$(lvs --noheadings -o vg_name "$src" | tr -d ' ')
  [[ -n $lv ]] || lv=$(lvs --noheadings -o lv_name "$src" | tr -d ' ')
  fstype=$(findmnt -no FSTYPE /)
  [[ -n $vg && -n $lv ]] || die "cannot detect root VG/LV from $src"
  echo "disk=$disk  vg=$vg  lv=$lv  fs=$fstype"
  read -rp "Wipe $disk and add it to $vg (all data on it is lost). Type YES: " a
  [[ $a == YES ]] || die "aborted"
  wipefs -af "$disk"
  pvcreate -y "$disk"
  vgextend "$vg" "$disk"
  lvextend -l +100%FREE "/dev/$vg/$lv"
  case $fstype in
    btrfs) btrfs filesystem resize max / ;;
    ext*)  resize2fs "/dev/$vg/$lv" ;;
    xfs)   xfs_growfs / ;;
    *)     echo "!! unknown fs '$fstype', resize manually" >&2 ;;
  esac
  echo "== done: $disk added to $vg, $lv grown"
  exit 0
fi

# ---------- preflight ----------
[[ $EUID -eq 0 ]] || die "run as root"
[[ -d /sys/firmware/efi/efivars ]] || die "not booted in UEFI mode"
rfkill unblock all || true
ping -c1 -W3 archlinux.org >/dev/null 2>&1 \
  || die "no network; run 'iwctl' to connect wifi, then retry"

echo "== available disks =="
lsblk -dpno NAME,SIZE,MODEL,TYPE
echo

live_disk=
live_src=$(findmnt -no SOURCE /run/archiso/bootmnt 2>/dev/null || true)
if [[ -n $live_src ]]; then
  pk=$(lsblk -ndo PKNAME "$live_src" 2>/dev/null || true)
  [[ -n $pk ]] && live_disk="/dev/$pk"
fi

check_disk() { # check_disk /dev/sdX
  [[ -b $1 ]] || die "not a block device: $1"
  [[ -n $live_disk && $1 == "$live_disk" ]] && die "$1 is the live medium"
  if lsblk -nro MOUNTPOINT "$1" | grep -q .; then die "$1 has mounted partitions"; fi
  return 0
}

ask DISK "Target disk (will be wiped)" ""
ask EXTRA "Extra whole disks for the VG, space separated (optional)" ""
ask VG    "Volume group name" "vg0"
ask SWAP  "Swap size, 0 = none" "4G"
ask HOST  "Hostname" "arch"
ask USER  "Username" "wray"
ask TZ    "Timezone" "Asia/Shanghai"
ask CN    "Use China mirrors (ustc/tuna)? y/N" "n"
ask DUAL  "Dual boot with another OS (os-prober)? y/N" "n"

check_disk "$DISK"
read -ra extras <<<"$EXTRA"
for d in "${extras[@]}"; do check_disk "$d"; done
[[ -e /usr/share/zoneinfo/$TZ ]] || die "unknown timezone: $TZ"

ask_pw ROOT_PW "root password"
ask_pw USER_PW "password for $USER"

[[ $CN =~ ^[Yy] ]] && CN=1 || CN=0
[[ $DUAL =~ ^[Yy] ]] && DUAL=1 || DUAL=0

ucode=
grep -q AuthenticAMD /proc/cpuinfo && ucode=amd-ucode
grep -q GenuineIntel /proc/cpuinfo && ucode=intel-ucode

cat <<EOF

== summary ==
disk(s)   : $DISK ${extras[*]-}
vg        : $VG   swap: $SWAP
hostname  : $HOST
user      : $USER (wheel, bash)
timezone  : $TZ
microcode : ${ucode:-none}
china mir.: $CN   dual boot: $DUAL

ALL DATA ON THE DISKS ABOVE WILL BE DESTROYED.
EOF
read -rp "Type YES to proceed: " a
[[ $a == YES ]] || die "aborted"

# ---------- mirrors ----------
if (( CN )); then
  systemctl stop reflector || true
  tmp=$(mktemp)
  {
    echo 'Server = https://mirrors.ustc.edu.cn/archlinux/$repo/os/$arch'
    echo 'Server = https://mirrors.tuna.tsinghua.edu.cn/archlinux/$repo/os/$arch'
    cat /etc/pacman.d/mirrorlist
  } >"$tmp"
  mv "$tmp" /etc/pacman.d/mirrorlist
fi

# ---------- partition ----------
vgchange -an >/dev/null 2>&1 || true   # deactivate any old VG (reinstall case)
wipe "$DISK"
sgdisk --zap-all "$DISK"
sgdisk -n1:0:+1G -t1:ef00 -n2:0:0 -t2:8e00 "$DISK"
partprobe "$DISK" 2>/dev/null || true
udevadm settle
ESP=$(part "$DISK" 1)
ROOT_PART=$(part "$DISK" 2)
for d in "${extras[@]}"; do wipe "$d"; done

# ---------- LVM ----------
if vgs "$VG" &>/dev/null; then die "VG '$VG' still exists on another disk, pick another name"; fi
pvcreate -y "$ROOT_PART"
for d in "${extras[@]}"; do pvcreate -y "$d"; done
vgcreate -y "$VG" "$ROOT_PART" "${extras[@]}"
if [[ $SWAP != 0 ]]; then
  lvcreate -y -L "$SWAP" -n swap "$VG"
fi
lvcreate -y -l 100%FREE -n root "$VG"

# ---------- filesystems ----------
mkfs.fat -F32 "$ESP"
mkfs.btrfs -f "/dev/mapper/$VG-root"
mount -o noatime,compress=zstd "/dev/mapper/$VG-root" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
umount /mnt
mount -o noatime,compress=zstd,subvol=@ "/dev/mapper/$VG-root" /mnt
mount --mkdir -o noatime,compress=zstd,subvol=@home "/dev/mapper/$VG-root" /mnt/home
mount --mkdir "$ESP" /mnt/boot
if [[ $SWAP != 0 ]]; then
  mkswap "/dev/mapper/$VG-swap"
  swapon "/dev/mapper/$VG-swap"
fi

# ---------- base install ----------
pacman -Sy --noconfirm archlinux-keyring
pkgs=(base base-devel linux linux-firmware lvm2 btrfs-progs grub efibootmgr
      networkmanager iwd sudo vim git openssh man-db)
[[ -n $ucode ]] && pkgs+=("$ucode")
(( DUAL )) && pkgs+=(os-prober ntfs-3g)
pacstrap -K /mnt "${pkgs[@]}"
genfstab -U /mnt >>/mnt/etc/fstab

# ---------- chroot config (no passwords in here) ----------
arch-chroot /mnt /bin/bash -e <<EOF
ln -sf /usr/share/zoneinfo/$TZ /etc/localtime
hwclock --systohc
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/; s/^#zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' >/etc/locale.conf
echo '$HOST' >/etc/hostname
printf '127.0.0.1 localhost\n::1 localhost\n127.0.1.1 %s.localdomain %s\n' '$HOST' '$HOST' >/etc/hosts

# add lvm2 before filesystems (works for udev and systemd hook sets)
grep -q '^HOOKS=.*lvm2' /etc/mkinitcpio.conf ||
  sed -i '/^HOOKS=/ s/\bfilesystems\b/lvm2 filesystems/' /etc/mkinitcpio.conf
mkinitcpio -P

useradd -m -G wheel -s /bin/bash '$USER'
printf '%%wheel ALL=(ALL:ALL) ALL\n' >/etc/sudoers.d/wheel
chmod 0440 /etc/sudoers.d/wheel

if (( $DUAL )); then
  sed -i 's/^#\?GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
  grep -q '^GRUB_DISABLE_OS_PROBER' /etc/default/grub ||
    echo 'GRUB_DISABLE_OS_PROBER=false' >>/etc/default/grub
fi

grub-install --target=x86_64-efi --efi-directory=/boot \
  --bootloader-id='Arch Linux' --modules="tpm" --disable-shim-lock
grub-install --target=x86_64-efi --efi-directory=/boot \
  --bootloader-id='Arch Linux' --modules="tpm" --disable-shim-lock --removable
grub-mkconfig -o /boot/grub/grub.cfg

# NetworkManager uses iwd as the wifi backend (no wpa_supplicant installed)
mkdir -p /etc/NetworkManager/conf.d
printf '[device]\nwifi.backend=iwd\n' >/etc/NetworkManager/conf.d/wifi_backend.conf
systemctl enable NetworkManager fstrim.timer
EOF

# passwords via chpasswd on stdin, never written to disk
printf 'root:%s\n%s:%s\n' "$ROOT_PW" "$USER" "$USER_PW" | arch-chroot /mnt chpasswd

umount -R /mnt
swapoff -a

cat <<EOF

== done, reboot ==
Remove the install media and run: reboot

After first login:
  git config --global user.name  "..."
  git config --global user.email "..."
  ssh-keygen -C "\$(whoami)@\$(uname -n)-\$(date -I)"
  curl -fsSL https://raw.githubusercontent.com/wray-lee/dotfiles/main/setup.sh | sh
Add a disk later:  arch-install.sh extend /dev/sdX
EOF
