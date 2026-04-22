#!/bin/bash
# =============================================================================
# CachyOS Clean Slate Backup — Timeshift to USB (/dev/sdb1)
# Run as normal user with sudo access
# =============================================================================

set -e

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()    { echo -e "${CYAN}[*]${NC} $1"; }
ok()      { echo -e "${GREEN}[✓]${NC} $1"; }
warning() { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[✗]${NC} $1"; exit 1; }
section() { echo -e "\n${YELLOW}══════════════════════════════════════${NC}"; echo -e "${YELLOW}  $1${NC}"; echo -e "${YELLOW}══════════════════════════════════════${NC}"; }

USB_DEVICE="/dev/sdb"
USB_PARTITION="/dev/sdb1"
MOUNT_POINT="/mnt/timeshift-usb"
SNAPSHOT_LABEL="cachyos-clean-slate"

# =============================================================================
# SANITY CHECKS
# =============================================================================

section "Pre-flight Checks"

[[ $EUID -eq 0 ]] && error "Run as your normal user, not root."

# Confirm USB is present
if ! lsblk "$USB_DEVICE" &>/dev/null; then
    error "$USB_DEVICE not found. Is the USB plugged in?"
fi

USB_SIZE=$(lsblk -dno SIZE "$USB_DEVICE")
info "Found USB: $USB_DEVICE ($USB_SIZE)"

# Warn clearly before doing anything destructive
echo ""
echo -e "${RED}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║  WARNING: This script may FORMAT /dev/sdb1           ║${NC}"
echo -e "${RED}║  ALL DATA ON THE USB WILL BE ERASED if it is not     ║${NC}"
echo -e "${RED}║  already ext4.                                        ║${NC}"
echo -e "${RED}║                                                        ║${NC}"
echo -e "${RED}║  USB:  $USB_DEVICE ($USB_SIZE)                              ║${NC}"
echo -e "${RED}║  Make sure this is your backup USB, not something     ║${NC}"
echo -e "${RED}║  important.                                            ║${NC}"
echo -e "${RED}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
read -rp "Type YES to continue: " CONFIRM
[[ "$CONFIRM" != "YES" ]] && echo "Aborted." && exit 0

# =============================================================================
# 1. INSTALL TIMESHIFT
# =============================================================================

section "Installing Timeshift"
if ! command -v timeshift &>/dev/null; then
    sudo pacman -S --needed --noconfirm timeshift
    ok "timeshift installed"
else
    ok "timeshift already installed"
fi

# =============================================================================
# 2. UNMOUNT USB IF MOUNTED
# =============================================================================

section "Preparing USB"
if mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
    info "Unmounting existing mount at $MOUNT_POINT..."
    sudo umount "$MOUNT_POINT"
fi

if grep -q "$USB_PARTITION" /proc/mounts 2>/dev/null; then
    info "Unmounting $USB_PARTITION..."
    sudo umount "$USB_PARTITION"
fi

# =============================================================================
# 3. CHECK / FORMAT USB TO EXT4
# =============================================================================

section "Filesystem Check"

CURRENT_FS=$(lsblk -no FSTYPE "$USB_PARTITION" 2>/dev/null || echo "unknown")
info "Current filesystem on $USB_PARTITION: ${CURRENT_FS:-none}"

if [ "$CURRENT_FS" != "ext4" ]; then
    warning "$USB_PARTITION is not ext4 (Timeshift RSYNC requires ext4)"
    echo ""
    read -rp "Format $USB_PARTITION as ext4? This erases all USB data. (yes/no): " FORMAT_CONFIRM
    if [[ "$FORMAT_CONFIRM" != "yes" ]]; then
        error "Cannot proceed without ext4. Aborting."
    fi

    info "Formatting $USB_PARTITION as ext4..."
    sudo mkfs.ext4 -L "TimeshiftUSB" -F "$USB_PARTITION"
    ok "$USB_PARTITION formatted as ext4"
else
    ok "$USB_PARTITION is already ext4"
fi

# =============================================================================
# 4. MOUNT USB
# =============================================================================

section "Mounting USB"
sudo mkdir -p "$MOUNT_POINT"
sudo mount "$USB_PARTITION" "$MOUNT_POINT"
ok "Mounted $USB_PARTITION at $MOUNT_POINT"

# Check available space
AVAIL=$(df -h "$MOUNT_POINT" | awk 'NR==2 {print $4}')
info "Available space on USB: $AVAIL"

# =============================================================================
# 5. CONFIGURE TIMESHIFT
# =============================================================================

section "Configuring Timeshift"

# Get UUID of USB partition
USB_UUID=$(blkid -s UUID -o value "$USB_PARTITION")
info "USB UUID: $USB_UUID"

# Get UUID of root partition (sda3)
ROOT_UUID=$(blkid -s UUID -o value /dev/sda3)
info "Root UUID: $ROOT_UUID"

sudo mkdir -p /etc/timeshift

sudo tee /etc/timeshift/timeshift.json > /dev/null << EOF
{
  "backup_device_uuid" : "$USB_UUID",
  "parent_device_uuid" : "",
  "do_first_run" : "false",
  "btrfs_mode" : "false",
  "include_btrfs_home_for_backup" : "false",
  "include_btrfs_home_for_restore" : "false",
  "stop_cron_emails" : "true",
  "btrfs_use_qgroup" : "true",
  "schedule_monthly" : "false",
  "schedule_weekly" : "false",
  "schedule_daily" : "false",
  "schedule_hourly" : "false",
  "schedule_boot" : "false",
  "count_monthly" : "2",
  "count_weekly" : "3",
  "count_daily" : "5",
  "count_hourly" : "6",
  "count_boot" : "5",
  "snapshot_size" : "",
  "snapshot_count" : "",
  "date_format" : "%Y-%m-%d %H:%M:%S",
  "exclude" : [
    "+ /root/**",
    "+ /home/**",
    "- /proc/*",
    "- /sys/*",
    "- /dev/*",
    "- /tmp/*",
    "- /run/*",
    "- /mnt/*",
    "- /media/*",
    "- /lost+found"
  ],
  "exclude-apps" : []
}
EOF

ok "Timeshift configured to back up to $USB_PARTITION"

# =============================================================================
# 6. TAKE INITIAL SNAPSHOT
# =============================================================================

section "Taking Clean Slate Snapshot"
info "This may take a few minutes..."

sudo timeshift --create \
    --comments "$SNAPSHOT_LABEL" \
    --tags O \
    --yes

ok "Snapshot complete!"

# =============================================================================
# 7. VERIFY
# =============================================================================

section "Verification"
sudo timeshift --list
SNAP_USED=$(df -h "$MOUNT_POINT" | awk 'NR==2 {print $3}')
SNAP_AVAIL=$(df -h "$MOUNT_POINT" | awk 'NR==2 {print $4}')
info "USB used: $SNAP_USED / available: $SNAP_AVAIL"

# =============================================================================
# DONE
# =============================================================================

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Clean slate snapshot saved to USB!                 ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}To restore later (boot a CachyOS live USB, then):${NC}"
echo "  sudo mount $USB_PARTITION /mnt/timeshift-usb"
echo "  sudo timeshift --restore"
echo ""
echo -e "${CYAN}To take another snapshot anytime:${NC}"
echo "  sudo timeshift --create --comments 'my note' --tags O"
echo ""
echo -e "${CYAN}To list all snapshots:${NC}"
echo "  sudo timeshift --list"
echo ""
echo -e "${YELLOW}Keep the USB plugged in during restore. Don't remove it.${NC}"
