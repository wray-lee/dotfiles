#!/bin/bash
# 一键系统迁移到SSD脚本 (带智能双启动支持)
# 警告：此操作将永久擦除目标磁盘所有数据！
# 版本: 2.0 (自动检测eMMC配置)

# 检查root权限
if [ "$(id -u)" -ne 0 ]; then
    echo "错误：必须使用sudo或root权限运行此脚本"
    exit 1
fi

# 智能设备检测
detect_devices() {
    # 自动检测当前根分区
    CURRENT_ROOT=$(findmnt / -o SOURCE -n)
    CURRENT_UUID=$(findmnt / -o UUID -n)
    
    # 检测是否为eMMC设备
    if [[ $CURRENT_ROOT =~ "mmcblk" ]]; then
        EMMC_DEVICE="/dev/$(lsblk -no NAME ${CURRENT_ROOT%p*})"
        EMMC_ROOT_PART="$CURRENT_ROOT"
        EMMC_ROOT_UUID="$CURRENT_UUID"
        echo "检测到eMMC根分区: $EMMC_ROOT_PART (UUID: $EMMC_ROOT_UUID)"
    else
        echo "错误：当前系统不是从eMMC启动！"
        exit 1
    fi

    # 检测SSD设备
    SSD_CANDIDATES=($(lsblk -d -o NAME,ROTA | awk '$2==0 && $1!="NAME" && $1!~"mmcblk" {print $1}'))
    if [ ${#SSD_CANDIDATES[@]} -eq 0 ]; then
        echo "错误：未检测到SSD设备！"
        exit 1
    elif [ ${#SSD_CANDIDATES[@]} -gt 1 ]; then
        echo "检测到多个SSD设备："
        for i in "${!SSD_CANDIDATES[@]}"; do
            echo "$((i+1))). /dev/${SSD_CANDIDATES[$i]}"
        done
        read -p "请选择要迁移的目标SSD编号: " choice
        TARGET_DISK="/dev/${SSD_CANDIDATES[$((choice-1))]}"
    else
        TARGET_DISK="/dev/${SSD_CANDIDATES[0]}"
    fi
    
    TARGET_PART="${TARGET_DISK}1"
    MOUNT_DIR="/mnt/ssd_migrate"
}

# 显示警告信息
show_warning() {
    echo "========================================"
    echo "      SSD 系统迁移工具 (智能双启动版)"
    echo "========================================"
    echo "当前系统根分区: $EMMC_ROOT_PART (UUID: $EMMC_ROOT_UUID)"
    echo "目标磁盘: $TARGET_DISK"
    echo "目标分区: $TARGET_PART"
    echo "挂载目录: $MOUNT_DIR"
    echo
    echo "警告：此操作将永久擦除 $TARGET_DISK 所有数据!"
    echo "系统将配置为："
    echo "  1. 插入SSD时从SSD启动 (优先)"
    echo "  2. 无SSD时从eMMC启动"
    echo "========================================"

    read -p "确认继续操作? (输入大写的 'YES' 继续): " confirm
    if [ "$confirm" != "YES" ]; then
        echo "操作已取消"
        exit 0
    fi
}

# 准备目标磁盘
prepare_disk() {
    echo -e "\n[1/8] 准备目标磁盘..."
    
    # 检查磁盘是否已挂载
    if mount | grep -q "$TARGET_DISK"; then
        echo "卸载现有分区..."
        umount -l "${TARGET_DISK}"* 2>/dev/null
    fi
    
    # 清除旧分区表
    wipefs -a "$TARGET_DISK"
    
    # 创建新分区
    parted -s "$TARGET_DISK" mklabel gpt
    parted -s -a optimal "$TARGET_DISK" mkpart primary ext4 1MiB 100%
    
    # 刷新分区表
    partprobe "$TARGET_DISK"
    sleep 2
    
    # 格式化分区
    echo -e "\n[2/8] 格式化分区..."
    mkfs.btrfs -f -L ROOTFS "$TARGET_PART"
    sync
    
    # 获取新UUID (带重试)
    echo -e "\n[3/8] 获取新分区UUID..."
    local retries=5
    while [[ $retries -gt 0 ]]; do
        NEW_UUID=$(blkid -s UUID -o value "$TARGET_PART")
        if [ -n "$NEW_UUID" ]; then
            echo "成功获取UUID: $NEW_UUID"
            break
        fi
        echo "等待UUID... ($((6-retries))/5)"
        sleep 1
        retries=$((retries-1))
        partprobe "$TARGET_DISK"
    done
    
    if [ -z "$NEW_UUID" ]; then
        echo "错误：无法获取新分区UUID！"
        exit 1
    fi
}

# 复制系统文件
copy_system() {
    echo -e "\n[4/8] 挂载目标分区..."
    mkdir -p "$MOUNT_DIR"
    mount "$TARGET_PART" "$MOUNT_DIR"
    
    echo -e "\n[5/8] 复制系统文件(可能需要较长时间)..."
    rsync -aAXv --progress \
        --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found"} \
        / "$MOUNT_DIR"
    
    # 特殊处理boot目录
    echo -e "\n[6/8] 处理boot目录..."
    if [ -d "$MOUNT_DIR/boot" ]; then
        rsync -aAXv /boot/ "$MOUNT_DIR/boot/"
    else
        mkdir -p "$MOUNT_DIR/boot"
        rsync -aAXv /boot/ "$MOUNT_DIR/boot/"
    fi
}

# 更新配置文件
update_configs() {
    echo -e "\n[7/8] 更新配置文件..."
    
    # 更新fstab
    echo "更新/etc/fstab..."
    sed -i "s|^UUID=$EMMC_ROOT_UUID|UUID=$NEW_UUID|" "$MOUNT_DIR/etc/fstab"
    
    # 更新armbianEnv.txt
    if [ -f "$MOUNT_DIR/boot/armbianEnv.txt" ]; then
        echo "更新/boot/armbianEnv.txt..."
        sed -i "s|^rootdev=.*|rootdev=UUID=$NEW_UUID|" "$MOUNT_DIR/boot/armbianEnv.txt"
    fi
    
    # 更新extlinux.conf
    if [ -f "$MOUNT_DIR/boot/extlinux/extlinux.conf" ]; then
        echo "更新/boot/extlinux/extlinux.conf..."
        sed -i "s|root=UUID=[a-f0-9-]*|root=UUID=$NEW_UUID|g" "$MOUNT_DIR/boot/extlinux/extlinux.conf"
    fi
    
    # 验证更新
    echo -e "\n验证配置更新:"
    grep "^UUID=" "$MOUNT_DIR/etc/fstab"
    [ -f "$MOUNT_DIR/boot/armbianEnv.txt" ] && grep "^rootdev=" "$MOUNT_DIR/boot/armbianEnv.txt"
    [ -f "$MOUNT_DIR/boot/extlinux/extlinux.conf" ] && grep "root=UUID=" "$MOUNT_DIR/boot/extlinux/extlinux.conf" | head -1
}

# 配置双启动
setup_dual_boot() {
    echo -e "\n[8/8] 配置双启动系统..."
    
    # 备份原始配置
    BOOT_DIR="/boot"
    cp "$BOOT_DIR/extlinux/extlinux.conf" "$BOOT_DIR/extlinux/extlinux.conf.bak"
    
    # 创建新配置
    cat > "$BOOT_DIR/extlinux/extlinux.conf" <<EOF
TIMEOUT 30
DEFAULT ssd

LABEL ssd
  MENU LABEL Boot from SSD (Primary)
  LINUX /Image
  INITRD /uInitrd
  FDT /dtb/amlogic/meson-g12b-a311d-oes-00050000.dtb
  APPEND root=UUID=$NEW_UUID rootflags=compress=zstd:6 rootfstype=btrfs console=ttyAML0,115200n8 console=tty0 no_console_suspend consoleblank=0 coherent_pool=2M libata.force=noncq ubootpart= fsck.fix=yes fsck.repair=yes net.ifnames=0 max_loop=128 cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory swapaccount=1

LABEL emmc
  MENU LABEL Boot from eMMC (Fallback)
  LINUX /Image
  INITRD /uInitrd
  FDT /dtb/amlogic/meson-g12b-a311d-oes-00050000.dtb
  APPEND root=UUID=$EMMC_ROOT_UUID rootflags=compress=zstd:6 rootfstype=btrfs console=ttyAML0,115200n8 console=tty0 no_console_suspend consoleblank=0 coherent_pool=2M libata.force=noncq ubootpart= fsck.fix=yes fsck.repair=yes net.ifnames=0 max_loop=128 cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory swapaccount=1
EOF

    echo "双启动配置完成！"
}

# 清理和完成
cleanup() {
    echo -e "\n[9/9] 清理环境..."
    umount "$MOUNT_DIR"
    rmdir "$MOUNT_DIR"
    
    echo "========================================"
    echo "系统迁移完成！双启动配置："
    echo "1. 插入SSD时：从SSD启动 (默认等待3秒)"
    echo "2. 无SSD时：从eMMC启动"
    echo
    echo "操作指南："
    echo "1. 关闭计算机: shutdown -h now"
    echo "2. 确保SSD已正确连接"
    echo "3. 首次启动后运行: sudo update-initramfs -u"
    echo "========================================"
}

# 主执行流程
detect_devices
show_warning
prepare_disk
copy_system
update_configs
setup_dual_boot
cleanup